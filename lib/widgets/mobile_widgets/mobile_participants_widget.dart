import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/services/notifications_service.dart';

class MobileParticipantsWidget extends StatefulWidget {
  final VoidCallback onClose;
  final String ownerName;
  final String? ownerAvatarUrl;
  final VoidCallback? onMemberAdded;
  final VoidCallback? onLeaveList;

  final List<Map<String, dynamic>> teamMembers;
  final String listId;
  final String currentUserId;

  const MobileParticipantsWidget({
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
  State<MobileParticipantsWidget> createState() =>
      _MobileParticipantsWidgetState();
}

class _MobileParticipantsWidgetState extends State<MobileParticipantsWidget> {
  List<Map<String, dynamic>> _addedMembers = [];
  List<String> _adminIds = [];

  late String _currentUserId;
  String? _currentUserAvatarUrl;

  // Геттеры для прав доступа
  bool get _isCurrentUserOwner => _currentUserId == _ownerId;
  bool get _isCurrentUserAdmin => _adminIds.contains(_currentUserId);

  late Future<void> _initialLoadFuture;
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
      if (user != null && mounted) {
        setState(() {
          _currentUserAvatarUrl = user['avatar_url'];
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки аватарки: $e');
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

      if (mounted) {
        setState(() {
          _addedMembers = loaded;
        });
      }
    } catch (e) {
      debugPrint("Ошибка загрузки участников: $e");
    }
  }

  // --- ЛОГИКА ДЕЙСТВИЙ (ADD, REMOVE, PROMOTE, DEMOTE, LEAVE) ---

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

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Участник добавлен')));
      }
    } catch (e) {
      debugPrint('Ошибка при добавлении: $e');
    }
  }

  Future<void> _leaveList() async {
    try {
      if (_isCurrentUserOwner)
        return; // Владелец не может выйти просто так (обычно)

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
      widget.onClose(); // Закрываем экран
    } catch (e) {
      debugPrint('Ошибка при выходе из списка: $e');
    }
  }

  Future<void> _promoteToAdmin(Map<String, dynamic> member) async {
    final userId = member['id'];
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
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Ошибка назначения админа: $e');
    }
  }

  Future<void> _demoteAdmin(Map<String, dynamic> member) async {
    final userId = member['id'];
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
      if (mounted) Navigator.pop(context); // Закрыть BottomSheet
    } catch (e) {
      debugPrint("Ошибка разжалования админа: $e");
    }
  }

  Future<void> _removeMember(
    Map<String, dynamic> member, {
    bool isAdmin = false,
  }) async {
    final memberId = member['id'];
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
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Ошибка удаления участника: $e");
    }
  }

  // --- UI КОМПОНЕНТЫ ---

  void _showMemberActionSheet({
    required Map<String, dynamic> member,
    required bool isAdmin,
  }) {
    // Проверка прав на открытие меню
    if (!_isCurrentUserOwner && !_isCurrentUserAdmin) return;
    // Админ не может управлять Владельцем или другими Админами (обычно)
    // Владелец может управлять всеми.
    if (!_isCurrentUserOwner && (isAdmin || member['id'] == _ownerId)) return;

    // Не открываем меню для самого себя
    if (member['id'] == _currentUserId) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  member['name'] ?? 'Участник',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 15),

                // Кнопка назначения/снятия админа (только для Владельца)
                if (_isCurrentUserOwner)
                  ListTile(
                    leading: Image.asset(
                      isAdmin
                          ? "assets/icons/admin_minus.png"
                          : "assets/icons/admin.png",
                      width: 24,
                      color: AppColors.black,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.shield_outlined),
                    ),
                    title: Text(
                      isAdmin
                          ? "Сделать участником"
                          : "Назначить администратором",
                    ),
                    onTap: () async {
                      if (isAdmin) {
                        await _demoteAdmin(member);
                      } else {
                        await _promoteToAdmin(member);
                      }
                    },
                  ),

                // Кнопка удаления (Владелец удаляет всех, Админ удаляет обычных участников)
                if ((_isCurrentUserOwner && member['id'] != _ownerId) ||
                    (_isCurrentUserAdmin && !isAdmin))
                  ListTile(
                    leading: Image.asset(
                      "assets/icons/circle_delete.png",
                      width: 24,
                      color: AppColors.red,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.red,
                      ),
                    ),
                    title: const Text(
                      "Удалить из списка",
                      style: TextStyle(color: AppColors.red),
                    ),
                    onTap: () async {
                      await _removeMember(member, isAdmin: isAdmin);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserRow({
    required Map<String, dynamic> member,
    required bool isAdmin,
    bool isOwner = false,
  }) {
    final name = member['name'] ?? 'Пользователь';
    final avatar = member['avatar_url'];
    final userId = member['id'];

    // Определяем, можем ли мы управлять этим юзером
    final canManage =
        (_isCurrentUserOwner && userId != _currentUserId) ||
        (_isCurrentUserAdmin &&
            !isAdmin &&
            !isOwner &&
            userId != _currentUserId);

    return InkWell(
      onTap: canManage
          ? () => _showMemberActionSheet(member: member, isAdmin: isAdmin)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        child: Row(
          children: [
            // Аватар
            avatar != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
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
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.black,
                      ),
                    ),
                  ),
            const SizedBox(width: 12),

            // Имя и роль
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
                  ),
                  if (isOwner)
                    const Text(
                      "Владелец",
                      // Владелец теперь SkyBlue
                      style: TextStyle(fontSize: 12, color: AppColors.skyBlue),
                    )
                  else if (isAdmin)
                    const Text(
                      "Администратор",
                      // Администратор теперь серый
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),

            // Иконка "опции", если можно управлять
            if (canManage) const Icon(Icons.more_vert, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMemberRow(int index, Map<String, dynamic> member) {
    final name = member['name'] ?? 'Пользователь';
    final avatar = member['avatar_url'];

    return InkWell(
      onTap: () => _addMember(member),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        child: Row(
          children: [
            avatar != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
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
                      name.isNotEmpty ? name[0].toUpperCase() : "?",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.black,
                      ),
                    ),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: AppColors.black, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60.0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            backgroundColor: AppColors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.black),
              onPressed: widget.onClose,
            ),
            title: const Text(
              "Участники",
              style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: FutureBuilder(
            future: _initialLoadFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.black,
                    strokeWidth: 2,
                  ),
                );
              }

              final admins = _addedMembers
                  .where((m) => _adminIds.contains(m['id']))
                  .toList();

              final members = _addedMembers
                  .where(
                    (m) => !_adminIds.contains(m['id']) && m['id'] != _ownerId,
                  )
                  .toList();

              final remainingMembers = widget.teamMembers.where((m) {
                final id = m['id'];
                return !_addedMembers.any((a) => a['id'] == id) &&
                    !_adminIds.contains(id) &&
                    id != _ownerId;
              }).toList();

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),

                          // Владелец
                          _buildUserRow(
                            member: {
                              'id': _ownerId,
                              'name': widget.ownerName,
                              'avatar_url': widget.ownerAvatarUrl,
                            },
                            isAdmin: false,
                            isOwner: true,
                          ),

                          // Админы
                          ...admins.map(
                            (m) => _buildUserRow(member: m, isAdmin: true),
                          ),

                          // Обычные участники
                          ...members.map(
                            (m) => _buildUserRow(member: m, isAdmin: false),
                          ),

                          // Секция добавления новых
                          if (remainingMembers.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                              child: Text(
                                "Добавить из команды",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            ...remainingMembers.asMap().entries.map(
                              (e) => _buildAddMemberRow(e.key, e.value),
                            ),
                          ],

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),

                  if (!_isCurrentUserOwner)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20.0,
                        right: 20,
                        bottom: 60,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _leaveList,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.exit_to_app,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Выйти из списка",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
