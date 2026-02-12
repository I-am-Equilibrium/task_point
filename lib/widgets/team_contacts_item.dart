import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/services/notifications_service.dart';

class TeamContactsItem extends StatefulWidget {
  final VoidCallback onClose;
  final double topBarHeight;

  const TeamContactsItem({
    super.key,
    required this.onClose,
    this.topBarHeight = 110,
  });

  @override
  State<TeamContactsItem> createState() => _TeamContactsItemState();
}

class _TeamContactsItemState extends State<TeamContactsItem>
    with TickerProviderStateMixin {
  final List<Color> _avatarColors = [
    AppColors.green,
    AppColors.skyBlue,
    AppColors.lavendar,
    AppColors.cheese,
    AppColors.red,
  ];

  bool _isHoverClose = false;
  bool _isHoverAdd = false;
  bool _isHoverBack = false;

  bool _isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();

  final NotificationsService _notificationsService = NotificationsService();

  List<Map<String, dynamic>> _searchResults = [];
  Set<String> _addedContacts = {};
  bool _isLoadingSearch = false;

  List<Map<String, dynamic>> _teamContacts = [];

  Timer? _debounceTimer;

  Offset? _contextMenuPosition;
  String? _contextMenuUserId;

  late AnimationController _menuController;
  late Animation<double> _menuOpacity;
  late Animation<double> _menuScale;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _menuController.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadTeamContacts();

    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );

    _menuOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _menuController, curve: Curves.easeOut));

    _menuScale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _menuController, curve: Curves.easeOutBack),
    );
  }

  Color _getAvatarColor(String? userId) {
    if (userId == null || userId.isEmpty) return AppColors.skyBlue;
    final int index = userId.hashCode.abs() % _avatarColors.length;
    return _avatarColors[index];
  }

  Widget _buildAvatar(Map<String, dynamic> user, {bool showLetter = true}) {
    final String? rawUrl = user['avatar_url']?.toString();
    final bool hasAvatar =
        rawUrl != null &&
        rawUrl.isNotEmpty &&
        rawUrl != 'null' &&
        rawUrl.contains('http');

    final String userId =
        user['\$id']?.toString() ?? user['id']?.toString() ?? "";
    final String name = user['name'] ?? "User";
    final String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : "?";

    if (hasAvatar) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Image.network(
          rawUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(userId, firstLetter, showLetter),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildPlaceholder(userId, firstLetter, showLetter);
          },
        ),
      );
    } else {
      return _buildPlaceholder(userId, firstLetter, showLetter);
    }
  }

  Widget _buildPlaceholder(String userId, String letter, bool showLetter) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _getAvatarColor(userId),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: showLetter
          ? Text(
              letter,
              style: const TextStyle(
                color: AppColors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Future<void> _loadTeamContacts() async {
    final service = AppwriteService();
    final current = await service.getCurrentUser();
    if (current == null) return;

    try {
      final doc = await service.databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.usersCollectionId,
        documentId: current.$id,
      );

      final contactsIds = List<String>.from(doc.data['team_contacts'] ?? []);
      final List<Map<String, dynamic>> loaded = [];

      for (final id in contactsIds) {
        final fullUser = await service.fetchFullUser(id);
        if (fullUser == null) continue;

        final assignedCount = await service.getAssignedTasksCount(id);
        fullUser['tasks_assigned_count'] = assignedCount;
        loaded.add(fullUser);
      }

      if (mounted) {
        setState(() {
          _teamContacts = loaded;
          _addedContacts = contactsIds.toSet();
        });
      }
    } catch (e) {
      print('❌ Ошибка загрузки контактов: $e');
    }
  }

  void _openAddToListPopup(String userId) async {
    final service = AppwriteService();
    final current = await service.getCurrentUser();
    if (current == null) return;

    final lists = await service.getManageableLists();

    final filtered = lists.where((list) {
      final admins = List<String>.from(list['admins'] ?? []);
      final members = List<String>.from(list['members'] ?? []);
      final ownerId = list['owner_id'];

      final canManage = ownerId == current.$id || admins.contains(current.$id);

      final alreadyInList =
          ownerId == userId ||
          admins.contains(userId) ||
          members.contains(userId);

      return canManage && !alreadyInList;
    }).toList();

    if (filtered.isEmpty) {
      debugPrint("ℹ Нет доступных списков для добавления");
      return;
    }

    _showAddToListOverlay(filtered, userId);
  }

  void _showAddToListOverlay(
    List<Map<String, dynamic>> lists,
    String userId,
  ) async {
    final service = AppwriteService();
    final current = await service.getCurrentUser();
    if (current == null) return;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => entry.remove(),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: StatefulBuilder(
                builder: (context, setLocalState) {
                  return Container(
                    width: 320,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withOpacity(0.25),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Text(
                            "Добавить в список",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...lists.map((list) {
                          final Color listColor = list['color'] != null
                              ? Color(list['color'])
                              : AppColors.skyBlue;

                          final bool isHover = list['__hover'] == true;

                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) =>
                                setLocalState(() => list['__hover'] = true),
                            onExit: (_) =>
                                setLocalState(() => list['__hover'] = false),
                            child: GestureDetector(
                              onTap: () async {
                                await service.addUserToList(
                                  listId: list['id'],
                                  userId: userId,
                                );

                                final fullCurrentUser = await service
                                    .fetchFullUser(current.$id);
                                final String? senderAvatarUrl =
                                    fullCurrentUser?['avatar_url']?.toString();

                                await _notificationsService.createNotification(
                                  senderId: current.$id,
                                  receiverId: userId,
                                  senderAvatarUrl: senderAvatarUrl,
                                  text:
                                      'Вас добавили в список "${list['title']}"',
                                  type: 'added_to_list',
                                );

                                entry.remove();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isHover
                                      ? listColor.withOpacity(0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  list['title'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isHover
                                        ? listColor
                                        : AppColors.black,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double panelHeight = screenHeight - widget.topBarHeight;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (_contextMenuPosition != null) {
          final menuRect = Rect.fromLTWH(
            _contextMenuPosition!.dx,
            _contextMenuPosition!.dy,
            200,
            80,
          );
          final RenderBox box = context.findRenderObject() as RenderBox;
          final Offset localOffset = box.globalToLocal(event.position);

          if (!menuRect.contains(localOffset)) {
            setState(() {
              _contextMenuPosition = null;
              _contextMenuUserId = null;
            });
          }
        }
      },
      child: Container(
        width: 300,
        height: panelHeight,
        decoration: BoxDecoration(
          color: AppColors.darkWhite,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(10)),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(-4, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: _isSearchMode ? _buildSearchBar() : _buildHeader(),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _isSearchMode
                      ? _buildSearchResults()
                      : (_teamContacts.isEmpty
                            ? const Center(
                                child: Text(
                                  "Контакты отсутствуют",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.grey,
                                    fontSize: 15,
                                  ),
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.only(
                                  top: 10,
                                  left: 15,
                                  right: 15,
                                ),
                                children: List.generate(
                                  _teamContacts.length,
                                  (index) => _buildTeamContactCard(
                                    _teamContacts[index],
                                    index,
                                  ),
                                ),
                              )),
                ),
              ],
            ),
            Positioned(
              right: 15,
              bottom: 15,
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHoverAdd = true),
                onExit: (_) => setState(() => _isHoverAdd = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _isSearchMode = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 45,
                    height: 45,
                    transform: Matrix4.identity()
                      ..scale(_isHoverAdd ? 1.12 : 1.0),
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Image.asset(
                        "assets/icons/add.png",
                        width: 24,
                        height: 24,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_contextMenuPosition != null && _contextMenuUserId != null)
              Positioned(
                left: _contextMenuPosition!.dx,
                top: _contextMenuPosition!.dy,
                child: _buildContextMenu(),
              ),
          ],
        ),
      ),
    );
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoadingSearch = false;
      });
      return;
    }

    setState(() => _isLoadingSearch = true);

    _debounceTimer = Timer(const Duration(seconds: 3), () async {
      final service = AppwriteService();
      final results = await service.searchUsers(text.trim());
      final current = await service.getCurrentUser();

      final filtered = results.where((u) => u['id'] != current?.$id).toList();

      if (mounted) {
        setState(() {
          _searchResults = filtered;
          _isLoadingSearch = false;
        });
      }
    });
  }

  void _closeMenu() {
    _menuController.reverse();
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) {
        setState(() {
          _contextMenuPosition = null;
          _contextMenuUserId = null;
        });
      }
    });
  }

  Widget _buildContextMenu() {
    return FadeTransition(
      opacity: _menuOpacity,
      child: ScaleTransition(
        scale: _menuScale,
        child: MouseRegion(
          opaque: false,
          child: Container(
            width: 200,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      final userId = _contextMenuUserId!;
                      _closeMenu();
                      Future.delayed(const Duration(milliseconds: 150), () {
                        _openAddToListPopup(userId);
                      });
                    },

                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 15,
                        left: 15,
                        right: 15,
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            "assets/icons/add_to_list.png",
                            width: 20,
                            height: 20,
                            color: AppColors.black,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Добавить в список",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      _closeMenu();

                      Future.delayed(const Duration(milliseconds: 120), () {
                        _deleteContact(_contextMenuUserId!);
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15, right: 15),
                      child: Row(
                        children: [
                          Image.asset(
                            "assets/icons/delete.png",
                            width: 20,
                            height: 20,
                            color: AppColors.red,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Удалить из команды",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.red,
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
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      key: const ValueKey("header"),
      padding: const EdgeInsets.only(top: 20, left: 15, right: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _isHoverClose = true),
            onExit: (_) => setState(() => _isHoverClose = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onClose,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                transform: Matrix4.identity()
                  ..scale(_isHoverClose ? 1.15 : 1.0),
                child: Image.asset(
                  "assets/icons/close.png",
                  width: 24,
                  height: 24,
                  color: _isHoverClose
                      ? AppColors.black.withOpacity(0.7)
                      : AppColors.black,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                "Ваша команда",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoadingSearch) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text("Совпадений нет", style: TextStyle(color: AppColors.grey)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 15),
      child: Column(
        children: [
          ..._searchResults.map(_buildUserItem),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    final bool isAdded = _addedContacts.contains(user['id']);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildAvatar(user, showLetter: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? "",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user['email'] ?? "",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
          MouseRegion(
            onEnter: (_) => setState(() => user["__hover_add_btn"] = true),
            onExit: (_) => setState(() => user["__hover_add_btn"] = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _onAddUser(user),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 35,
                height: 35,
                transform: Matrix4.identity()
                  ..scale(user["__hover_add_btn"] == true ? 1.15 : 1.0),
                decoration: BoxDecoration(
                  color: isAdded ? AppColors.skyBlue : AppColors.paper,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (user["__hover_add_btn"] == true)
                      BoxShadow(
                        color: AppColors.black.withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    isAdded ? "assets/icons/check.png" : "assets/icons/add.png",
                    width: 22,
                    height: 22,
                    color: isAdded ? AppColors.white : AppColors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onAddUser(Map<String, dynamic> user) async {
    final service = AppwriteService();
    final current = await service.getCurrentUser();
    if (current == null) return;

    final success = await service.addUserToTeamContacts(
      ownerId: current.$id,
      contactId: user['id'],
    );

    if (!success) return;
    final fullCurrentUser = await service.fetchFullUser(current.$id);
    final String? senderAvatarUrl = fullCurrentUser?['avatar_url']?.toString();

    await _notificationsService.createNotification(
      senderId: current.$id,
      receiverId: user['id'],
      senderAvatarUrl: senderAvatarUrl,
      text: 'Вас добавили в команду',
      type: 'added_to_team',
    );

    final fullUser = await service.fetchFullUser(user['id']);
    if (mounted && fullUser != null) {
      setState(() {
        _addedContacts.add(user['id']);
        _teamContacts.add(fullUser);
      });
    }
  }

  void _showContextMenu(Offset localPosition, String userId) {
    const double panelWidth = 300;
    const double menuWidth = 200;
    const double menuHeight = 80;
    const double padding = 30;

    double x = localPosition.dx;
    double y = localPosition.dy;

    if (x + menuWidth > panelWidth - padding) {
      x = panelWidth - menuWidth - padding;
    }

    final double panelHeight =
        MediaQuery.of(context).size.height - widget.topBarHeight;
    if (y + menuHeight > panelHeight - padding) {
      y = panelHeight - menuHeight - padding;
    }

    setState(() {
      _contextMenuPosition = Offset(x, y);
      _contextMenuUserId = userId;
    });

    _menuController.forward(from: 0);
  }

  Widget _buildTeamContactCard(Map<String, dynamic> user, int index) {
    return Padding(
      padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
      child: Listener(
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.mouse &&
              event.buttons == kPrimaryMouseButton) {
            setState(() => user["__pressed"] = true);

            Future.delayed(const Duration(milliseconds: 95), () {
              if (mounted) {
                setState(() => user["__pressed"] = false);
              }
            });

            final RenderBox box = context.findRenderObject() as RenderBox;
            final Offset localOffset = box.globalToLocal(event.position);
            _showContextMenu(localOffset, user["id"]);
          }
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => user["__hover"] = true),
          onExit: (_) => setState(() => user["__hover"] = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),

            transform: Matrix4.identity()
              ..scale(
                user["__pressed"] == true
                    ? 0.97
                    : (user["__hover"] == true ? 1.015 : 1.0),
              ),

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(
                    user["__hover"] == true ? 0.25 : 0.15,
                  ),
                  blurRadius: user["__hover"] == true ? 28 : 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildContactCardContent(user, index),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCardContent(Map<String, dynamic> user, int index) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(user, showLetter: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'] ?? "",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user['email'] ?? "",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Container(height: 1, color: AppColors.paper),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                "Передано задач:",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                (user['tasks_assigned_count'] ?? 0).toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      key: const ValueKey("search"),
      padding: const EdgeInsets.only(top: 12, left: 15, right: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.black, width: 1),
            ),
            child: Row(
              children: [
                MouseRegion(
                  onEnter: (_) => setState(() => _isHoverBack = true),
                  onExit: (_) => setState(() => _isHoverBack = false),
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSearchMode = false;
                        _searchController.clear();
                        _searchResults = [];
                      });
                    },
                    child: AnimatedScale(
                      scale: _isHoverBack ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Image.asset(
                          "assets/icons/back.png",
                          width: 24,
                          height: 24,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.black,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Найти сотрудника...",
                      hintStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grey,
                      ),
                      isCollapsed: true,
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

  Future<void> _deleteContact(String userId) async {
    final service = AppwriteService();
    final current = await service.getCurrentUser();

    if (current == null) return;

    final ok = await service.removeUserFromTeamContacts(
      ownerId: current.$id,
      contactId: userId,
    );

    if (!ok) return;
    final fullCurrentUser = await service.fetchFullUser(current.$id);
    final senderAvatarUrl = fullCurrentUser?['avatar_url']?.toString();

    await _notificationsService.createNotification(
      senderId: current.$id,
      receiverId: userId,
      senderAvatarUrl: senderAvatarUrl,
      text: 'Вас удалили из команды',
      type: 'deleted_from_team',
    );

    if (mounted) {
      setState(() {
        _teamContacts.removeWhere((u) => u["id"] == userId);
        _addedContacts.remove(userId);
        _contextMenuPosition = null;
        _contextMenuUserId = null;
      });
    }
  }
}
