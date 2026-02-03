import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:universal_html/html.dart' as html;
import '../utils/desktop_create_list.dart';
import '../utils/desktop_edit_list.dart';
import 'package:task_point/services/local_storage_service.dart';

class SideBarItem extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback? onExpand;
  final void Function(String listId, String listName, Color color)?
  onListSelected;
  final Map<String, int> activeTasksCount;
  final void Function(List<Map<String, dynamic>> lists)? onListsUpdated;
  final VoidCallback? onImportantSelected;
  final VoidCallback? onAssignedSelected;
  final List<Map<String, dynamic>> userLists;

  const SideBarItem({
    super.key,
    required this.isExpanded,
    this.onExpand,
    required this.onListSelected,
    this.onListsUpdated,
    this.activeTasksCount = const {},
    this.onImportantSelected,
    this.onAssignedSelected,
    required this.userLists,
  });

  @override
  State<SideBarItem> createState() => _SideBarItemState();
}

class _SideBarItemState extends State<SideBarItem>
    with SingleTickerProviderStateMixin {
  bool _isHoverImportant = false;
  bool _isHoverForMe = false;
  bool _isHoverTasks = false;
  bool _isHoverCreateList = false;
  bool _showText = false;
  final TextEditingController _groupNameController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _showGroupInput = false;
  String? _currentUserId;
  final List<Color> _listColors = [
    AppColors.skyBlue,
    AppColors.lavendar,
    AppColors.green,
    AppColors.cheese,
    AppColors.red,
  ];
  Widget _buildDraggableListItem(Map<String, dynamic> list, int index) {
    return ReorderableDragStartListener(
      key: ValueKey(list['id']),
      index: index,
      child: _userListItem(list),
    );
  }

  final AppwriteService _appwrite = AppwriteService();
  OverlayEntry? _contextMenuEntry;

  Set<String> _collectAllIds(List<Map<String, dynamic>> items) {
    final ids = <String>{};

    void walk(List<Map<String, dynamic>> list) {
      for (final item in list) {
        if (item['id'] != null) {
          ids.add(item['id']);
        }
        if (item['type'] == 'group' && item['children'] != null) {
          walk(List<Map<String, dynamic>>.from(item['children']));
        }
      }
    }

    walk(items);
    return ids;
  }

  @override
  void initState() {
    super.initState();
    _loadUserLists();

    html.document.onContextMenu.listen((event) {
      event.preventDefault();
    });
  }

  Widget _buildItems(List<Map<String, dynamic>> items, {double indent = 40}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        if (item['type'] == 'list') {
          return _userListItem(item, insideGroup: indent > 40);
        }

        if (item['type'] == 'group') {
          final bool expanded = item['isExpanded'] == true;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  item['isExpanded'] = !expanded;
                }),
                child: Padding(
                  padding: EdgeInsets.only(left: indent, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['name'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: Image.asset(
                          'assets/icons/arrow.png',
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final bool isExpanding = child.key.toString().contains(
                    "expanded",
                  );

                  final offsetTween = Tween<Offset>(
                    begin: isExpanding
                        ? const Offset(0, -0.15)
                        : const Offset(0, 0.15),
                    end: Offset.zero,
                  );

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: offsetTween.animate(animation),
                      child: child,
                    ),
                  );
                },
                child: expanded
                    ? Padding(
                        key: ValueKey("expanded_${item['id']}"),
                        padding: EdgeInsets.only(left: indent + 20),
                        child: _buildItems(
                          item['children'] ?? [],
                          indent: indent + 20,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey("collapsed")),
              ),
            ],
          );
        }

        return const SizedBox.shrink();
      }).toList(),
    );
  }

  List<Widget> _buildSidebarItems() {
    return _items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;

      return StatefulBuilder(
        builder: (context, setHoverState) {
          bool isDragHover = false;

          return DragTarget<Map<String, dynamic>>(
            onWillAccept: (data) {
              final canAccept =
                  data != null && data['data']['id'] != item['id'];
              if (canAccept) setHoverState(() => isDragHover = true);
              return canAccept;
            },
            onLeave: (_) => setHoverState(() => isDragHover = false),
            onAccept: (data) async {
              final moved = data['data'];
              setHoverState(() => isDragHover = false);

              if (data['type'] == 'list' || data['type'] == 'list_in_group') {
                if (item['type'] == 'group') {
                  setState(() {
                    _removeFromStructure(_items, moved['id']);
                    item['children'] ??= [];
                    item['children'].add(moved);
                  });
                } else {
                  _moveItem(moved, index);
                }
              } else if (data['type'] == 'group') {
                _moveItem(moved, index);
              }
              final user = await _appwrite.getCurrentUser();
              if (user != null) {
                await LocalStorageService.saveGroupsStructure(
                  _items,
                  userId: user.$id,
                );
              }
            },

            builder: (context, candidateData, rejectedData) {
              final child = item['type'] == 'list'
                  ? _buildDraggableListItem(item, index)
                  : item['type'] == 'group'
                  ? _buildGroupItem(item, index)
                  : const SizedBox.shrink();

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isDragHover
                      ? AppColors.lavendar.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: child,
              );
            },
          );
        },
      );
    }).toList();
  }

  Color _parseColor(dynamic raw) {
    if (raw is int) return Color(raw);
    if (raw is String) {
      if (RegExp(r'^\d+$').hasMatch(raw)) {
        return Color(int.parse(raw));
      }
      if (raw.startsWith("0x")) {
        return Color(int.parse(raw));
      }
    }
    return Colors.black;
  }

  List<Map<String, dynamic>> deepCloneStructure(
    List<Map<String, dynamic>> items,
  ) {
    return items.map((item) {
      return {
        ...item,
        if (item['children'] != null)
          'children': deepCloneStructure(
            List<Map<String, dynamic>>.from(item['children']),
          ),
      };
    }).toList();
  }

  Future<void> _loadUserLists() async {
    final user = await _appwrite.getCurrentUser();
    if (user == null) return;

    _currentUserId = user.$id;

    try {
      final ownedLists = await _appwrite.getUserLists(userId: user.$id);
      final allLists = await _appwrite.getAllLists();

      final memberAndAdminLists = allLists.where((l) {
        final members = List<String>.from(l['members'] ?? []);
        final admins = List<String>.from(l['admins'] ?? []);
        return members.contains(user.$id) || admins.contains(user.$id);
      }).toList();

      final allListsCombined = [...ownedLists, ...memberAndAdminLists];

      final Set<String> ownedListIds = ownedLists
          .map((e) => e['id'] as String)
          .toSet();

      final lists = <Map<String, dynamic>>[];
      final ids = <String>{};
      for (var l in allListsCombined) {
        if (!ids.contains(l['id'])) {
          lists.add(l);
          ids.add(l['id']);
        }
      }

      final loadedLists = lists.map((l) {
        String? ownerId = l['owner_id'];
        if (ownerId == null && ownedListIds.contains(l['id'])) {
          ownerId = user.$id;
        }

        return {
          'type': 'list',
          'id': l['id'],
          'name': l['name'],
          'color': _parseColor(l['color']),
          'owner_id': ownerId,
        };
      }).toList();

      final savedStructure = await LocalStorageService.loadGroupsStructure(
        userId: user.$id,
      );

      List<Map<String, dynamic>> restored;
      if (savedStructure.isNotEmpty) {
        restored = _restoreListsIntoStructure(savedStructure, loadedLists);

        final allIdsInStructure = _collectAllIds(restored);

        for (final l in loadedLists) {
          if (!allIdsInStructure.contains(l['id'])) {
            restored.add(l);
          }
        }
      } else {
        restored = loadedLists;
      }

      await LocalStorageService.saveGroupsStructure(restored, userId: user.$id);

      if (!mounted) return;
      setState(() {
        _items = restored;
      });
    } catch (e) {
      print('❌ Ошибка загрузки списков/групп: $e');
    }
  }

  @override
  void didUpdateWidget(SideBarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _showText = true);
        });
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _showText = false);
        });
      }
    }
  }

  void _setHover(String assetName, bool value) {
    setState(() {
      switch (assetName) {
        case 'assets/icons/important.png':
          _isHoverImportant = value;
          break;
        case 'assets/icons/for_me.png':
          _isHoverForMe = value;
          break;
        case 'assets/icons/tasks.png':
          _isHoverTasks = value;
          break;
      }
    });
  }

  Widget _listItem({
    required String iconPath,
    required String title,
    required bool isHover,
    required Color hoverColor,
  }) {
    return MouseRegion(
      onEnter: (_) => _setHover(iconPath, true),
      onExit: (_) => _setHover(iconPath, false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(isHover ? 1.05 : 1.0),
        padding: const EdgeInsets.only(left: 40, right: 20, bottom: 16),
        child: Row(
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                isHover ? hoverColor : AppColors.black,
                BlendMode.srcIn,
              ),
              child: Image.asset(iconPath, width: 24, height: 24),
            ),

            const SizedBox(width: 8),

            Text(
              title,
              softWrap: false,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isHover ? hoverColor : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userListItem(Map<String, dynamic> list, {bool insideGroup = false}) {
    bool isHover = false;
    bool isDragging = false;
    final leftPadding = insideGroup ? 30.0 : 40.0;
    final admins = List<String>.from(list['admins'] ?? []);

    return StatefulBuilder(
      builder: (context, setHover) {
        return MouseRegion(
          onEnter: (_) => setHover(() => isHover = true),
          onExit: (_) => setHover(() => isHover = false),
          cursor: SystemMouseCursors.click,
          child: Draggable<Map<String, dynamic>>(
            data: {
              'type': insideGroup ? 'list_in_group' : 'list',
              'data': list,
            },
            feedback: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.2),
                      blurRadius: 6,
                    ),
                  ],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  list['name'],
                  style: TextStyle(
                    color: list['color'],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            onDragStarted: () => setHover(() => isDragging = true),
            onDraggableCanceled: (_, __) => setHover(() => isDragging = false),
            onDragEnd: (_) => setHover(() => isDragging = false),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                final dynamic rawColor = list['color'];
                final Color color = (rawColor is Color)
                    ? rawColor
                    : AppColors.black;
                widget.onListSelected?.call(
                  list['id'] as String,
                  list['name'] as String,
                  color,
                );
              },
              onSecondaryTapDown: (details) {
                if (_currentUserId != null &&
                    (list['owner_id'] == _currentUserId ||
                        admins.contains(_currentUserId))) {
                  print("✅ Доступ разрешен. Открываю меню.");
                  _showContextMenuAt(details.globalPosition, list);
                } else {
                  print("❌ Доступ запрещен. ID не совпадают.");
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: Matrix4.identity()..scale(isHover ? 1.03 : 1.0),
                padding: EdgeInsets.only(
                  left: leftPadding,
                  top: insideGroup ? 20 : 4,
                  bottom: 8,
                ),
                decoration: BoxDecoration(
                  color: isDragging ? AppColors.paper : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/list.png',
                      width: 20,
                      height: 20,
                      color: isHover ? list['color'] : AppColors.black,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        list['name'],
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isHover ? list['color'] : AppColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showContextMenuAt(
    Offset globalPosition,
    Map<String, dynamic> selectedList,
  ) {
    _hideContextMenu();
    final left = 130.0;
    final top = globalPosition.dy + 15.0;

    double opacity = 0.0;

    _contextMenuEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _hideContextMenu,
            child: Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  child: Material(
                    color: Colors.transparent,
                    child: AnimatedOpacity(
                      opacity: opacity,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Container(
                        width: 150,
                        height: 115,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 15,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withOpacity(0.15),
                              offset: const Offset(0, 4),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildContextMenuRow(
                              title: 'Изменить',
                              iconPath: 'assets/icons/edit.png',
                              color: AppColors.black,
                              onTap: () {
                                _hideContextMenu();
                                showEditListDialog(
                                  context: context,
                                  list: selectedList,
                                  listColors: _listColors,
                                  getCurrentUser: _appwrite.getCurrentUser,
                                  updateList: _appwrite.updateList,
                                  reloadLists: (updatedList) async {
                                    await _loadUserLists();
                                  },
                                  mounted: mounted,
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildContextMenuRow(
                              title: 'Дублировать',
                              iconPath: 'assets/icons/copy.png',
                              color: AppColors.black,
                              onTap: () {
                                _hideContextMenu();
                                _duplicateList(selectedList);
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildContextMenuRow(
                              title: 'Удалить',
                              iconPath: 'assets/icons/delete.png',
                              color: AppColors.red,
                              onTap: () {
                                _hideContextMenu();
                                _deleteList(selectedList);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_contextMenuEntry!);

    Future.delayed(const Duration(milliseconds: 10), () {
      opacity = 1.0;
      _contextMenuEntry?.markNeedsBuild();
    });
  }

  Widget _buildContextMenuRow({
    required String title,
    required String iconPath,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Image.asset(iconPath, width: 16, height: 16),
        ],
      ),
    );
  }

  void _hideContextMenu() {
    try {
      _contextMenuEntry?.remove();
    } catch (_) {}
    _contextMenuEntry = null;
  }

  Future _duplicateList(Map<String, dynamic> list) async {
    final user = await _appwrite.getCurrentUser();
    if (user == null) return;

    try {
      final newList = await _appwrite.createList(
        userId: user.$id,
        name: '${list['name']} (копия)',
        color: list['color'].value.toString(),
      );
      if (newList == null) return;

      final newListId = newList['id'];
      final newItem = {
        'type': 'list',
        'id': newListId,
        'name': newList['name'],
        'color': _parseColor(newList['color']),
      };

      setState(() {
        _items.add(newItem);
      });

      final tasksResult = await _appwrite.databases.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.tasksCollectionId,
        queries: [Query.equal('list_id', list['id'])],
      );

      for (var doc in tasksResult.documents) {
        final data = Map<String, dynamic>.from(doc.data);
        data['list_id'] = newListId;

        await _appwrite.databases.createDocument(
          databaseId: AppwriteService.databaseId,
          collectionId: AppwriteService.tasksCollectionId,
          documentId: 'unique()',
          data: data,
        );
      }

      await LocalStorageService.saveGroupsStructure(_items, userId: user.$id);
    } catch (e) {
      print('❌ Ошибка при дублировании списка с задачами: $e');
    }
  }

  Future _deleteList(Map<String, dynamic> list) async {
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

      final success = await _appwrite.deleteList(
        listId: list['id'],
        userId: user.$id,
      );
      if (!success) return;

      setState(() {
        _removeFromStructure(_items, list['id']);
      });
      await LocalStorageService.saveGroupsStructure(_items, userId: user.$id);
    } catch (e) {
      print('❌ Ошибка при удалении списка и его задач: $e');
    }
  }

  Future<void> _moveItem(Map<String, dynamic> moved, int insertIndex) async {
    if (moved.isEmpty) return;

    setState(() {
      // удаляем везде
      _removeFromStructure(_items, moved['id']);

      // вставляем на новое место в корень
      if (insertIndex < 0) insertIndex = 0;
      if (insertIndex > _items.length) insertIndex = _items.length;

      _items.insert(insertIndex, moved);
    });

    final user = await _appwrite.getCurrentUser();
    if (user != null) {
      await LocalStorageService.saveGroupsStructure(_items, userId: user.$id);
    }
  }

  bool _removeFromStructure(List<Map<String, dynamic>> list, String id) {
    for (int i = 0; i < list.length; i++) {
      if (list[i]['id'] == id) {
        list.removeAt(i);
        return true;
      } else if (list[i]['type'] == 'group' && list[i]['children'] != null) {
        if (_removeFromStructure(list[i]['children'], id)) return true;
      }
    }
    return false;
  }

  List<Map<String, dynamic>> _restoreListsIntoStructure(
    List<Map<String, dynamic>> savedStructure,
    List<Map<String, dynamic>> loadedLists,
  ) {
    final Map<String, Map<String, dynamic>> listsById = {
      for (var l in loadedLists) l['id']: {...l, 'type': 'list'},
    };

    Map<String, dynamic>? restoreItem(Map<String, dynamic> item) {
      if (item['type'] == 'list') {
        final id = item['id'];
        final real = listsById.remove(id);
        return real;
      }

      if (item['type'] == 'group') {
        final restoredChildren = <Map<String, dynamic>>[];

        for (final child in (item['children'] ?? [])) {
          final restored = restoreItem(child);
          if (restored != null) restoredChildren.add(restored);
        }

        return {
          'type': 'group',
          'id': item['id'],
          'name': item['name'],
          'isExpanded': item['isExpanded'] ?? false,
          'children': restoredChildren,
        };
      }

      return {...item};
    }

    final result = <Map<String, dynamic>>[];

    for (final item in savedStructure) {
      final restored = restoreItem(item);
      if (restored != null) result.add(restored);
    }

    listsById.forEach((id, item) {
      print("⚠️ Список $id отсутствует в сохранённой структуре");
    });

    return result;
  }

  void _deleteGroupAndExtractChildren(String groupId) {
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];

      if (item['id'] == groupId && item['type'] == 'group') {
        final children = List<Map<String, dynamic>>.from(
          item['children'] ?? [],
        );

        setState(() {
          _items.removeAt(i);
          // Вставляем списки ровно на место удалённой группы
          _items.insertAll(i, children);
        });

        return;
      }
    }
  }

  Widget _buildGroupItem(Map<String, dynamic> group, int groupIndex) {
    bool isHoverInner = false;
    bool isHoverBelow = false;
    bool isDragging = false;

    return StatefulBuilder(
      builder: (context, setHover) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DragTarget<Map<String, dynamic>>(
              onWillAccept: (data) {
                final canAccept =
                    data != null &&
                    (data['type'] == 'list' ||
                        data['type'] == 'list_in_group') &&
                    data['data']['id'] != group['id'];

                if (canAccept) setHover(() => isHoverInner = true);
                return canAccept;
              },
              onLeave: (_) => setHover(() => isHoverInner = false),
              onAccept: (data) async {
                final moved = data['data'];
                setHover(() => isHoverInner = false);
                setState(() {
                  _removeFromStructure(_items, moved['id']);
                  group['children'] ??= [];
                  group['children'].add(moved);
                  group['isExpanded'] = true;
                });

                final user = await _appwrite.getCurrentUser();
                if (user != null) {
                  await LocalStorageService.saveGroupsStructure(
                    _items,
                    userId: user.$id,
                  );
                }
              },

              builder: (context, candidateData, rejectedData) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isHoverInner
                        ? AppColors.skyBlue.withOpacity(0.6)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Draggable<Map<String, dynamic>>(
                    data: {'type': 'group', 'data': group},
                    feedback: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withOpacity(0.2),
                              blurRadius: 6,
                            ),
                          ],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: group['isEditing'] == true
                            ? SizedBox(
                                width: 110,
                                child: TextField(
                                  autofocus: true,
                                  controller: TextEditingController(
                                    text: group['name'],
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.black,
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                  ),
                                  onSubmitted: (value) async {
                                    final newName = value.trim();
                                    if (newName.isNotEmpty) {
                                      setState(() {
                                        group['name'] = newName;
                                        group['isEditing'] = false;
                                      });
                                      final user = await _appwrite
                                          .getCurrentUser();
                                      if (user != null) {
                                        await LocalStorageService.saveGroupsStructure(
                                          _items,
                                          userId: user.$id,
                                        );
                                      }

                                      setState(
                                        () => group['isEditing'] = false,
                                      );
                                    }
                                  },
                                ),
                              )
                            : Text(
                                group['name'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.black,
                                ),
                              ),
                      ),
                    ),
                    onDragStarted: () => setHover(() => isDragging = true),
                    onDragEnd: (_) => setHover(() => isDragging = false),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          if (group['isEditing'] == true) return;
                          setState(() {
                            group['isExpanded'] =
                                !(group['isExpanded'] ?? false);
                          });
                        },
                        onSecondaryTapDown: (details) =>
                            _showGroupContextMenuAt(
                              details.globalPosition,
                              group,
                            ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: EdgeInsets.only(
                            left: 40,
                            bottom:
                                (group['children'] != null &&
                                    group['children'].isNotEmpty)
                                ? 4
                                : 8,
                            right: 20,
                            top:
                                (group['children'] != null &&
                                    group['children'].isNotEmpty)
                                ? 4
                                : 8,
                          ),
                          color: isDragging
                              ? AppColors.paper
                              : Colors.transparent,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: group['isEditing'] == true
                                    ? FocusScope(
                                        child: Focus(
                                          onFocusChange: (hasFocus) async {
                                            if (!hasFocus) {
                                              final newName = group['name']
                                                  .trim();
                                              setState(
                                                () =>
                                                    group['isEditing'] = false,
                                              );
                                              final user = await _appwrite
                                                  .getCurrentUser();
                                              if (user != null) {
                                                await LocalStorageService.saveGroupsStructure(
                                                  _items,
                                                  userId: user.$id,
                                                );
                                              }
                                            }
                                          },
                                          child: TextField(
                                            autofocus: true,
                                            controller: TextEditingController(
                                              text: group['name'],
                                            ),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.black,
                                            ),
                                            onSubmitted: (value) async {
                                              final newName = value.trim();
                                              if (newName.isNotEmpty) {
                                                setState(
                                                  () => group['name'] = newName,
                                                );
                                              }
                                              setState(
                                                () =>
                                                    group['isEditing'] = false,
                                              );
                                              final user = await _appwrite
                                                  .getCurrentUser();
                                              if (user != null) {
                                                await LocalStorageService.saveGroupsStructure(
                                                  _items,
                                                  userId: user.$id,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      )
                                    : Text(
                                        group['name'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.black,
                                        ),
                                      ),
                              ),
                              AnimatedRotation(
                                turns: (group['isExpanded'] == true)
                                    ? 0.25
                                    : 0.0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                child: Image.asset(
                                  'assets/icons/arrow.png',
                                  width: 25,
                                  height: 25,
                                  color: AppColors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(0, -0.1),
                  end: Offset.zero,
                ).animate(animation);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  ),
                );
              },
              child: group['isExpanded'] == true
                  ? Padding(
                      key: ValueKey("expanded_${group['id']}"),
                      padding: const EdgeInsets.only(left: 20),
                      child: _buildItems(group['children'] ?? [], indent: 60),
                    )
                  : const SizedBox.shrink(key: ValueKey("collapsed")),
            ),

            DragTarget<Map<String, dynamic>>(
              onWillAccept: (data) {
                final canAccept =
                    data != null && data['data']['id'] != group['id'];

                if (canAccept) setHover(() => isHoverBelow = true);
                return canAccept;
              },
              onLeave: (_) => setHover(() => isHoverBelow = false),
              onAccept: (data) async {
                final moved = data['data'];
                setHover(() => isHoverBelow = false);
                _moveItem(moved, groupIndex + 1);
                final user = await _appwrite.getCurrentUser();
                if (user != null) {
                  await LocalStorageService.saveGroupsStructure(
                    _items,
                    userId: user.$id,
                  );
                }
              },
              builder: (context, candidateData, rejectedData) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  height: isHoverBelow ? 12 : 8,
                  margin: const EdgeInsets.only(left: 40, right: 20),
                  decoration: BoxDecoration(
                    color: isHoverBelow
                        ? AppColors.lavendar.withOpacity(0.6)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showGroupContextMenuAt(
    Offset globalPosition,
    Map<String, dynamic> group,
  ) {
    _hideContextMenu();
    final left = 130.0;
    final top = globalPosition.dy + 15.0;

    double opacity = 0.0;

    _contextMenuEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _hideContextMenu,
            child: Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  child: Material(
                    color: Colors.transparent,
                    child: AnimatedOpacity(
                      opacity: opacity,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Container(
                        width: 150,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 15,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withOpacity(0.15),
                              offset: const Offset(0, 4),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildContextMenuRow(
                              title: 'Изменить',
                              iconPath: 'assets/icons/edit.png',
                              color: AppColors.black,
                              onTap: () async {
                                _hideContextMenu();
                                setState(() {
                                  group['isEditing'] = true;
                                });
                                await Future.delayed(
                                  Duration(milliseconds: 50),
                                );
                                _hideContextMenu();
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildContextMenuRow(
                              title: 'Удалить',
                              iconPath: 'assets/icons/delete.png',
                              color: AppColors.red,
                              onTap: () async {
                                _hideContextMenu();
                                _deleteGroupAndExtractChildren(group['id']);
                                final user = await _appwrite.getCurrentUser();
                                if (user != null) {
                                  await LocalStorageService.saveGroupsStructure(
                                    _items,
                                    userId: user.$id,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_contextMenuEntry!);

    Future.delayed(const Duration(milliseconds: 10), () {
      opacity = 1.0;
      _contextMenuEntry?.markNeedsBuild();
    });
  }

  void _addGroup(String name) async {
    if (name.trim().isEmpty) return;

    final user = await _appwrite.getCurrentUser();
    if (user == null) return;

    final newGroup = {
      'type': 'group',
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name.trim(),
      'isExpanded': false,
      'children': <Map<String, dynamic>>[],
    };

    setState(() {
      _items = List.from(_items)..add(newGroup);
    });

    await LocalStorageService.saveGroupsStructure(_items, userId: user.$id);
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = widget.isExpanded;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_showGroupInput) setState(() => _showGroupInput = false);
      },
      child: Container(
        color: AppColors.darkWhite,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              GestureDetector(
                onTap: () {
                  widget.onListSelected!(
                    'important',
                    'Важное',
                    AppColors.skyBlue,
                  );
                },
                child: _listItem(
                  iconPath: 'assets/icons/important.png',
                  title: widget.isExpanded ? 'Важное' : '',
                  isHover: _isHoverImportant,
                  hoverColor: AppColors.skyBlue,
                ),
              ),

              GestureDetector(
                onTap: () {
                  widget.onListSelected!(
                    'assigned',
                    'Переданное мне',
                    AppColors.lavendar,
                  );
                },
                child: _listItem(
                  iconPath: 'assets/icons/for_me.png',
                  title: widget.isExpanded ? 'Переданное мне' : '',
                  isHover: _isHoverForMe,
                  hoverColor: AppColors.lavendar,
                ),
              ),

              if (isExpanded) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    width: 215,
                    height: 1,
                    color: AppColors.lightGrey,
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._buildSidebarItems(),
                        if (_showGroupInput)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 40,
                              right: 20,
                              top: 16,
                              bottom: 16,
                            ),
                            child: FocusScope(
                              onFocusChange: (hasFocus) {
                                if (!hasFocus)
                                  setState(() => _showGroupInput = false);
                              },
                              child: TextField(
                                controller: _groupNameController,
                                autofocus: true,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.black,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Введите название группы',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.grey,
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: AppColors.black,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: AppColors.black,
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                                onSubmitted: (value) {
                                  final trimmed = value.trim();
                                  if (trimmed.isNotEmpty) {
                                    _addGroup(trimmed);
                                    _groupNameController.clear();
                                    setState(() => _showGroupInput = false);
                                  }
                                },
                              ),
                            ),
                          ),
                        const SizedBox(height: 35),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 40, bottom: 30),
                  child: Row(
                    children: [
                      MouseRegion(
                        onEnter: (_) =>
                            setState(() => _isHoverCreateList = true),
                        onExit: (_) =>
                            setState(() => _isHoverCreateList = false),
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            showCreateListDialog(
                              context: context,
                              listColors: _listColors,
                              getCurrentUser: _appwrite.getCurrentUser,
                              createList:
                                  ({
                                    required String color,
                                    required String name,
                                    required String userId,
                                  }) async {
                                    final tempId =
                                        'temp_${DateTime.now().millisecondsSinceEpoch}';

                                    Color parsedColor;
                                    try {
                                      parsedColor = Color(int.parse(color));
                                    } catch (e) {
                                      parsedColor = AppColors.black;
                                    }

                                    final optimisticItem = {
                                      'type': 'list',
                                      'id': tempId,
                                      'name': name,
                                      'color': parsedColor,
                                      'owner_id': userId,
                                    };

                                    setState(() {
                                      _items.add(optimisticItem);
                                    });

                                    try {
                                      final createdList = await _appwrite
                                          .createList(
                                            userId: userId,
                                            name: name,
                                            color: color,
                                          );

                                      if (createdList != null) {
                                        if (mounted) {
                                          setState(() {
                                            final index = _items.indexWhere(
                                              (item) => item['id'] == tempId,
                                            );
                                            if (index != -1) {
                                              _items[index] = {
                                                'type': 'list',
                                                'id': createdList['id'],
                                                'name': createdList['name'],
                                                'color': _parseColor(
                                                  createdList['color'],
                                                ),
                                                'owner_id':
                                                    createdList['owner_id'] ??
                                                    userId,
                                              };
                                            }
                                          });
                                          await LocalStorageService.saveGroupsStructure(
                                            _items,
                                            userId: userId,
                                          );
                                        }
                                        return createdList;
                                      }
                                    } catch (e) {
                                      print('❌ Ошибка при создании списка: $e');
                                      if (mounted) {
                                        setState(() {
                                          _items.removeWhere(
                                            (item) => item['id'] == tempId,
                                          );
                                        });
                                      }
                                    }
                                    return null;
                                  },
                              reloadLists: (_) async {},
                              mounted: mounted,
                              onExpand: widget.onExpand ?? () {},
                              isExpanded: widget.isExpanded,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            transform: Matrix4.identity()
                              ..scale(_isHoverCreateList ? 1.07 : 1.0),
                            width: isExpanded ? 150 : 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.black,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: isExpanded
                                ? const Text(
                                    'Создать список',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.white,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/icons/add.png',
                                    width: 20,
                                    height: 20,
                                    color: AppColors.white,
                                  ),
                          ),
                        ),
                      ),
                      if (isExpanded) ...[
                        const SizedBox(width: 15),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _showGroupInput = !_showGroupInput,
                            ),
                            child: Image.asset(
                              'assets/icons/group.png',
                              width: 25,
                              height: 25,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }
}
