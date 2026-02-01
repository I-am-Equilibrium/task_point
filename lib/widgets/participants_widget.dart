import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/services/notifications_service.dart';

class ParticipantsWidget extends StatefulWidget {
  final VoidCallback onClose;
  final String ownerName;
  final String? ownerAvatarUrl;
  final VoidCallback? onMemberAdded;
  final VoidCallback? onLeaveList;

  final List<Map<String, dynamic>> teamMembers;
  final String listId;
  final String currentUserId;

  const ParticipantsWidget({
    super.key,
    required this.onClose,
    required this.ownerName,
    this.ownerAvatarUrl,
    this.teamMembers = const [],
    required this.listId,
    required this.currentUserId,
    this.onMemberAdded,
    this.onLeaveList,
  });

  @override
  State<ParticipantsWidget> createState() => _ParticipantsWidgetState();
}

class _ParticipantsWidgetState extends State<ParticipantsWidget> {
  bool _isBackHovered = false;
  int? _hoveredAddIndex;
  List<Map<String, dynamic>> _addedMembers = [];
  List<String> _adminIds = [];

  late String _currentUserId;
  String? _currentUserAvatarUrl;
  bool get _isCurrentUserOwner => _currentUserId == _ownerId;
  bool get _isCurrentUserAdmin => _adminIds.contains(_currentUserId);

  late Future<void> _initialLoadFuture;
  OverlayEntry? _memberContextMenu;
  String? _hoveredMemberId;
  String? _ownerId;

  final NotificationsService _notificationsService = NotificationsService();

  late String _listName;

  final List<Color> fallbackColors = [
    AppColors.skyBlue,
    AppColors.cheese,
    AppColors.green,
    AppColors.red,
    AppColors.lavendar,
  ];

  Color _getFallbackColor(String name) {
    final index = name.hashCode.abs() % fallbackColors.length;
    return fallbackColors[index];
  }

  Future<void> _addMember(Map<String, dynamic> member) async {
    final memberId = member['id'];

    final alreadyAdded = _addedMembers.any((m) => m['id'] == memberId);
    if (alreadyAdded) return;

    try {
      final success = await AppwriteService().addMemberToList(
        listId: widget.listId,
        memberId: memberId,
      );

      if (!success) return;

      await _notificationsService.createNotification(
        listId: widget.listId,
        senderId: widget.currentUserId,
        receiverId: memberId,
        senderAvatarUrl: _currentUserAvatarUrl,
        text: 'Вас добавили в список "$_listName"',
        type: 'added_to_list',
      );

      setState(() {
        _addedMembers.add(member);
      });

      widget.onMemberAdded?.call();
    } catch (e) {
      print('Ошибка при добавлении участника: $e');
    }
  }

  Future<void> _leaveList() async {
    try {
      if (_isCurrentUserOwner) return;

      if (_isCurrentUserAdmin) {
        await AppwriteService().removeAdminFromList(
          listId: widget.listId,
          userId: _currentUserId,
        );
      } else {
        await AppwriteService().removeMemberFromList(
          listId: widget.listId,
          memberId: _currentUserId,
        );

        await AppwriteService().clearAssigneeFromTasks(
          listId: widget.listId,
          userId: _currentUserId,
        );
      }

      widget.onLeaveList?.call();
      widget.onClose();
    } catch (e) {
      print('Ошибка при выходе из списка: $e');
    }
  }

  Future<void> _promoteToAdmin(Map<String, dynamic> member) async {
    final userId = member['id'];
    if (userId == _ownerId) return;

    try {
      await AppwriteService().promoteMemberToAdmin(
        listId: widget.listId,
        userId: userId,
      );

      await _notificationsService.createNotification(
        listId: widget.listId,
        senderId: widget.currentUserId,
        receiverId: userId,
        senderAvatarUrl: _currentUserAvatarUrl,
        text: 'Вас назначили администратором списка "$_listName"',
        type: 'made_admin',
      );

      setState(() {
        if (!_adminIds.contains(userId)) {
          _adminIds.add(userId);
        }
      });

      widget.onMemberAdded?.call();
    } catch (e) {
      print('Ошибка при назначении администратора: $e');
    }
  }

  Future<void> _removeMember(
    Map<String, dynamic> member, {
    bool isAdmin = false,
  }) async {
    final memberId = member['id'];
    if (memberId == _ownerId) return;

    try {
      if (isAdmin) {
        await AppwriteService().removeAdminFromList(
          listId: widget.listId,
          userId: memberId,
        );
      } else {
        await AppwriteService().removeMemberFromList(
          listId: widget.listId,
          memberId: memberId,
        );

        await AppwriteService().clearAssigneeFromTasks(
          listId: widget.listId,
          userId: memberId,
        );
      }

      await _notificationsService.createNotification(
        listId: widget.listId,
        senderId: widget.currentUserId,
        receiverId: memberId,
        senderAvatarUrl: _currentUserAvatarUrl,
        text: 'Вас удалили из списка "$_listName"',
        type: 'deleted_from_list',
      );

      setState(() {
        _adminIds.remove(memberId);
        _addedMembers.removeWhere((m) => m['id'] == memberId);
      });

      widget.onMemberAdded?.call();
    } catch (e) {
      print("Ошибка при удалении участника: $e");
    }
  }

  Future<void> _demoteAdmin(Map<String, dynamic> member) async {
    final userId = member['id'];
    if (userId == _ownerId) return;

    try {
      await AppwriteService().demoteAdminToMember(
        listId: widget.listId,
        userId: userId,
      );

      await _notificationsService.createNotification(
        listId: widget.listId,
        senderId: widget.currentUserId,
        receiverId: userId,
        senderAvatarUrl: _currentUserAvatarUrl,
        text: 'Вы больше не являетесь администратором списка "$_listName"',
        type: 'made_member',
      );

      setState(() {
        _adminIds.remove(userId);
      });

      widget.onMemberAdded?.call();
    } catch (e) {
      print("Ошибка при понижении администратора: $e");
    }
  }

  Widget _buildUserRow({
    required Map<String, dynamic> member,
    required bool isAdmin,
    bool isOwner = false,
  }) {
    final name = member['name'] ?? 'Пользователь';
    final avatar = member['avatar_url'];
    final userId = member['id'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Listener(
        onPointerDown: (event) {
          if (event.buttons != kSecondaryMouseButton) return;

          final memberId = member['id'];

          if (isOwner || memberId == _currentUserId) return;
          if (_isCurrentUserAdmin && isAdmin) return;

          _showMemberContextMenu(
            position: event.position,
            member: member,
            isAdmin: isAdmin,
          );
        },

        child: MouseRegion(
          onEnter: (_) {
            if (!isOwner) setState(() => _hoveredMemberId = userId);
          },
          onExit: (_) {
            if (!isOwner) setState(() => _hoveredMemberId = null);
          },
          cursor:
              (isOwner ||
                  member['id'] == _currentUserId ||
                  (_isCurrentUserAdmin && isAdmin))
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,

          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: (!isOwner && _hoveredMemberId == userId)
                  ? AppColors.black.withOpacity(0.04)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                avatar != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Image.network(
                          avatar,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getFallbackColor(name),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                      ),
                      if (isOwner) Spacer(),
                      if (isOwner)
                        const Text(
                          "Владелец",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isAdmin)
                  const Text(
                    "Админ",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _closeMemberContextMenu() {
    _memberContextMenu?.remove();
    _memberContextMenu = null;
  }

  void _showMemberContextMenu({
    required Offset position,
    required Map<String, dynamic> member,
    required bool isAdmin,
  }) {
    _closeMemberContextMenu();

    if (!_isCurrentUserOwner && !_isCurrentUserAdmin) {
      if (isAdmin ||
          member['id'] == _ownerId ||
          member['id'] == _currentUserId) {
        return;
      }
    }

    final overlay = Overlay.of(context);

    _memberContextMenu = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: _closeMemberContextMenu,
              behavior: HitTestBehavior.translucent,
              child: Container(),
            ),
            Positioned(
              left: position.dx,
              top: position.dy,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 4),
                        blurRadius: 20,
                        color: AppColors.black.withOpacity(0.15),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isCurrentUserOwner) ...[
                        if (isAdmin)
                          _ContextMenuItem(
                            icon: "assets/icons/admin_minus.png",
                            iconColor: AppColors.black,
                            text: "Сделать участником",
                            textColor: AppColors.black,
                            onTap: () async {
                              _closeMemberContextMenu();
                              await _demoteAdmin(member);
                            },
                          )
                        else
                          _ContextMenuItem(
                            icon: "assets/icons/admin.png",
                            iconColor: AppColors.black,
                            text: "Назначить администратором",
                            textColor: AppColors.black,
                            onTap: () async {
                              _closeMemberContextMenu();
                              await _promoteToAdmin(member);
                            },
                          ),
                        const SizedBox(height: 12),
                      ],

                      if ((_isCurrentUserOwner && member['id'] != _ownerId) ||
                          (_isCurrentUserAdmin && !isAdmin))
                        _ContextMenuItem(
                          icon: "assets/icons/circle_delete.png",
                          iconColor: AppColors.red,
                          text: "Удалить из списка",
                          textColor: AppColors.red,
                          onTap: () async {
                            _closeMemberContextMenu();
                            await _removeMember(member, isAdmin: isAdmin);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_memberContextMenu!);
  }

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.currentUserId;
    _initialLoadFuture = _loadExistingMembers();
    _loadCurrentUserAvatar();
  }

  Future<void> _loadCurrentUserAvatar() async {
    try {
      final user = await AppwriteService().fetchFullUser(_currentUserId);
      if (user != null) {
        setState(() {
          _currentUserAvatarUrl = user['avatar_url'];
        });
      }
    } catch (e) {
      print('Ошибка загрузки аватарки текущего пользователя: $e');
    }
  }

  Future<void> _loadExistingMembers() async {
    try {
      final listDoc = await AppwriteService().databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.listsCollectionId,
        documentId: widget.listId,
      );

      final listData = Map<String, dynamic>.from(listDoc.data);
      _ownerId = listData['owner_id'];
      _listName = listData['name'] ?? 'Список';

      final membersRaw = List<String>.from(listData['members'] ?? []);
      _adminIds = List<String>.from(listData['admins'] ?? []);

      final Set<String> userIds = {...membersRaw, ..._adminIds};

      final List<Map<String, dynamic>> loaded = [];

      for (final id in userIds) {
        final user = await AppwriteService().fetchFullUser(id);
        if (user != null) {
          loaded.add(user);
        }
      }

      setState(() {
        _addedMembers = loaded;
      });
    } catch (e) {
      print("Ошибка загрузки участников: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onClose,
          child: Container(color: Colors.black.withOpacity(0.25)),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Container(
                  width: 360,
                  constraints: const BoxConstraints(
                    minHeight: 450,
                    maxHeight: 600,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 4),
                        blurRadius: 20,
                        color: AppColors.black.withOpacity(0.15),
                      ),
                    ],
                  ),
                  child: FutureBuilder(
                    future: _initialLoadFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return SizedBox(
                          height: 450,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.black,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }

                      final admins = _addedMembers
                          .where((m) => _adminIds.contains(m['id']))
                          .toList();

                      final members = _addedMembers
                          .where(
                            (m) =>
                                !_adminIds.contains(m['id']) &&
                                m['id'] != _ownerId,
                          )
                          .toList();

                      final remainingMembers = widget.teamMembers.where((m) {
                        final id = m['id'];
                        return !_addedMembers.any((a) => a['id'] == id) &&
                            !_adminIds.contains(id) &&
                            id != _ownerId;
                      }).toList();

                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              child: Row(
                                children: [
                                  MouseRegion(
                                    onEnter: (_) =>
                                        setState(() => _isBackHovered = true),
                                    onExit: (_) =>
                                        setState(() => _isBackHovered = false),
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: widget.onClose,
                                      child: AnimatedScale(
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        scale: _isBackHovered ? 1.1 : 1.0,
                                        child: Image.asset(
                                          "assets/icons/back.png",
                                          width: 24,
                                          height: 24,
                                          color: AppColors.black.withOpacity(
                                            _isBackHovered ? 0.7 : 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: const Text(
                                        "Участники списка",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 38),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildUserRow(
                                    member: {
                                      'id': _ownerId,
                                      'name': widget.ownerName,
                                      'avatar_url': widget.ownerAvatarUrl,
                                    },
                                    isAdmin: false,
                                    isOwner: true,
                                  ),

                                  ...admins.map(
                                    (member) => _buildUserRow(
                                      member: member,
                                      isAdmin: true,
                                    ),
                                  ),

                                  ...members.map(
                                    (member) => _buildUserRow(
                                      member: member,
                                      isAdmin: false,
                                    ),
                                  ),

                                  if (remainingMembers.isNotEmpty) ...[
                                    const Text(
                                      "Добавить из команды",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],

                                  ...remainingMembers.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final member = entry.value;
                                    final name =
                                        member['name'] ?? 'Пользователь';
                                    final avatar = member['avatar_url'];

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          avatar != null
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(17),
                                                  child: Image.network(
                                                    avatar,
                                                    width: 40,
                                                    height: 40,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: _getFallbackColor(
                                                      name,
                                                    ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    name.isNotEmpty
                                                        ? name[0].toUpperCase()
                                                        : "?",
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: AppColors.black,
                                                    ),
                                                  ),
                                                ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.black,
                                              ),
                                            ),
                                          ),
                                          MouseRegion(
                                            onEnter: (_) => setState(
                                              () => _hoveredAddIndex = index,
                                            ),
                                            onExit: (_) => setState(
                                              () => _hoveredAddIndex = null,
                                            ),
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              onTap: () => _addMember(member),
                                              child: AnimatedScale(
                                                duration: const Duration(
                                                  milliseconds: 120,
                                                ),
                                                scale: _hoveredAddIndex == index
                                                    ? 1.2
                                                    : 1.0,
                                                child: Image.asset(
                                                  "assets/icons/add.png",
                                                  width: 24,
                                                  height: 24,
                                                  color: AppColors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (!_isCurrentUserOwner)
                  Positioned(
                    right: 15,
                    bottom: 15,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _leaveList,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Image.asset(
                            "assets/icons/exit.png",
                            width: 20,
                            height: 20,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ContextMenuItem extends StatelessWidget {
  final String icon;
  final Color iconColor;
  final String text;
  final Color textColor;
  final VoidCallback onTap;

  const _ContextMenuItem({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(icon, width: 20, height: 20, color: iconColor),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
