import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/services/local_storage_service.dart';
import 'package:task_point/utils/desktop_edit_list.dart';
import 'package:appwrite/appwrite.dart';

class MobileElementsItem extends StatefulWidget {
  final void Function(String listId, String listName, Color color)
  onListSelected;

  const MobileElementsItem({super.key, required this.onListSelected});

  @override
  State<MobileElementsItem> createState() => _MobileElementsItemState();
}

class _MobileElementsItemState extends State<MobileElementsItem> {
  final AppwriteService _appwrite = AppwriteService();
  final TextEditingController _groupController = TextEditingController();

  RealtimeSubscription? _subscription;

  List<Map<String, dynamic>> _items = [];
  String? _currentUserId;
  bool _isAddingGroup = false;

  int _importantTasksCount = 0;
  int _assignedTasksCount = 0;

  final List<Color> _listColors = [
    AppColors.skyBlue,
    AppColors.lavendar,
    AppColors.green,
    AppColors.cheese,
    AppColors.red,
  ];

  @override
  void initState() {
    super.initState();
    _loadUserLists();
    _subscribeToTaskChanges();
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  void _subscribeToTaskChanges() {
    final realtime = Realtime(_appwrite.client);
    _subscription = realtime.subscribe([
      'databases.${AppwriteService.databaseId}.collections.${AppwriteService.tasksCollectionId}.documents',
    ]);

    _subscription!.stream.listen((event) {
      _loadTasksCounts();
    });
  }

  void _navigateToTasks(String id, String name, Color color) async {
    widget.onListSelected(id, name, color);
    await _loadTasksCounts();
  }

  bool _removeFromStructure(List<Map<String, dynamic>> list, String id) {
    for (int i = 0; i < list.length; i++) {
      if (list[i]['id'] == id) {
        list.removeAt(i);
        return true;
      } else if (list[i]['type'] == 'group' && list[i]['children'] != null) {
        if (_removeFromStructure(list[i]['children'], id)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _moveItem(Map<String, dynamic> moved, int insertIndex) async {
    if (moved.isEmpty) return;
    setState(() {
      _removeFromStructure(_items, moved['id']);
      if (insertIndex < 0) insertIndex = 0;
      if (insertIndex > _items.length) insertIndex = _items.length;
      _items.insert(insertIndex, moved);
    });
    _saveToStorage();
  }

  Future<void> _saveToStorage() async {
    if (_currentUserId != null) {
      await LocalStorageService.saveGroupsStructure(
        _items,
        userId: _currentUserId!,
      );
    }
  }

  Future<void> _duplicateList(Map<String, dynamic> list) async {
    final user = await _appwrite.getCurrentUser();
    if (user == null) return;

    try {
      final newList = await _appwrite.createList(
        userId: user.$id,
        name: '${list['name']} (копия)',
        color: (list['color'] as Color).value.toString(),
      );
      if (newList == null) return;

      final newItem = {
        'type': 'list',
        'id': newList['id'],
        'name': newList['name'],
        'color': _parseColor(newList['color']),
        'tasksCount': 0,
        'owner_id': user.$id,
      };

      setState(() => _items.add(newItem));

      final tasksResult = await _appwrite.databases.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.tasksCollectionId,
        queries: [Query.equal('list_id', list['id'])],
      );

      for (var doc in tasksResult.documents) {
        final data = Map<String, dynamic>.from(doc.data);
        data['list_id'] = newList['id'];
        data.remove('\$id');
        data.remove('\$createdAt');
        data.remove('\$updatedAt');

        await _appwrite.databases.createDocument(
          databaseId: AppwriteService.databaseId,
          collectionId: AppwriteService.tasksCollectionId,
          documentId: 'unique()',
          data: data,
        );
      }
      _saveToStorage();
    } catch (e) {
      debugPrint('❌ Ошибка дублирования: $e');
    }
  }

  Future<void> _deleteList(Map<String, dynamic> list) async {
    final user = await _appwrite.getCurrentUser();
    if (user == null) return;

    try {
      final tasksResult = await _appwrite.databases.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.tasksCollectionId,
        queries: [Query.equal('list_id', list['id'])],
      );
      for (var doc in tasksResult.documents) {
        await _appwrite.databases.deleteDocument(
          databaseId: AppwriteService.databaseId,
          collectionId: AppwriteService.tasksCollectionId,
          documentId: doc.$id,
        );
      }
      await _appwrite.deleteList(listId: list['id'], userId: user.$id);

      setState(() {
        _removeFromStructure(_items, list['id']);
      });
      _saveToStorage();
    } catch (e) {
      debugPrint('❌ Ошибка удаления: $e');
    }
  }

  List<String> _getAdminListIds() {
    if (_currentUserId == null) return [];

    final Set<String> ids = {};

    void collect(List<Map<String, dynamic>> items) {
      for (var item in items) {
        if (item['type'] == 'list') {
          final ownerId = item['owner_id'];
          final admins = List<String>.from(item['admins'] ?? []);

          if (ownerId == _currentUserId || admins.contains(_currentUserId)) {
            ids.add(item['id']);
          }
        } else if (item['type'] == 'group' && item['children'] != null) {
          collect(List<Map<String, dynamic>>.from(item['children']));
        }
      }
    }

    collect(_items);
    return ids.toList();
  }

  Future<void> _loadTasksCounts() async {
    if (_currentUserId == null) return;

    try {
      final adminListIds = _getAdminListIds();

      final importantCount = await _appwrite.getActiveTasksCount(
        userId: _currentUserId,
        isImportant: true,
        adminListIds: adminListIds,
      );

      final assignedCount = await _appwrite.getActiveTasksCount(
        userId: _currentUserId,
        isAssigned: true,
      );

      final updatedItems = await Future.wait(
        _items.map((item) async {
          if (item['type'] == 'list') {
            final count = await _appwrite.getActiveTasksCount(
              listId: item['id'],
            );
            return {...item, 'tasksCount': count};
          } else if (item['type'] == 'group' && item['children'] != null) {
            List<Map<String, dynamic>> updatedChildren = [];
            for (var child in item['children']) {
              final count = await _appwrite.getActiveTasksCount(
                listId: child['id'],
              );
              updatedChildren.add({...child, 'tasksCount': count});
            }
            return {...item, 'children': updatedChildren};
          }
          return item;
        }),
      );

      if (!mounted) return;
      setState(() {
        _importantTasksCount = importantCount;
        _assignedTasksCount = assignedCount;
        _items = List<Map<String, dynamic>>.from(updatedItems);
      });
    } catch (e) {
      debugPrint('❌ Ошибка обновления счетчиков: $e');
    }
  }

  void _createNewGroup() {
    if (_groupController.text.trim().isEmpty) return;
    setState(() {
      _items.add({
        'type': 'group',
        'id': 'group_${DateTime.now().millisecondsSinceEpoch}',
        'name': _groupController.text.trim(),
        'isExpanded': true,
        'children': [],
      });
      _groupController.clear();
      _isAddingGroup = false;
    });
    _saveToStorage();
  }

  void _showEditGroupDialog(Map<String, dynamic> group) {
    final TextEditingController editController = TextEditingController(
      text: group['name'],
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Переименовать группу",
          style: TextStyle(color: AppColors.black),
        ),
        content: TextField(
          controller: editController,
          autofocus: true,
          cursorColor: AppColors.black,
          decoration: const InputDecoration(
            hintText: "Новое название",
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.black),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.black),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Отмена",
              style: TextStyle(color: AppColors.black),
            ),
          ),
          TextButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                setState(() {
                  group['name'] = editController.text.trim();
                });
                _saveToStorage();
                Navigator.pop(context);
              }
            },
            child: const Text(
              "Сохранить",
              style: TextStyle(color: AppColors.black),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteGroup(Map<String, dynamic> group) {
    setState(() {
      int index = _items.indexWhere((item) => item['id'] == group['id']);
      if (index != -1) {
        List children = group['children'] ?? [];
        _items.removeAt(index);
        _items.insertAll(index, List<Map<String, dynamic>>.from(children));
      }
    });
    _saveToStorage();
  }

  void _showCreateListDialog() {
    final TextEditingController listNameController = TextEditingController();
    Color selectedColor = _listColors.first;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isButtonActive = listNameController.text
                .trim()
                .isNotEmpty;
            return AlertDialog(
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              title: const Text(
                'Создать список',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: listNameController,
                    autofocus: true,
                    onChanged: (val) {
                      setDialogState(() {});
                    },
                    decoration: const InputDecoration(
                      hintText: 'Название списка',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Выберите цвет:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    children: _listColors.map((color) {
                      final bool isSelected = color == selectedColor;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 34 : 30,
                          height: isSelected ? 34 : 30,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(color: AppColors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isButtonActive
                        ? selectedColor
                        : Colors.grey[300],
                    elevation: isButtonActive ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isButtonActive
                      ? () async {
                          final name = listNameController.text.trim();
                          Navigator.pop(context);
                          await _createListInBackend(name, selectedColor);
                        }
                      : null,
                  child: Text(
                    'Создать',
                    style: TextStyle(
                      color: isButtonActive ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createListInBackend(String name, Color color) async {
    final user = await _appwrite.getCurrentUser();
    if (user == null) return;
    try {
      final newList = await _appwrite.createList(
        userId: user.$id,
        name: name,
        color: color.value.toString(),
      );
      if (newList != null) {
        final newItem = {
          'type': 'list',
          'id': newList['id'],
          'name': newList['name'],
          'color': color,
          'tasksCount': 0,
          'owner_id': user.$id,
        };
        setState(() {
          _items.add(newItem);
        });
        _saveToStorage();
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  Color _parseColor(dynamic raw) {
    try {
      if (raw == null) return AppColors.skyBlue;
      if (raw is int) return Color(raw);
      if (raw is String) {
        if (raw.startsWith('0x')) return Color(int.parse(raw));
        if (RegExp(r'^\d+$').hasMatch(raw)) return Color(int.parse(raw));
      }
    } catch (e) {
      debugPrint('❌ Color parse error: $raw → $e');
    }
    return AppColors.skyBlue;
  }

  Future<void> _loadUserLists() async {
    final user = await _appwrite.getCurrentUser();
    if (user == null) return;
    _currentUserId = user.$id;
    try {
      final ownedLists = await _appwrite.getUserLists(userId: user.$id);
      final allLists = await _appwrite.getAllLists();
      final memberLists = allLists.where((l) {
        final members = List<String>.from(l['members'] ?? []);
        final admins = List<String>.from(l['admins'] ?? []);
        return members.contains(user.$id) || admins.contains(user.$id);
      }).toList();
      final combined = [...ownedLists, ...memberLists];
      final Map<String, Map<String, dynamic>> unique = {};
      for (final l in combined) {
        unique[l['id']] = {
          'type': 'list',
          'id': l['id'],
          'name': l['name'],
          'color': _parseColor(l['color']),
          'tasksCount': l['tasksCount'] ?? 0,
          'owner_id': l['owner_id'],
          'admins': l['admins'],
        };
      }
      final savedStructure = await LocalStorageService.loadGroupsStructure(
        userId: user.$id,
      );
      List<Map<String, dynamic>> restored = savedStructure.isNotEmpty
          ? _restoreListsIntoStructure(savedStructure, unique.values.toList())
          : unique.values.toList();
      final allIdsInStructure = _collectAllIds(restored);
      for (final l in unique.values) {
        if (!allIdsInStructure.contains(l['id'])) {
          restored.add(l);
        }
      }
      if (!mounted) return;
      setState(() => _items = restored);
      await _loadTasksCounts();
    } catch (e) {
      debugPrint('❌ Load error: $e');
    }
  }

  Set<String> _collectAllIds(List<Map<String, dynamic>> items) {
    final ids = <String>{};
    void walk(List<Map<String, dynamic>> list) {
      for (final item in list) {
        ids.add(item['id']);
        if (item['type'] == 'group' && item['children'] != null) {
          walk(List<Map<String, dynamic>>.from(item['children']));
        }
      }
    }

    walk(items);
    return ids;
  }

  List<Map<String, dynamic>> _restoreListsIntoStructure(
    List<Map<String, dynamic>> saved,
    List<Map<String, dynamic>> lists,
  ) {
    final byId = {for (var l in lists) l['id']: l};
    Map<String, dynamic>? restore(Map<String, dynamic> item) {
      if (item['type'] == 'list') return byId.remove(item['id']);
      if (item['type'] == 'group') {
        return {
          'type': 'group',
          'id': item['id'],
          'name': item['name'],
          'isExpanded': item['isExpanded'] ?? false,
          'children': (item['children'] ?? [])
              .map<Map<String, dynamic>?>((c) => restore(c))
              .whereType<Map<String, dynamic>>()
              .toList(),
        };
      }
      return null;
    }

    final result = <Map<String, dynamic>>[];
    for (final item in saved) {
      final restored = restore(item);
      if (restored != null) result.add(restored);
    }
    result.addAll(byId.values);
    return result;
  }

  Widget _buildDraggableItem(Map<String, dynamic> item, int index) {
    return Column(
      key: ValueKey(item['id']),
      children: [
        DragTarget<Map<String, dynamic>>(
          onWillAccept: (data) =>
              data != null && data['data']['id'] != item['id'],
          onAccept: (data) => _moveItem(data['data'], index),
          builder: (context, candidate, _) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: candidate.isNotEmpty ? 60 : 16,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: candidate.isNotEmpty
                  ? AppColors.skyBlue.withOpacity(0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: candidate.isNotEmpty
                  ? Border.all(color: AppColors.skyBlue, width: 2)
                  : null,
            ),
            child: candidate.isNotEmpty
                ? const Center(
                    child: Icon(
                      Icons.add_circle_outline,
                      color: AppColors.skyBlue,
                      size: 30,
                    ),
                  )
                : null,
          ),
        ),
        LongPressDraggable<Map<String, dynamic>>(
          delay: const Duration(milliseconds: 300),
          data: {'type': item['type'], 'data': item},
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.85,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: item['type'] == 'list'
                    ? _userListCard(item)
                    : _groupHeader(item),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: item['type'] == 'list'
                ? _userListCard(item)
                : _groupCard(item),
          ),
          child: item['type'] == 'list'
              ? _userListCard(item)
              : _groupCard(item),
        ),
        if (index == _items.length - 1)
          DragTarget<Map<String, dynamic>>(
            onWillAccept: (data) => data != null,
            onAccept: (data) => _moveItem(data['data'], _items.length),
            builder: (context, candidate, _) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: candidate.isNotEmpty ? 80 : 40,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: candidate.isNotEmpty
                    ? AppColors.skyBlue.withOpacity(0.3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: candidate.isNotEmpty
                    ? Border.all(color: AppColors.skyBlue, width: 2)
                    : null,
              ),
              child: candidate.isNotEmpty
                  ? const Center(
                      child: Icon(
                        Icons.add_circle_outline,
                        color: AppColors.skyBlue,
                        size: 30,
                      ),
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _groupHeader(Map<String, dynamic> group) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
      ),
      child: Text(
        group['name'],
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.black,
        ),
      ),
    );
  }

  Widget _groupCard(Map<String, dynamic> group) {
    final bool expanded = group['isExpanded'] == true;
    final List<Map<String, dynamic>> children = List<Map<String, dynamic>>.from(
      group['children'] ?? [],
    );
    return DragTarget<Map<String, dynamic>>(
      onWillAccept: (data) {
        if (data == null || data['type'] != 'list') return false;
        final String draggedId = data['data']['id'];
        final bool isAlreadyInside = children.any((c) => c['id'] == draggedId);
        return !isAlreadyInside;
      },
      onAccept: (data) async {
        setState(() {
          _removeFromStructure(_items, data['data']['id']);
          group['children'] ??= [];
          group['children'].add(data['data']);
          group['isExpanded'] = true;
        });
        _saveToStorage();
      },
      builder: (context, candidate, _) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: candidate.isNotEmpty
                ? AppColors.lavendar.withOpacity(0.2)
                : AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: candidate.isNotEmpty
                ? Border.all(color: AppColors.lavendar, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 4),
                blurRadius: 20,
                color: Colors.black.withOpacity(0.15),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() => group['isExpanded'] = !expanded),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        group['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: PopupMenuButton<String>(
                        color: AppColors.white,
                        elevation: 4,
                        icon: Image.asset(
                          'assets/icons/more.png',
                          width: 18,
                          height: 18,
                          color: AppColors.black,
                        ),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditGroupDialog(group);
                          } else if (value == 'delete') {
                            _deleteGroup(group);
                          }
                        },
                        itemBuilder: (context) => [
                          _buildPopupItem(
                            'Переименовать',
                            'assets/icons/edit.png',
                            'edit',
                          ),
                          _buildPopupItem(
                            'Удалить группу',
                            'assets/icons/delete.png',
                            'delete',
                            isDelete: true,
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.chevron_right,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
              ),
              if (expanded) ...[
                const SizedBox(height: 12),
                ...children.map((child) => _groupListItem(child, group)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _specialListCard({
    required String title,
    required int tasksCount,
    required List<Color> gradient,
    required String iconPath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 4),
              blurRadius: 20,
              color: Colors.black.withOpacity(0.15),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  iconPath,
                  width: 18,
                  height: 18,
                  color: AppColors.black,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Активных задач: $tasksCount',
              style: const TextStyle(fontSize: 14, color: AppColors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: _isAddingGroup
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _groupController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "Название группы",
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _createNewGroup,
                  icon: const Icon(Icons.check, color: Colors.green),
                ),
                IconButton(
                  onPressed: () => setState(() => _isAddingGroup = false),
                  icon: const Icon(Icons.close, color: Colors.red),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _isAddingGroup = true),
                  icon: const Icon(
                    Icons.create_new_folder_outlined,
                    color: AppColors.black,
                  ),
                  label: const Text(
                    "Создать группу",
                    style: TextStyle(color: AppColors.black),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showCreateListDialog,
                  icon: const Icon(
                    Icons.add_box_outlined,
                    color: AppColors.black,
                  ),
                  label: const Text(
                    "Создать список",
                    style: TextStyle(color: AppColors.black),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Списки',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
        ),
        const SizedBox(height: 15),
        _buildSpecialLists(),
        const SizedBox(height: 12),
        _buildActionButtons(),
        Divider(height: 1, thickness: 1, color: AppColors.paper),
        const SizedBox(height: 4),
        ..._items.asMap().entries.map(
          (entry) => _buildDraggableItem(entry.value, entry.key),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSpecialLists() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _specialListCard(
            title: 'Важное',
            tasksCount: _importantTasksCount,
            gradient: [
              AppColors.candyCrushSecondColor,
              AppColors.candyCrushFirstColor,
            ],
            iconPath: 'assets/icons/star.png',
            onTap: () => _navigateToTasks(
              'important',
              'Важное',
              AppColors.candyCrushSecondColor,
            ),
          ),
          const SizedBox(height: 10),
          _specialListCard(
            title: 'Переданное мне',
            tasksCount: _assignedTasksCount,
            gradient: [
              AppColors.spotifyPurpleFirstColor,
              AppColors.spotifyPurpleSecondColor,
            ],
            iconPath: 'assets/icons/for_me.png',
            onTap: () => _navigateToTasks(
              'assigned',
              'Переданное мне',
              AppColors.spotifyPurpleFirstColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _userListCard(Map<String, dynamic> list) {
    final Color color = list['color'] as Color;

    final bool isOwner =
        _currentUserId != null && list['owner_id'] == _currentUserId;

    return GestureDetector(
      onTap: () => _navigateToTasks(list['id'], list['name'], color),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.only(
          left: 20,
          top: 14,
          bottom: 14,
          right: 10,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 4),
              blurRadius: 20,
              color: Colors.black.withOpacity(0.15),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    list['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                ),
                if (isOwner)
                  SizedBox(
                    width: 30,
                    height: 24,
                    child: PopupMenuButton<String>(
                      color: AppColors.white,
                      elevation: 4,
                      icon: Image.asset(
                        'assets/icons/more.png',
                        width: 20,
                        height: 20,
                        color: AppColors.black,
                      ),
                      padding: EdgeInsets.zero,
                      offset: const Offset(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          showEditListDialog(
                            context: context,
                            list: list,
                            listColors: _listColors,
                            getCurrentUser: _appwrite.getCurrentUser,
                            updateList: _appwrite.updateList,
                            reloadLists: (updated) async {
                              await _loadUserLists();
                            },
                            mounted: mounted,
                          );
                        } else if (value == 'copy') {
                          _duplicateList(list);
                        } else if (value == 'delete') {
                          _deleteList(list);
                        }
                      },
                      itemBuilder: (context) => [
                        _buildPopupItem(
                          'Изменить',
                          'assets/icons/edit.png',
                          'edit',
                        ),
                        _buildPopupItem(
                          'Дублировать',
                          'assets/icons/copy.png',
                          'copy',
                        ),
                        _buildPopupItem(
                          'Удалить',
                          'assets/icons/delete.png',
                          'delete',
                          isDelete: true,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Задачи: ${list['tasksCount']}',
              style: const TextStyle(fontSize: 14, color: AppColors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupListItem(
    Map<String, dynamic> list,
    Map<String, dynamic> parentGroup,
  ) {
    final Color color = list['color'] as Color;
    final int count = list['tasksCount'] ?? 0;
    final bool isOwner =
        _currentUserId != null && list['owner_id'] == _currentUserId;

    return LongPressDraggable<Map<String, dynamic>>(
      delay: const Duration(milliseconds: 300),
      data: {'type': 'list', 'data': list},
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          child: _userListCard(list),
        ),
      ),
      childWhenDragging: const SizedBox.shrink(),
      child: GestureDetector(
        onTap: () => _navigateToTasks(list['id'], list['name'], color),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        '• ${list['name']}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (isOwner) _buildListMenu(list),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListMenu(Map<String, dynamic> list) {
    return SizedBox(
      width: 30,
      height: 30,
      child: PopupMenuButton<String>(
        color: AppColors.white,
        icon: Image.asset('assets/icons/more.png', width: 18, height: 18),
        onSelected: (value) => _handleMenuAction(value, list),
        itemBuilder: (context) => [
          _buildPopupItem('Изменить', 'assets/icons/edit.png', 'edit'),
          _buildPopupItem('Дублировать', 'assets/icons/copy.png', 'copy'),
          _buildPopupItem(
            'Удалить',
            'assets/icons/delete.png',
            'delete',
            isDelete: true,
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String value, Map<String, dynamic> list) {
    if (value == 'edit') {
      showEditListDialog(
        context: context,
        list: list,
        listColors: _listColors,
        getCurrentUser: _appwrite.getCurrentUser,
        updateList: _appwrite.updateList,
        reloadLists: (updated) => _loadUserLists(),
        mounted: mounted,
      );
    } else if (value == 'copy') {
      _duplicateList(list);
    } else if (value == 'delete') {
      _deleteList(list);
    }
  }

  PopupMenuItem<String> _buildPopupItem(
    String title,
    String icon,
    String value, {
    bool isDelete = false,
  }) {
    return PopupMenuItem(
      value: value,
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDelete ? AppColors.red : AppColors.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Image.asset(
            icon,
            width: 18,
            height: 18,
            color: isDelete ? AppColors.red : AppColors.black,
          ),
        ],
      ),
    );
  }
}
