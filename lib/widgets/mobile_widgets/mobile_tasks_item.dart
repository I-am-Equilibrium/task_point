import 'dart:math' as math;
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/services/notifications_service.dart';
import 'package:task_point/services/task_model.dart';
import 'package:task_point/widgets/mobile_widgets/mobile_create_task_item.dart';
import 'package:task_point/utils/mobile_utils/mobile_task_card.dart';
import 'package:task_point/widgets/mobile_widgets/mobile_participants_widget.dart';
import 'package:task_point/widgets/mobile_widgets/mobile_read_task_item.dart';

enum SortType { creationDate, deliveryDate, important, assigned, none }

class MobileTasksScreen extends StatefulWidget {
  final String listId;
  final String listName;
  final Color listColor;
  final String? highlightTaskId;
  final String? scrollToTaskId;

  const MobileTasksScreen({
    super.key,
    required this.listId,
    required this.listName,
    required this.listColor,
    this.highlightTaskId,
    this.scrollToTaskId,
  });

  @override
  State<MobileTasksScreen> createState() => _MobileTasksScreenState();
}

class _MobileTasksScreenState extends State<MobileTasksScreen> {
  List<TaskModel> tasks = [];
  bool _isLoading = true;
  bool _isRoleLoaded = false;
  bool _isCompletedExpanded = true;

  String? _highlightedTaskId;

  String? _currentUserId;
  bool _isOwner = false;
  bool _isAdmin = false;
  bool get _canManage => _isOwner || _isAdmin;
  List<Map<String, dynamic>> _userLists = [];
  List<Map<String, dynamic>> _manageableLists = [];

  bool get _isSpecialList =>
      widget.listId == 'important' || widget.listId == 'assigned';

  SortType _activeSort = SortType.none;
  final Map<String, Map<String, dynamic>> _usersCache = {};

  final ScrollController _scrollController = ScrollController();
  double _itemHeight = 160.0;

  @override
  void initState() {
    super.initState();
    _highlightedTaskId = widget.scrollToTaskId;
    _init();
  }

  void _handleHighlighting() {
    if (_highlightedTaskId == null || tasks.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final activeTasks = tasks.where((t) => !t.isDone).toList();
      final completedTasks = tasks.where((t) => t.isDone).toList();

      int activeIndex = activeTasks.indexWhere(
        (t) => t.id == _highlightedTaskId,
      );
      int completedIndex = completedTasks.indexWhere(
        (t) => t.id == _highlightedTaskId,
      );

      double targetOffset = 0;
      const double cardHeight = 135.0;

      if (activeIndex != -1) {
        targetOffset = activeIndex * cardHeight;
      } else if (completedIndex != -1) {
        setState(() => _isCompletedExpanded = true);

        await Future.delayed(const Duration(milliseconds: 200));

        targetOffset =
            (activeTasks.length * cardHeight) +
            60.0 +
            (completedIndex * cardHeight);
      } else {
        return;
      }

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) {
        setState(() {
          _highlightedTaskId = null;
        });
      }
    });
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);

    await _loadUserContext();
    await _loadUserLists();
    await _loadCurrentUserRole();

    if (widget.listId == 'important') {
      await _loadImportantTasks();
    } else if (widget.listId == 'assigned') {
      await _loadAssignedTasks();
    } else {
      await _loadTasks();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserContext() async {
    try {
      final user = await AppwriteService().account.get();
      _currentUserId = user.$id;

      final allLists = await AppwriteService().getUserLists(
        userId: _currentUserId!,
      );
      _manageableLists = allLists.where((l) {
        final admins = List<String>.from(l['admins'] ?? []);
        return l['owner_id'] == _currentUserId ||
            admins.contains(_currentUserId);
      }).toList();

      if (widget.listId != 'important' && widget.listId != 'assigned') {
        final currentList = allLists.firstWhere(
          (l) => l['id'] == widget.listId,
          orElse: () => {},
        );
        if (currentList.isNotEmpty) {
          final admins = List<String>.from(currentList['admins'] ?? []);
          _isOwner = currentList['owner_id'] == _currentUserId;
          _isAdmin = admins.contains(_currentUserId);
        }
      } else {
        _isOwner = true;
        _isAdmin = true;
      }
      _isRoleLoaded = true;
    } catch (e) {
      debugPrint('Ошибка загрузки контекста пользователя: $e');
      _isRoleLoaded = true;
    }
  }

  Future<void> _loadImportantTasks() async {
    try {
      final manageableIds = _manageableLists
          .map((l) => l['id'] as String)
          .toList();

      final assignedResult = await AppwriteService().databases.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.tasksCollectionId,
        queries: [
          Query.equal('is_important', true),
          Query.equal('is_done', false),
          Query.equal('assigned_to', _currentUserId),
        ],
      );

      List<Document> adminDocs = [];
      if (manageableIds.isNotEmpty) {
        final adminResult = await AppwriteService().databases.listDocuments(
          databaseId: AppwriteService.databaseId,
          collectionId: AppwriteService.tasksCollectionId,
          queries: [
            Query.equal('is_important', true),
            Query.equal('is_done', false),
            Query.limit(100),
            Query.equal('list_id', manageableIds),
          ],
        );
        adminDocs = adminResult.documents;
      }

      final allDocs = {
        for (final d in [...assignedResult.documents, ...adminDocs]) d.$id: d,
      }.values.toList();

      setState(() {
        tasks = allDocs
            .map((doc) => TaskModel.fromJson({'\$id': doc.$id, ...doc.data}))
            .toList();
        tasks.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
      });

      for (var task in tasks) {
        if (task.executor != null) await _ensureUserLoaded(task.executor);
      }

      _handleHighlighting();
    } catch (e) {
      debugPrint('Ошибка загрузки важных задач: $e');
    }
  }

  Future<void> _loadAssignedTasks() async {
    try {
      final result = await AppwriteService().databases.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.tasksCollectionId,
        queries: [
          Query.equal('assigned_to', _currentUserId),
          Query.equal('is_done', false),
        ],
      );

      setState(() {
        tasks = result.documents
            .map((doc) => TaskModel.fromJson({'\$id': doc.$id, ...doc.data}))
            .toList();
        tasks.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
      });

      for (var task in tasks) {
        if (task.executor != null) await _ensureUserLoaded(task.executor);
      }

      _handleHighlighting();
    } catch (e) {
      debugPrint('Ошибка загрузки переданных задач: $e');
    }
  }

  void _sortTasks(SortType type) {
    setState(() {
      if (_activeSort == type) {
        _activeSort = SortType.none;
        tasks.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
        return;
      }
      _activeSort = type;
      switch (type) {
        case SortType.deliveryDate:
          tasks.sort((a, b) {
            final aDateStr = a.date;
            final bDateStr = b.date;
            final bool aHasDate = aDateStr != null && aDateStr.isNotEmpty;
            final bool bHasDate = bDateStr != null && bDateStr.isNotEmpty;
            if (aHasDate && bHasDate) {
              return DateTime.parse(
                aDateStr,
              ).compareTo(DateTime.parse(bDateStr));
            } else if (aHasDate) {
              return -1;
            } else if (bHasDate) {
              return 1;
            } else {
              return 0;
            }
          });
          break;
        case SortType.important:
          tasks.sort(
            (a, b) => (b.isImportant ? 1 : 0).compareTo(a.isImportant ? 1 : 0),
          );
          break;
        case SortType.assigned:
          tasks.sort((a, b) {
            final aAssigned = a.executor?.isNotEmpty == true ? 1 : 0;
            final bAssigned = b.executor?.isNotEmpty == true ? 1 : 0;
            return bAssigned.compareTo(aAssigned);
          });
          break;
        default:
          break;
      }
    });
  }

  PopupMenuItem<SortType> _buildPopupItem(
    String title,
    String icon,
    SortType type,
  ) {
    final bool isActive = _activeSort == type;
    return PopupMenuItem<SortType>(
      value: type,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Image.asset(
            'assets/icons/$icon.png',
            width: 18,
            height: 18,
            color: isActive ? widget.listColor : AppColors.black,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: isActive ? widget.listColor : AppColors.black,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (!_canManage || _isSpecialList) return;

    final activeTasks = tasks.where((t) => !t.isDone).toList();
    if (newIndex > oldIndex) newIndex -= 1;

    setState(() {
      final item = activeTasks.removeAt(oldIndex);
      activeTasks.insert(newIndex, item);

      _activeSort = SortType.none;

      final completedTasks = tasks.where((t) => t.isDone).toList();
      tasks = [...activeTasks, ...completedTasks];

      for (int i = 0; i < tasks.length; i++) {
        tasks[i] = tasks[i].copyWith(order: i);
      }
    });

    for (int i = 0; i < tasks.length; i++) {
      AppwriteService().databases.updateDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.tasksCollectionId,
        documentId: tasks[i].id,
        data: {"order": i},
      );
    }
  }

  Future<void> _openParticipantsPopup() async {
    if (_isSpecialList) return;
    try {
      final listDoc = await AppwriteService().databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.listsCollectionId,
        documentId: widget.listId,
      );
      final listData = Map<String, dynamic>.from(listDoc.data);
      final ownerId = listData['owner_id'];
      final ownerDoc = await AppwriteService().databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.usersCollectionId,
        documentId: ownerId,
      );
      final ownerData = Map<String, dynamic>.from(ownerDoc.data);
      final teamContactsRaw = ownerData['team_contacts'] ?? [];
      final List<String> teamIds = (teamContactsRaw as List<dynamic>)
          .map((e) => e.toString())
          .toList();
      List<Map<String, dynamic>> teamMembers = [];
      for (String userId in teamIds) {
        final user = await AppwriteService().fetchFullUser(userId);
        if (user != null) teamMembers.add(user);
      }
      final ownerInfo = {
        'name': ownerData['name'] ?? 'Владелец',
        'avatarUrl': ownerData['avatar_url'] ?? '',
      };
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return MobileParticipantsWidget(
            listId: widget.listId,
            currentUserId: _currentUserId ?? '',
            ownerName: ownerInfo['name']!,
            ownerAvatarUrl: ownerInfo['avatarUrl']!,
            teamMembers: teamMembers,
            onClose: () => Navigator.pop(context),
            onLeaveList: () {
              Navigator.pop(context);
              Navigator.of(context).pop();
            },
          );
        },
      );
    } catch (e) {
      print('Ошибка открытия участников в мобильной версии: $e');
    }
  }

  Future<void> _loadCurrentUserRole() async {
    try {
      final user = await AppwriteService().account.get();
      _currentUserId = user.$id;
      final listDoc = await AppwriteService().databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.listsCollectionId,
        documentId: widget.listId,
      );
      final data = Map<String, dynamic>.from(listDoc.data);
      final ownerId = data['owner_id'] as String?;
      final admins = List<String>.from(data['admins'] ?? []);
      _isOwner = ownerId == _currentUserId;
      _isAdmin = admins.contains(_currentUserId);
      _isRoleLoaded = true;
    } catch (e) {
      _isOwner = false;
      _isAdmin = false;
      _isRoleLoaded = true;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadUserLists() async {
    try {
      final result = await AppwriteService().databases.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.listsCollectionId,
      );
      setState(() {
        _userLists = result.documents
            .map(
              (doc) => {
                'id': doc.$id,
                'name': doc.data['name'],
                'color': Color(int.parse(doc.data['color'] ?? '0xff4fa3ff')),
              },
            )
            .toList();
      });
    } catch (e) {
      print('Error loading lists for move: $e');
    }
  }

  Future<void> _loadTasks() async {
    try {
      final result = await AppwriteService().databases.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.tasksCollectionId,
        queries: [Query.equal('list_id', widget.listId)],
      );
      final loadedTasks = result.documents.map((doc) {
        final data = Map<String, dynamic>.from(doc.data);
        return TaskModel.fromJson({
          '\$id': doc.$id,
          ...data,
          '\$createdAt': doc.$createdAt,
        });
      }).toList();
      for (var task in loadedTasks) {
        if (task.executor != null) await _ensureUserLoaded(task.executor);
      }
      if (!mounted) return;
      setState(() {
        tasks = loadedTasks;
        tasks.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
      });
      _handleHighlighting();
    } catch (e) {
      print('Ошибка загрузки задач: $e');
    }
  }

  Future<void> _ensureUserLoaded(String? userId) async {
    if (userId == null || _usersCache.containsKey(userId)) return;
    final user = await AppwriteService().fetchFullUser(userId);
    if (user != null && mounted) {
      setState(() => _usersCache[userId] = user);
    }
  }

  void _updateTaskStatus(TaskModel updatedTask) async {
    final index = tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index == -1) return;

    final previousTask = tasks[index];

    setState(() => tasks[index] = updatedTask);

    await AppwriteService().updateTaskStatus(
      taskId: updatedTask.id,
      isDone: updatedTask.isDone,
      isImportant: updatedTask.isImportant,
      executor: updatedTask.executor,
    );

    if (!previousTask.isDone && updatedTask.isDone) {
      await _sendTaskCompletedNotification(updatedTask);
    }

    if (widget.listId == 'important') {
      _loadImportantTasks();
    } else if (widget.listId == 'assigned') {
      _loadAssignedTasks();
    } else {
      _loadTasks();
    }
  }

  Future<void> _sendTaskCompletedNotification(TaskModel task) async {
    if (!task.isDone) return;
    if (_currentUserId == null) return;

    try {
      final assignerId = await AppwriteService().getTaskAssigner(task.id);

      if (assignerId == null) return;
      if (assignerId == _currentUserId) return;

      await _ensureUserLoaded(_currentUserId);

      final senderAvatarUrl = _usersCache[_currentUserId]?['avatar_url'] ?? '';

      final listDoc = await AppwriteService().databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.listsCollectionId,
        documentId: task.listId,
      );

      final listName = listDoc.data['name'] ?? 'Список';

      await NotificationsService().createNotification(
        senderId: _currentUserId!,
        receiverId: assignerId,
        taskId: task.id,
        listId: task.listId,
        senderAvatarUrl: senderAvatarUrl,
        type: 'task_completed',
        text: 'Задача выполнена в списке «$listName»',
      );
    } catch (e) {
      debugPrint('Ошибка отправки task_completed: $e');
    }
  }

  void _openTaskDetail(TaskModel task) async {
    final destinationList = _userLists.firstWhere(
      (l) => l['id'] == task.listId,
      orElse: () => {},
    );

    VoidCallback? onNavigateToOriginal;

    if (_isSpecialList && destinationList.isNotEmpty) {
      onNavigateToOriginal = () {
        Navigator.of(context).pop();

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MobileTasksScreen(
              listId: task.listId,
              listName: destinationList['name'],
              listColor: destinationList['color'],
              highlightTaskId: task.id,
            ),
          ),
        );
      };
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MobileReadTaskScreen(
          task: task,
          listColor: _isSpecialList && destinationList.isNotEmpty
              ? destinationList['color']
              : widget.listColor,
          currentUserId: _currentUserId ?? "",
          isReadOnly: _isSpecialList,
          onNavigateToOriginalList: onNavigateToOriginal,
          showGoToTaskButton: _isSpecialList,
          onTaskUpdated: (updatedTask) {
            if (_isSpecialList) return;
            setState(() {
              final index = tasks.indexWhere((t) => t.id == updatedTask.id);
              if (index != -1) {
                tasks[index] = updatedTask;
              }
            });
          },
          onTaskDeleted: () {
            if (_isSpecialList) return;
            setState(() {
              tasks.removeWhere((t) => t.id == task.id);
            });
          },
        ),
      ),
    );

    if (widget.listId == 'important') {
      _loadImportantTasks();
    } else if (widget.listId == 'assigned') {
      _loadAssignedTasks();
    } else {
      _loadTasks();
    }
  }

  void _openCreateTaskScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MobileCreateTaskScreen(
          listId: widget.listId,
          listColor: widget.listColor,
          tasksInList: tasks,
          currentUserId: _currentUserId ?? "",
          onTaskCreated: (newTask) {
            setState(() {
              tasks.add(newTask);
              tasks.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
            });
          },
        ),
      ),
    );
  }

  Future<void> _handleExitList() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkWhite,
        title: const Text('Покинуть список'),
        content: const Text('Вы действительно хотите покинуть этот список?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Отмена',
              style: TextStyle(color: AppColors.black),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && _currentUserId != null) {
      try {
        final listDoc = await AppwriteService().databases.getDocument(
          databaseId: AppwriteService.databaseId,
          collectionId: AppwriteService.listsCollectionId,
          documentId: widget.listId,
        );

        List<dynamic> members = List.from(listDoc.data['members'] ?? []);
        List<dynamic> admins = List.from(listDoc.data['admins'] ?? []);

        bool needsUpdate = false;

        if (members.contains(_currentUserId)) {
          members.remove(_currentUserId);
          needsUpdate = true;
        }

        if (admins.contains(_currentUserId)) {
          admins.remove(_currentUserId);
          needsUpdate = true;
        }

        if (needsUpdate) {
          await AppwriteService().databases.updateDocument(
            databaseId: AppwriteService.databaseId,
            collectionId: AppwriteService.listsCollectionId,
            documentId: widget.listId,
            data: {'members': members, 'admins': admins},
          );
        }

        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        debugPrint('Ошибка при выходе из списка: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка выхода: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTasks = tasks.where((t) => !t.isDone).toList();
    final completedTasks = tasks.where((t) => t.isDone).toList();

    final canDrag = _canManage && !_isSpecialList;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.listName,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: widget.listColor,
          ),
        ),
        actions: [
          if (!_isSpecialList)
            PopupMenuButton<SortType>(
              color: AppColors.white,
              icon: Image.asset(
                'assets/icons/filter.png',
                width: 20,
                height: 20,
                color: _activeSort != SortType.none
                    ? widget.listColor
                    : AppColors.black,
              ),
              offset: const Offset(0, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (SortType type) => _sortTasks(type),
              itemBuilder: (context) => [
                _buildPopupItem(
                  "Дата выполнения",
                  "date",
                  SortType.deliveryDate,
                ),
                _buildPopupItem("Важность", "star", SortType.important),
                _buildPopupItem("Исполнитель", "user", SortType.assigned),
              ],
            ),
          if (_isRoleLoaded && _canManage && !_isSpecialList)
            IconButton(
              onPressed: _openParticipantsPopup,
              icon: Image.asset('assets/icons/team.png', width: 20, height: 20),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              scrollController: _scrollController,
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: activeTasks.length,
              onReorder: _onReorder,
              footer: completedTasks.isEmpty
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isCompletedExpanded = !_isCompletedExpanded;
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Завершенные",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.black,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Transform.rotate(
                                  angle: _isCompletedExpanded ? math.pi / 2 : 0,
                                  child: Image.asset(
                                    'assets/icons/arrow.png',
                                    width: 24,
                                    height: 24,
                                    color: AppColors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isCompletedExpanded) ...[
                          const SizedBox(height: 10),
                          ...completedTasks.map((task) {
                            final String nameOfExecutor =
                                _usersCache[task.executor]?['name'] ?? '';
                            final originalList = _userLists.firstWhere(
                              (l) => l['id'] == task.listId,
                              orElse: () => {},
                            );
                            final String taskListName =
                                originalList['name'] ?? "";
                            return MobileTaskCard(
                              key: ValueKey("done_${task.id}"),
                              task: task,
                              listColor: widget.listColor,
                              executorName: nameOfExecutor,
                              isHighlighted: _highlightedTaskId == task.id,
                              showListName: widget.listId == 'assigned',
                              taskListName: taskListName,
                              onTap: _isRoleLoaded
                                  ? () => _openTaskDetail(task)
                                  : null,
                              onStatusToggle: () => _updateTaskStatus(
                                task.copyWith(isDone: !task.isDone),
                              ),
                              onFavoriteToggle: (_canManage && !_isSpecialList)
                                  ? () => _updateTaskStatus(
                                      task.copyWith(
                                        isImportant: !task.isImportant,
                                      ),
                                    )
                                  : null,
                            );
                          }).toList(),
                        ],
                        const SizedBox(height: 60),
                      ],
                    ),
              itemBuilder: (context, index) {
                final task = activeTasks[index];
                final String nameOfExecutor =
                    _usersCache[task.executor]?['name'] ?? '';
                final originalList = _userLists.firstWhere(
                  (l) => l['id'] == task.listId,
                  orElse: () => {},
                );
                final String taskListName = originalList['name'] ?? "";

                return ReorderableDelayedDragStartListener(
                  key: ValueKey(task.id),
                  index: index,
                  enabled: canDrag,
                  child: MobileTaskCard(
                    task: task,
                    listColor: widget.listColor,
                    executorName: nameOfExecutor,
                    isHighlighted: _highlightedTaskId == task.id,
                    showListName: widget.listId == 'assigned',
                    taskListName: taskListName,
                    onTap: _isRoleLoaded ? () => _openTaskDetail(task) : null,
                    onStatusToggle: () =>
                        _updateTaskStatus(task.copyWith(isDone: !task.isDone)),
                    onFavoriteToggle: (_canManage && !_isSpecialList)
                        ? () => _updateTaskStatus(
                            task.copyWith(isImportant: !task.isImportant),
                          )
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: _getFloatingActionButton(),
    );
  }

  Widget? _getFloatingActionButton() {
    if (!_isRoleLoaded || _isSpecialList) return null;

    if (_canManage) {
      return FloatingActionButton(
        onPressed: _openCreateTaskScreen,
        backgroundColor: widget.listColor,
        child: const Icon(Icons.add, color: AppColors.white, size: 30),
      );
    } else {
      return FloatingActionButton(
        onPressed: _handleExitList,
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.exit_to_app, color: AppColors.white, size: 30),
      );
    }
  }
}
