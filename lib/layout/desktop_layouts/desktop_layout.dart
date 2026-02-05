import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/services/notifications_service.dart';
import 'package:task_point/utils/task_card.dart';
import 'package:task_point/services/task_model.dart';
import 'package:task_point/widgets/create_task_item.dart';
import 'package:task_point/widgets/participants_widget.dart';
import 'package:task_point/widgets/read_task_item.dart';
import 'package:task_point/widgets/top_bar_item.dart';
import 'package:task_point/widgets/side_bar_item.dart';
import 'package:task_point/router/app_router.dart' as router;

enum SortType { creationDate, deliveryDate, important, assigned, none }

class DesktopLayout extends StatefulWidget {
  final double fontSize;
  final String listId;

  const DesktopLayout({
    super.key,
    required this.fontSize,
    required this.listId,
  });

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  bool _isSidebarOpen = false;
  bool _isCreateTaskOpen = false;
  String? _selectedListName;
  String? _selectedListId;

  final Map<String, Map<String, dynamic>> _usersCache = {};

  String? _currentUserId;
  bool _isOwner = false;
  bool _isAdmin = false;
  bool _isRoleLoaded = false;

  bool _isSortHovered = false;
  bool _isSortMenuOpen = false;

  static const String _importantListId = 'important';
  static const String _assignedListId = 'assigned';

  List<Map<String, dynamic>> _userLists = [];
  List<Map<String, dynamic>> _manageableLists = [];
  List<Map<String, dynamic>> _listsForDuplicate = [];
  List<Map<String, dynamic>> _listsForMove = [];

  final double _menuWidth = 190.0;

  SortType _activeSort = SortType.none;
  bool _isSortReversed = false;
  bool _isParticipantsHovered = false;

  final Set<String> _locallyLeftLists = {};

  TaskModel? _openedTask;
  String? _pendingScrollTaskId;

  final Map<SortType, bool> _hoveredSort = {
    SortType.creationDate: false,
    SortType.deliveryDate: false,
    SortType.important: false,
    SortType.assigned: false,
  };

  final GlobalKey _sortButtonKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  Offset _sortMenuOffset = Offset.zero;

  Color? _selectedListColor;
  List<TaskModel> tasks = [];
  Map<String, DateTime> _taskCreatedAtMap = {};

  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _taskKeys = {};

  bool _completedExpanded = true;
  bool _isListContextLoading = false;

  void _goToTaskFromSpecialList(TaskModel task) async {
    _closeTaskDetail();

    final String targetListId = task.listId;

    final listData = await _getListById(targetListId);
    if (!mounted || listData == null) return;

    _pendingScrollTaskId = task.id;

    _onListSelected(targetListId, listData['name'], listData['color']);

    _waitAndOpenTask(task);
  }

  void _waitAndOpenTask(TaskModel task) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_isListContextLoading || !_isRoleLoaded) {
        _waitAndOpenTask(task);
        return;
      }

      _openTaskDetail(task);

      if (_pendingScrollTaskId != null) {
        _scrollToTask(_pendingScrollTaskId!);
        _pendingScrollTaskId = null;
      }
    });
  }

  Future<void> _ensureUserLoaded(String? userId) async {
    if (userId == null) return;
    if (_usersCache.containsKey(userId)) return;

    final user = await AppwriteService().fetchFullUser(userId);
    if (user != null && mounted) {
      setState(() {
        _usersCache[userId] = user;
      });
    }
  }

  Future<void> _loadUserLists() async {
    try {
      final user = await AppwriteService().account.get();
      final userId = user.$id;

      final result = await AppwriteService().databases.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.listsCollectionId,
      );

      final allLists = result.documents.map((doc) {
        final data = Map<String, dynamic>.from(doc.data);

        return {
          'id': doc.$id,
          'name': data['name'] ?? 'Список',
          'color': Color(int.parse(data['color'] ?? '0xff4fa3ff')),
          'owner_id': data['owner_id'],
          'members': List<String>.from(data['members'] ?? []),
          'admins': List<String>.from(data['admins'] ?? []),
        };
      }).toList();

      final visibleLists = allLists.where((list) {
        return list['owner_id'] == userId ||
            list['admins'].contains(userId) ||
            list['members'].contains(userId);
      }).toList();

      final manageableLists = allLists.where((list) {
        return list['owner_id'] == userId || list['admins'].contains(userId);
      }).toList();

      final filteredVisibleLists = visibleLists
          .where((list) => !_locallyLeftLists.contains(list['id']))
          .toList();

      final filteredManageableLists = manageableLists
          .where((list) => !_locallyLeftLists.contains(list['id']))
          .toList();

      setState(() {
        _userLists = filteredVisibleLists;
        _listsForDuplicate = filteredManageableLists;
        _listsForMove = filteredManageableLists;
      });
    } catch (e) {
      print('Ошибка загрузки списков: $e');
    }
  }

  Future<void> _sendTaskCompletedNotification(TaskModel task) async {
    if (!task.isDone) return;
    if (_currentUserId == null) return;

    final assignerId = await AppwriteService().getTaskAssigner(task.id);

    if (assignerId == null) return;
    if (assignerId == _currentUserId) return;

    await _ensureUserLoaded(_currentUserId);

    final senderAvatarUrl = _usersCache[_currentUserId]?['avatar_url'] ?? '';

    final listData = await _getListById(task.listId);

    await NotificationsService().createNotification(
      senderId: _currentUserId!,
      receiverId: assignerId,
      taskId: task.id,
      listId: task.listId,
      senderAvatarUrl: senderAvatarUrl,
      type: 'task_completed',
      text: 'Задача выполнена в списке «${listData?['name'] ?? 'Список'}»',
    );
  }

  void _openParticipantsPopup() async {
    if (_selectedListId == null) return;

    try {
      final listDoc = await AppwriteService().databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.listsCollectionId,
        documentId: _selectedListId!,
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

      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (context) {
          return ParticipantsWidget(
            onClose: () => entry.remove(),
            ownerName: ownerInfo['name']!,
            ownerAvatarUrl: ownerInfo['avatarUrl']!,
            teamMembers: teamMembers,
            listId: _selectedListId!,
            currentUserId: _currentUserId!,
            onLeaveList: () async {
              final leftListId = _selectedListId;

              setState(() {
                if (leftListId != null) {
                  _locallyLeftLists.add(leftListId);
                }

                _selectedListId = null;
                _selectedListName = null;
                _selectedListColor = null;

                _userLists.removeWhere((l) => l['id'] == leftListId);
                _listsForMove.removeWhere((l) => l['id'] == leftListId);
                _listsForDuplicate.removeWhere((l) => l['id'] == leftListId);

                tasks.clear();
                _openedTask = null;
                _isCreateTaskOpen = false;
              });

              await _loadUserLists();
            },
          );
        },
      );

      Overlay.of(context).insert(entry);
    } catch (e) {
      print('Ошибка открытия участников: $e');
    }
  }

  Future<void> _duplicateTask(TaskModel task) async {
    try {
      final newTaskData = {
        'list_id': task.listId,
        'invoice_number': task.invoice,
        'company_name': task.company,
        'products': task.products,
        'address': task.address,
        'delivery_date': task.date,
        'assigned_to': null,
        'reminder_time': task.reminder,
        'comments': task.comment,
        'is_important': task.isImportant,
        'is_done': task.isDone,
        'order': tasks.length + 1,
      };

      await AppwriteService().databases.createDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.tasksCollectionId,
        documentId: ID.unique(),
        data: newTaskData,
      );

      _loadTasks();
    } catch (e) {
      print('Ошибка дублирования задачи: $e');
    }
  }

  Future<void> _moveTaskToList(TaskModel task, String newListId) async {
    if (task.listId == newListId) return;

    try {
      await AppwriteService().databases.updateDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.tasksCollectionId,
        documentId: task.id,
        data: {'list_id': newListId},
      );

      setState(() {
        tasks.removeWhere((t) => t.id == task.id);
      });
    } catch (e) {
      print('Ошибка перемещения задачи: $e');
    }
  }

  void _toggleSidebar() => setState(() => _isSidebarOpen = !_isSidebarOpen);

  void _onListSelected(String listId, String listName, Color listColor) async {
    setState(() {
      _isListContextLoading = true;
      tasks.clear();

      _openedTask = null;
      _isCreateTaskOpen = false;
      _isRoleLoaded = false;

      _activeSort = SortType.none;
      _isSortReversed = false;
      _isSortMenuOpen = false;

      _selectedListId = listId;
      _selectedListName = listName;
      _selectedListColor = listColor;
    });

    await _loadCurrentUserRole();
    await _loadUserLists();

    if (listId == 'important') {
      await _loadImportantTasks();
    } else if (listId == 'assigned') {
      await _loadAssignedTasks();
    } else {
      await _loadTasks();
    }
    if (mounted) {
      setState(() {
        _isListContextLoading = false;
      });
    }
  }

  void _updateSortMenuPosition() {
    final renderBox =
        _sortButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null || stackBox == null) return;

    final buttonGlobal = renderBox.localToGlobal(Offset.zero);
    final buttonLocalInStack = stackBox.globalToLocal(buttonGlobal);

    double left =
        buttonLocalInStack.dx + renderBox.size.width / 2 - _menuWidth / 2;

    double top = buttonLocalInStack.dy + renderBox.size.height + 10;

    final stackWidth = stackBox.size.width;

    if (left + _menuWidth + 20 > stackWidth) {
      left = stackWidth - _menuWidth - 20;
    }
    if (left < 0) left = 10;

    setState(() {
      _sortMenuOffset = Offset(left, top);
    });
  }

  void _openTaskDetail(TaskModel task) {
    if (_isListContextLoading || !_isRoleLoaded) return;
    setState(() {
      _openedTask = task;
    });
  }

  void _closeTaskDetail() {
    setState(() {
      _openedTask = null;
    });
  }

  Future<Map<String, dynamic>?> _getListById(String listId) async {
    try {
      final result = await AppwriteService().databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.listsCollectionId,
        documentId: listId,
      );

      final data = Map<String, dynamic>.from(result.data);

      return {
        'name': data['name'] ?? 'Список',
        'color': Color(int.parse(data['color'] ?? '0xff4fa3ff')),
      };
    } catch (e) {
      return null;
    }
  }

  void _openList(String listId, {String? taskId}) async {
    _pendingScrollTaskId = taskId;

    final listData = await _getListById(listId);

    if (!mounted) return;

    _onListSelected(
      listId,
      listData?['name'] ?? 'Список',
      listData?['color'] ?? AppColors.skyBlue,
    );

    if (taskId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTask(taskId);
        _pendingScrollTaskId = null;
      });
    }
  }

  Future<void> _loadCurrentUserRole() async {
    try {
      _isRoleLoaded = false;
      setState(() {});

      final user = await AppwriteService().account.get();
      _currentUserId = user.$id;

      if (_selectedListId != null &&
          _selectedListId != 'important' &&
          _selectedListId != 'assigned' &&
          _selectedListId != 'search') {
        final listDoc = await AppwriteService().databases.getDocument(
          databaseId: AppwriteService.databaseId,
          collectionId: AppwriteService.listsCollectionId,
          documentId: _selectedListId!,
        );

        final data = Map<String, dynamic>.from(listDoc.data);

        final ownerId = data['owner_id'] as String?;
        final admins = List<String>.from(data['admins'] ?? []);

        _isOwner = ownerId == _currentUserId;
        _isAdmin = admins.contains(_currentUserId);
      } else {
        _isOwner = true;
        _isAdmin = true;
      }

      _isRoleLoaded = true;
      setState(() {});
    } catch (e) {
      print('Ошибка загрузки роли: $e');
      _isOwner = false;
      _isAdmin = false;
      _isRoleLoaded = true;
      setState(() {});
    }
  }

  void _updateTaskLocally(TaskModel updatedTask) async {
    await _ensureUserLoaded(updatedTask.executor);

    final index = tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index == -1) return;

    setState(() {
      tasks[index] = updatedTask;

      if (_openedTask?.id == updatedTask.id) {
        _openedTask = updatedTask;
      }
    });
  }

  Widget _sortItem({
    required String icon,
    required String text,
    required SortType type,
    required VoidCallback onTap,
  }) {
    final isActive = _activeSort == type;
    final isHovered = _hoveredSort[type] ?? false;

    Color color = isActive
        ? _selectedListColor ?? AppColors.skyBlue
        : AppColors.black;
    if (!isActive && isHovered) {
      color = color.withOpacity(0.7);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredSort[type] = true),
      onExit: (_) => setState(() => _hoveredSort[type] = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          decoration: BoxDecoration(
            color: isHovered
                ? Colors.grey.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icons/$icon.png',
                width: 18,
                height: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sortTasks(SortType type) {
    setState(() {
      if (_activeSort == type) {
        _activeSort = SortType.none;
        _isSortReversed = false;
        tasks.sort((a, b) => a.order.compareTo(b.order));
        return;
      }

      _activeSort = type;
      _isSortReversed = false;

      switch (type) {
        case SortType.deliveryDate:
          tasks.sort((a, b) {
            final aHasDate = a.date != null && a.date!.isNotEmpty;
            final bHasDate = b.date != null && b.date!.isNotEmpty;

            DateTime aDate = aHasDate
                ? DateTime.parse(a.date!)
                : _taskCreatedAtMap[a.id] ?? DateTime.now();
            DateTime bDate = bHasDate
                ? DateTime.parse(b.date!)
                : _taskCreatedAtMap[b.id] ?? DateTime.now();

            return aDate.compareTo(bDate);
          });
          break;

        case SortType.important:
          tasks.sort(
            (a, b) => (b.isImportant ? 1 : 0) - (a.isImportant ? 1 : 0),
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

  Future<void> _scrollToTask(String taskId) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _taskKeys[taskId];
      if (key == null || key.currentContext == null) return;

      final box = key.currentContext!.findRenderObject() as RenderBox;
      final offset = box.localToGlobal(
        Offset.zero,
        ancestor: context.findRenderObject(),
      );

      _scrollController.animateTo(
        _scrollController.offset + offset.dy - 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _toggleCreateTask() =>
      setState(() => _isCreateTaskOpen = !_isCreateTaskOpen);

  void _authListener() {
    if (mounted) setState(() {});
  }

  void _updateTaskStatus(TaskModel updatedTask) async {
    final index = tasks.indexWhere((t) => t.id == updatedTask.id);

    await _ensureUserLoaded(updatedTask.executor);

    if (_selectedListId == 'important' && !updatedTask.isImportant) {
      setState(() {
        tasks.removeWhere((t) => t.id == updatedTask.id);
        if (_openedTask?.id == updatedTask.id) {
          _openedTask = null;
        }
      });

      await AppwriteService().updateTaskStatus(
        taskId: updatedTask.id,
        isDone: updatedTask.isDone,
        isImportant: updatedTask.isImportant,
        executor: updatedTask.executor,
      );
      if (updatedTask.isDone) {
        await _sendTaskCompletedNotification(updatedTask);
      }

      return;
    }

    if (index != -1) {
      setState(() {
        tasks[index] = updatedTask;
      });
    }

    await AppwriteService().updateTaskStatus(
      taskId: updatedTask.id,
      isDone: updatedTask.isDone,
      isImportant: updatedTask.isImportant,
      executor: updatedTask.executor,
    );

    if (updatedTask.isDone) {
      await _sendTaskCompletedNotification(updatedTask);
    }

    setState(() {
      final active = tasks.where((t) => !t.isDone).toList();
      final completed = tasks.where((t) => t.isDone).toList();

      for (int i = 0; i < active.length; i++) {
        active[i] = active[i].copyWith(order: i);
      }
      for (int i = 0; i < completed.length; i++) {
        completed[i] = completed[i].copyWith(order: active.length + i);
      }

      tasks = [...active, ...completed];

      if (_openedTask?.id == updatedTask.id) {
        _openedTask = tasks.firstWhere(
          (t) => t.id == updatedTask.id,
          orElse: () => updatedTask,
        );
      }
    });
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final active = tasks.where((t) => !t.isDone).toList();

    if (newIndex > active.length) newIndex = active.length;
    if (oldIndex < newIndex) newIndex--;

    final movedTask = active.removeAt(oldIndex);
    active.insert(newIndex, movedTask);
    for (int i = 0; i < active.length; i++) {
      active[i] = active[i].copyWith(order: i);
    }

    final completed = tasks.where((t) => t.isDone).toList()
      ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

    for (int i = 0; i < completed.length; i++) {
      completed[i] = completed[i].copyWith(order: active.length + i);
    }

    tasks = [...active, ...completed];

    setState(() {});

    for (final t in active) {
      AppwriteService().databases.updateDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.tasksCollectionId,
        documentId: t.id,
        data: {"order": t.order},
      );
    }
  }

  void _closeCreatePanel() => setState(() => _isCreateTaskOpen = false);

  @override
  void initState() {
    super.initState();
    _selectedListId = widget.listId;
    _init();
  }

  Future<void> _init() async {
    await _loadCurrentUserRole();
    await _loadUserLists();
    await _loadTasks();
  }

  @override
  void dispose() {
    router.authState.removeListener(_authListener);
    super.dispose();
  }

  Future<void> _loadImportantTasks() async {
    try {
      final user = await AppwriteService().account.get();
      final userId = user.$id;

      final manageableListIds = _listsForMove
          .map((l) => l['id'] as String)
          .toList();

      final assignedResult = await AppwriteService().databases.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.tasksCollectionId,
        queries: [
          Query.equal('is_important', true),
          Query.equal('is_done', false),
          Query.equal('assigned_to', userId),
        ],
      );

      final List<Document> adminDocs = [];

      if (manageableListIds.isNotEmpty) {
        final adminResult = await AppwriteService().databases.listDocuments(
          databaseId: AppwriteService.databaseId,
          collectionId: AppwriteService.tasksCollectionId,
          queries: [
            Query.equal('is_important', true),
            Query.equal('is_done', false),
            Query.equal('list_id', manageableListIds),
          ],
        );
        adminDocs.addAll(adminResult.documents);
      }

      final allDocs = {
        for (final d in [...assignedResult.documents, ...adminDocs]) d.$id: d,
      }.values.toList();

      final loadedTasks = allDocs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data);

        final task = TaskModel.fromJson({
          '\$id': doc.$id,
          ...data,
          '\$createdAt': doc.$createdAt,
        });

        _taskCreatedAtMap[task.id] = DateTime.parse(doc.$createdAt);
        return task;
      }).toList();

      final executorIds = loadedTasks
          .map((t) => t.executor)
          .where((id) => id != null && !_usersCache.containsKey(id))
          .toSet();

      await Future.wait(executorIds.map(_ensureUserLoaded));

      if (!mounted) return;

      setState(() {
        tasks = loadedTasks
          ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
      });
    } catch (e) {
      print('Ошибка загрузки важных задач: $e');
    }
  }

  Future<void> _loadAssignedTasks() async {
    final user = await AppwriteService().account.get();
    final userId = user.$id;

    final result = await AppwriteService().databases.listDocuments(
      databaseId: AppwriteService.databaseId,
      collectionId: AppwriteService.tasksCollectionId,
      queries: [
        Query.equal('assigned_to', userId),
        Query.equal('is_done', false),
      ],
    );

    setState(() {
      tasks = result.documents.map((doc) {
        final data = {...doc.data, '\$id': doc.$id};
        final task = TaskModel.fromJson(data);
        _taskCreatedAtMap[task.id] = DateTime.parse(doc.$createdAt);
        return task;
      }).toList();

      tasks.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    });
  }

  Future<void> _loadTasks() async {
    if (_selectedListId == null) return;

    try {
      final result = await AppwriteService().databases.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.tasksCollectionId,
        queries: [Query.equal('list_id', _selectedListId!)],
      );

      final loadedTasks = result.documents.map((doc) {
        final Map<String, dynamic> data = {...doc.data, '\$id': doc.$id};

        return TaskModel.fromJson(data);
      }).toList();

      final executorIds = loadedTasks
          .map((task) => task.executor)
          .where((id) => id != null && !_usersCache.containsKey(id))
          .toSet()
          .toList();

      await Future.wait(executorIds.map((id) => _ensureUserLoaded(id)));

      if (!mounted) return;
      setState(() {
        tasks = loadedTasks;
        tasks.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

        _taskKeys.clear();
        for (var task in tasks) {
          _taskKeys[task.id] = GlobalKey();
        }
      });
    } catch (e) {
      print('Ошибка загрузки задач: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<TaskModel> visibleTasks =
        (!_isListContextLoading && _isRoleLoaded) ? tasks : [];
    final bool isPanelOpen = _openedTask != null || _isCreateTaskOpen;
    final double dynamicRightPadding = isPanelOpen ? 300.0 : 0.0;

    final activeTasks = visibleTasks.where((t) => !t.isDone).toList();
    final completedTasks = visibleTasks.where((t) => t.isDone).toList();

    final bool enableContextMenu =
        !_isListContextLoading &&
        _isRoleLoaded &&
        _selectedListId != 'important' &&
        _selectedListId != 'assigned';

    const double taskSlideOffset = 10;

    return Scaffold(
      backgroundColor: AppColors.darkWhite,
      body: Column(
        children: [
          TopBarItem(
            onToggleSidebar: _toggleSidebar,
            getAllTasks: () => tasks,
            scrollToTask: _scrollToTask,
            openList: _openList,
          ),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isSidebarOpen ? 235 : 105,
                  child: SideBarItem(
                    key: ValueKey(
                      [
                        _importantListId,
                        _assignedListId,
                        ..._userLists.map((e) => e['id']),
                      ].join(','),
                    ),

                    isExpanded: _isSidebarOpen,
                    onExpand: _toggleSidebar,
                    onListSelected: _onListSelected,
                    userLists: _userLists,
                  ),
                ),

                Expanded(
                  child: SizedBox.expand(
                    child: Stack(
                      key: _stackKey,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 30, top: 50),
                          child: _selectedListName == null
                              ? Center(
                                  child: Text(
                                    'Выберите список',
                                    style: TextStyle(
                                      color: AppColors.black,
                                      fontSize: widget.fontSize,
                                    ),
                                  ),
                                )
                              : SingleChildScrollView(
                                  controller: _scrollController,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            'assets/icons/list.png',
                                            width: 25,
                                            height: 25,
                                            color: AppColors.black,
                                          ),
                                          const SizedBox(width: 8),

                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.baseline,
                                            textBaseline:
                                                TextBaseline.alphabetic,
                                            children: [
                                              Text(
                                                _selectedListName!,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.black,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                activeTasks.isNotEmpty
                                                    ? 'Задачи: ${activeTasks.length}'
                                                    : 'Задач нет',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.black,
                                                ),
                                              ),
                                            ],
                                          ),

                                          const Spacer(),

                                          if (_selectedListId != null &&
                                              _selectedListId != 'important' &&
                                              _selectedListId != 'assigned' &&
                                              _selectedListId != 'search')
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 40,
                                              ),
                                              child: Row(
                                                children: [
                                                  MouseRegion(
                                                    onEnter: (_) => setState(
                                                      () =>
                                                          _isSortHovered = true,
                                                    ),
                                                    onExit: (_) => setState(
                                                      () => _isSortHovered =
                                                          false,
                                                    ),
                                                    cursor: SystemMouseCursors
                                                        .click,
                                                    child: GestureDetector(
                                                      behavior: HitTestBehavior
                                                          .opaque,
                                                      key: _sortButtonKey,
                                                      onTap: () {
                                                        _updateSortMenuPosition();
                                                        setState(
                                                          () => _isSortMenuOpen =
                                                              !_isSortMenuOpen,
                                                        );
                                                      },
                                                      child: AnimatedScale(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 120,
                                                            ),
                                                        scale: _isSortHovered
                                                            ? 1.05
                                                            : 1.0,
                                                        child: Row(
                                                          children: [
                                                            Image.asset(
                                                              'assets/icons/filter.png',
                                                              width: 20,
                                                              height: 20,
                                                              color: AppColors
                                                                  .black,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Text(
                                                              'Сортировка',
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: AppColors
                                                                    .black
                                                                    .withOpacity(
                                                                      _isSortHovered
                                                                          ? 0.7
                                                                          : 1.0,
                                                                    ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),

                                                  const SizedBox(width: 16),

                                                  MouseRegion(
                                                    onEnter: (_) => setState(
                                                      () =>
                                                          _isParticipantsHovered =
                                                              true,
                                                    ),
                                                    onExit: (_) => setState(
                                                      () =>
                                                          _isParticipantsHovered =
                                                              false,
                                                    ),
                                                    cursor: SystemMouseCursors
                                                        .click,
                                                    child: GestureDetector(
                                                      onTap:
                                                          _openParticipantsPopup,
                                                      behavior: HitTestBehavior
                                                          .opaque,
                                                      child: AnimatedScale(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 120,
                                                            ),
                                                        scale:
                                                            _isParticipantsHovered
                                                            ? 1.08
                                                            : 1.0,
                                                        child: Row(
                                                          children: [
                                                            Image.asset(
                                                              'assets/icons/participants.png',
                                                              width: 20,
                                                              height: 20,
                                                              color: AppColors
                                                                  .black
                                                                  .withOpacity(
                                                                    _isParticipantsHovered
                                                                        ? 0.7
                                                                        : 1.0,
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Text(
                                                              'Участники',
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: AppColors
                                                                    .black
                                                                    .withOpacity(
                                                                      _isParticipantsHovered
                                                                          ? 0.7
                                                                          : 1.0,
                                                                    ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),

                                      const SizedBox(height: 20),

                                      ReorderableListView(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        onReorder: _onReorder,
                                        buildDefaultDragHandles: false,
                                        proxyDecorator:
                                            (child, index, animation) => child,
                                        children: [
                                          for (final task in activeTasks)
                                            Container(
                                              key: ValueKey(task.id),
                                              child: ReorderableDragStartListener(
                                                index: activeTasks.indexOf(
                                                  task,
                                                ),
                                                child: AnimatedPadding(
                                                  duration: const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  curve: Curves.easeInOut,
                                                  padding: EdgeInsets.only(
                                                    right: dynamicRightPadding,
                                                  ),
                                                  child: TaskCard(
                                                    key: ValueKey(task.id),
                                                    task: task,
                                                    listColor:
                                                        _selectedListColor ??
                                                        AppColors.skyBlue,
                                                    userLists: _listsForMove,
                                                    onStatusChanged:
                                                        _updateTaskStatus,
                                                    onTap:
                                                        (!_isListContextLoading &&
                                                            _isRoleLoaded)
                                                        ? () => _openTaskDetail(
                                                            task,
                                                          )
                                                        : null,
                                                    isAdmin: _isAdmin,
                                                    onTaskDuplicated:
                                                        _selectedListId ==
                                                            'important'
                                                        ? null
                                                        : _duplicateTask,
                                                    onTaskMoved:
                                                        (_isOwner || _isAdmin)
                                                        ? _moveTaskToList
                                                        : null,
                                                    isOwner: _isOwner,
                                                    enableContextMenu:
                                                        enableContextMenu,
                                                    canToggleImportant:
                                                        _selectedListId !=
                                                            'important' &&
                                                        _selectedListId !=
                                                            'assigned',
                                                    executorName:
                                                        _usersCache[task
                                                            .executor]?['name'] ??
                                                        '',
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),

                                      if (completedTasks.isNotEmpty) ...[
                                        const SizedBox(height: 15),
                                        Row(
                                          children: [
                                            const Text(
                                              'Завершенные',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.black,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              '${completedTasks.length}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.black,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            _ArrowToggle(
                                              isExpanded: _completedExpanded,
                                              onTap: () => setState(
                                                () => _completedExpanded =
                                                    !_completedExpanded,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        AnimatedSize(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                          alignment: Alignment.topCenter,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: _completedExpanded
                                                ? Column(
                                                    key: ValueKey(
                                                      'completed-${completedTasks.length}',
                                                    ),
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: completedTasks
                                                        .map(
                                                          (
                                                            task,
                                                          ) => TweenAnimationBuilder<double>(
                                                            key: ValueKey(
                                                              task.id,
                                                            ),
                                                            tween:
                                                                Tween<double>(
                                                                  begin: 0,
                                                                  end: 1,
                                                                ),
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      300,
                                                                ),
                                                            builder:
                                                                (
                                                                  context,
                                                                  value,
                                                                  child,
                                                                ) => Opacity(
                                                                  opacity:
                                                                      value,
                                                                  child: Transform.translate(
                                                                    offset: Offset(
                                                                      0,
                                                                      (1 - value) *
                                                                          -taskSlideOffset,
                                                                    ),
                                                                    child:
                                                                        child,
                                                                  ),
                                                                ),
                                                            child: AnimatedPadding(
                                                              duration:
                                                                  const Duration(
                                                                    milliseconds:
                                                                        200,
                                                                  ),
                                                              curve: Curves
                                                                  .easeInOut,
                                                              padding:
                                                                  EdgeInsets.only(
                                                                    right:
                                                                        dynamicRightPadding,
                                                                  ),
                                                              child: TaskCard(
                                                                key: ValueKey(
                                                                  task.id,
                                                                ),
                                                                task: task,
                                                                listColor:
                                                                    _selectedListColor ??
                                                                    AppColors
                                                                        .skyBlue,
                                                                isCompleted:
                                                                    true,
                                                                userLists:
                                                                    _listsForMove,
                                                                onStatusChanged:
                                                                    _updateTaskStatus,
                                                                onTap:
                                                                    (!_isListContextLoading &&
                                                                        _isRoleLoaded)
                                                                    ? () =>
                                                                          _openTaskDetail(
                                                                            task,
                                                                          )
                                                                    : null,
                                                                isAdmin:
                                                                    _isAdmin,
                                                                onTaskDuplicated:
                                                                    _selectedListId ==
                                                                        'important'
                                                                    ? null
                                                                    : _duplicateTask,
                                                                onTaskMoved:
                                                                    (_isOwner ||
                                                                        _isAdmin)
                                                                    ? _moveTaskToList
                                                                    : null,
                                                                isOwner:
                                                                    _isOwner,
                                                                enableContextMenu:
                                                                    enableContextMenu,
                                                                canToggleImportant:
                                                                    _selectedListId !=
                                                                        'important' &&
                                                                    _selectedListId !=
                                                                        'assigned',
                                                                executorName:
                                                                    _usersCache[task
                                                                        .executor]?['name'] ??
                                                                    '',
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                  )
                                                : const SizedBox(),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                        ),

                        if (_isSortMenuOpen)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () =>
                                  setState(() => _isSortMenuOpen = false),
                              child: Container(color: Colors.transparent),
                            ),
                          ),

                        if (_isSortMenuOpen)
                          Positioned(
                            left: _sortMenuOffset.dx,
                            top: _sortMenuOffset.dy,
                            child: TweenAnimationBuilder(
                              tween: Tween(begin: 0.92, end: 1.0),
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: AnimatedOpacity(
                                    opacity: _isSortMenuOpen ? 1 : 0,
                                    duration: const Duration(milliseconds: 160),
                                    child: Container(
                                      width: _menuWidth,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.black.withOpacity(
                                              0.15,
                                            ),
                                            blurRadius: 16,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 6),
                                          ),
                                          BoxShadow(
                                            color: AppColors.skyBlue
                                                .withOpacity(0.18),
                                            blurRadius: 24,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _sortItem(
                                            icon: 'delivery_date',
                                            text: 'дата выполнения',
                                            type: SortType.deliveryDate,
                                            onTap: () => _sortTasks(
                                              SortType.deliveryDate,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          _sortItem(
                                            icon: 'star',
                                            text: 'Важное',
                                            type: SortType.important,
                                            onTap: () =>
                                                _sortTasks(SortType.important),
                                          ),
                                          const SizedBox(height: 12),
                                          _sortItem(
                                            icon: 'user',
                                            text: 'Назначенные',
                                            type: SortType.assigned,
                                            onTap: () =>
                                                _sortTasks(SortType.assigned),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                        Positioned(
                          right: 40,
                          bottom: 30,
                          child:
                              (_selectedListId != null &&
                                  _selectedListId != _importantListId &&
                                  _selectedListId != _assignedListId &&
                                  _isCreateTaskOpen == false &&
                                  _isRoleLoaded == true &&
                                  (_isOwner || _isAdmin))
                              ? ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _selectedListColor ?? AppColors.skyBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                      horizontal: 24,
                                    ),
                                  ),
                                  onPressed: _toggleCreateTask,
                                  child: const Text(
                                    'Добавить Задачу',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.white,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),

                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          right: _isCreateTaskOpen ? 0 : -300,
                          top: 0,
                          bottom: 0,
                          child: CreateTaskItem(
                            onClose: _closeCreatePanel,
                            listId: _selectedListId ?? "",
                            listColor: _selectedListColor ?? AppColors.black,
                            tasksInList: activeTasks,
                            currentUserId: _currentUserId!,
                            onTaskCreated: (task) {
                              setState(() {
                                final active = tasks
                                    .where((t) => !t.isDone)
                                    .toList();
                                final completed = tasks
                                    .where((t) => t.isDone)
                                    .toList();

                                active.add(task);

                                for (int i = 0; i < active.length; i++) {
                                  active[i] = active[i].copyWith(order: i);
                                }

                                tasks = [...active, ...completed];
                              });
                            },
                          ),
                        ),
                        if (_openedTask != null)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            right: 0,
                            top: 5,
                            bottom: 0,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 300,
                                minWidth: 300,
                              ),

                              child: ReadTaskItem(
                                editingTask: _openedTask!,
                                listId: _selectedListId ?? "",
                                listColor:
                                    _selectedListColor ?? AppColors.skyBlue,
                                tasksInList: tasks,
                                currentUserId: _currentUserId!,
                                onTaskCreated: (newTask) {},
                                onTaskUpdated: (updatedTask) {
                                  _updateTaskLocally(updatedTask);
                                },
                                onClose: _closeTaskDetail,
                                isOwner: _isOwner,
                                isAdmin: _isAdmin,
                                isReadOnly:
                                    _selectedListId == 'important' ||
                                    _selectedListId == 'assigned',
                                onGoToTask: () {
                                  if (_openedTask == null) return;
                                  _goToTaskFromSpecialList(_openedTask!);
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowToggle extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const _ArrowToggle({required this.isExpanded, required this.onTap});

  @override
  State<_ArrowToggle> createState() => _ArrowToggleState();
}

class _ArrowToggleState extends State<_ArrowToggle> {
  bool _isHover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHover = true),
      onExit: (_) => setState(() => _isHover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedRotation(
          turns: widget.isExpanded ? 0.25 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedScale(
            scale: _isHover ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Image.asset(
              'assets/icons/arrow.png',
              width: 20,
              height: 20,
              color: AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}
