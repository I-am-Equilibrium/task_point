import 'dart:async';
import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/router/app_router.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/services/notifications_service.dart';

class MobileTeamContactsItem extends StatefulWidget {
  const MobileTeamContactsItem({super.key});

  @override
  State<MobileTeamContactsItem> createState() => _MobileTeamContactsItemState();
}

class _MobileTeamContactsItemState extends State<MobileTeamContactsItem> {
  final TextEditingController _searchController = TextEditingController();
  final NotificationsService _notificationsService = NotificationsService();

  bool _isSearchMode = false;
  bool _isLoading = true;
  bool _isLoadingSearch = false;

  List<Map<String, dynamic>> _teamContacts = [];
  List<Map<String, dynamic>> _searchResults = [];
  Set<String> _addedContacts = {};

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadTeamContacts();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamContacts() async {
    final service = AppwriteService();
    final current = authState.currentUser;
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
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки контактов: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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

    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      final service = AppwriteService();
      try {
        final results = await service.searchUsers(text.trim());
        final current = authState.currentUser;

        final filtered = results.where((u) => u['id'] != current?.$id).toList();

        if (mounted) {
          setState(() {
            _searchResults = filtered;
            _isLoadingSearch = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingSearch = false);
      }
    });
  }

  Future<void> _addUserToTeam(Map<String, dynamic> user) async {
    final service = AppwriteService();
    final current = authState.currentUser;
    if (current == null) return;

    setState(() {
      _addedContacts.add(user['id']);
    });

    final success = await service.addUserToTeamContacts(
      ownerId: current.$id,
      contactId: user['id'],
    );

    if (!success) {
      if (mounted) {
        setState(() => _addedContacts.remove(user['id']));
      }
      return;
    }

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
    if (fullUser != null && mounted) {
      final count = await service.getAssignedTasksCount(user['id']);
      fullUser['tasks_assigned_count'] = count;

      setState(() {
        if (!_teamContacts.any((u) => u['id'] == fullUser['id'])) {
          _teamContacts.add(fullUser);
        }
      });
    }
  }

  Future<void> _deleteContact(String userId) async {
    final service = AppwriteService();
    final current = authState.currentUser;
    if (current == null) return;

    Navigator.pop(context);

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
      });
    }
  }

  void _showContactOptions(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                user['name'] ?? 'Пользователь',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: AppColors.black),
                title: const Text('Добавить в список задач'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToListSheet(user['id']);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove, color: AppColors.red),
                title: const Text(
                  'Удалить из команды',
                  style: TextStyle(color: AppColors.red),
                ),
                onTap: () => _deleteContact(user['id']),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddToListSheet(String userId) async {
    final service = AppwriteService();
    final current = authState.currentUser;
    if (current == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final lists = await service.getManageableLists();

    final filtered = lists.where((list) {
      final admins = List<String>.from(list['admins'] ?? []);
      final members = List<String>.from(list['members'] ?? []);
      final ownerId = list['owner_id'];

      final bool canManage =
          ownerId == current.$id || admins.contains(current.$id);
      if (!canManage) return false;

      final bool alreadyInList =
          ownerId == userId ||
          admins.contains(userId) ||
          members.contains(userId);

      return !alreadyInList;
    }).toList();

    if (mounted) Navigator.pop(context);

    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Нет доступных списков или пользователь уже добавлен',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'Выберите список',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final list = filtered[index];

                    Color listColor = AppColors.skyBlue;
                    if (list['color'] != null) {
                      if (list['color'] is int) {
                        listColor = Color(list['color']);
                      } else if (list['color'] is String) {
                        final intVal = int.tryParse(list['color'].toString());
                        if (intVal != null) {
                          listColor = Color(intVal);
                        }
                      }
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      title: Text(
                        list['title'],
                        style: TextStyle(
                          color: listColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(context);

                        await service.addUserToList(
                          listId: list['id'],
                          userId: userId,
                        );

                        final fullCurrentUser = await service.fetchFullUser(
                          current.$id,
                        );
                        final String? senderAvatarUrl =
                            fullCurrentUser?['avatar_url']?.toString();

                        await _notificationsService.createNotification(
                          senderId: current.$id,
                          receiverId: userId,
                          senderAvatarUrl: senderAvatarUrl,
                          text: 'Вас добавили в список "${list['title']}"',
                          type: 'added_to_list',
                        );

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Добавлен в список "${list['title']}"',
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkWhite,
      appBar: _buildAppBar(),
      body: _isSearchMode ? _buildSearchView() : _buildTeamView(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: AppColors.black,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: _isSearchMode
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: AppColors.black),
              decoration: const InputDecoration(
                hintText: 'Поиск пользователей...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppColors.grey),
              ),
              onChanged: _onSearchChanged,
            )
          : const Text(
              'Ваша команда',
              style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearchMode ? Icons.close : Icons.search,
            color: AppColors.black,
          ),
          onPressed: () {
            setState(() {
              _isSearchMode = !_isSearchMode;
              if (!_isSearchMode) {
                _searchController.clear();
                _searchResults = [];
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildTeamView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.skyBlue),
      );
    }

    if (_teamContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'В вашей команде пока никого нет',
              style: TextStyle(color: AppColors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 15),
      itemCount: _teamContacts.length,
      itemBuilder: (context, index) {
        return _buildUserCard(_teamContacts[index], isTeamMember: true);
      },
    );
  }

  Widget _buildSearchView() {
    if (_isLoadingSearch) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.skyBlue),
      );
    }

    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(
        child: Text(
          'Пользователи не найдены',
          style: TextStyle(color: AppColors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 15),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildUserCard(_searchResults[index], isTeamMember: false);
      },
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic> user, {
    required bool isTeamMember,
  }) {
    final String name = user['name'] ?? 'Без имени';
    final String email = user['email'] ?? '';
    final String? avatarUrl = user['avatar_url'];

    int tasksCount = 0;
    if (user['tasks_assigned_count'] != null) {
      tasksCount = user['tasks_assigned_count'] is int
          ? user['tasks_assigned_count']
          : int.tryParse(user['tasks_assigned_count'].toString()) ?? 0;
    }

    final bool isAdded = _addedContacts.contains(user['id']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarUrl == null ? AppColors.skyBlue : null,
              image: avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email,
                  style: const TextStyle(color: AppColors.grey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isTeamMember)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Задач в работе: $tasksCount',
                      style: const TextStyle(
                        color: AppColors.skyBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isTeamMember)
            IconButton(
              icon: const Icon(Icons.more_vert, color: AppColors.grey),
              onPressed: () => _showContactOptions(user),
            )
          else
            IconButton(
              icon: Icon(
                isAdded ? Icons.check_circle : Icons.add_circle,
                color: isAdded ? AppColors.green : AppColors.black,
                size: 28,
              ),
              onPressed: isAdded ? null : () => _addUserToTeam(user),
            ),
        ],
      ),
    );
  }
}
