import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/router/app_router.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/services/notifications_service.dart';
import 'mobile_profile_item.dart';
import 'mobile_notifications_item.dart';
import 'mobile_team_contacts_item.dart';

class _SearchResult {
  final String taskId;
  final String listId;
  final String listName;
  final String matchedText;

  _SearchResult({
    required this.taskId,
    required this.listId,
    required this.listName,
    required this.matchedText,
  });
}

class MobileTopBarItem extends StatefulWidget implements PreferredSizeWidget {
  final void Function(String taskId) scrollToTask;
  final void Function(String listId) openList;
  final void Function(String listId, String taskId) onSearchResultTap;

  const MobileTopBarItem({
    super.key,
    required this.scrollToTask,
    required this.openList,
    required this.onSearchResultTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  State<MobileTopBarItem> createState() => _MobileTopBarItemState();
}

class _MobileTopBarItemState extends State<MobileTopBarItem> {
  final AppwriteService _appwriteService = AppwriteService();
  final _searchController = TextEditingController();
  final GlobalKey _searchKey = GlobalKey();

  bool _showSearch = false;
  bool _hasUnreadNotifications = false;
  String? _avatarUrl;

  OverlayEntry? _searchEntry;
  List<_SearchResult> _results = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _checkUnreadNotifications();
  }

  @override
  void dispose() {
    _closeSearchOverlay();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _results = [];
      _closeSearchOverlay();
      return;
    }

    final user = authState.currentUser;
    if (user == null) return;

    final allTasks = await _appwriteService.getAllAccessibleTasks(user.$id);
    final q = query.toLowerCase();
    final List<_SearchResult> found = [];

    for (final t in allTasks) {
      bool matchInvoice = t.invoice?.toLowerCase().contains(q) ?? false;
      bool matchCompany = t.company?.toLowerCase().contains(q) ?? false;
      bool matchProduct = t.products?.toLowerCase().contains(q) ?? false;

      if (matchInvoice || matchCompany || matchProduct) {
        String listName = "Без списка";
        if (t.listId != null && t.listId!.isNotEmpty) {
          try {
            final listDoc = await _appwriteService.databases.getDocument(
              databaseId: AppwriteService.databaseId,
              collectionId: AppwriteService.listsCollectionId,
              documentId: t.listId!,
            );
            listName = listDoc.data['name'];
          } catch (_) {}
        }

        found.add(
          _SearchResult(
            taskId: t.id,
            listId: t.listId ?? "",
            listName: listName,
            matchedText: matchInvoice
                ? t.invoice!
                : matchCompany
                ? t.company!
                : t.products ?? "",
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _results = found);
      if (_results.isNotEmpty && _showSearch) {
        _showSearchOverlay();
      } else {
        _closeSearchOverlay();
      }
    }
  }

  void _showSearchOverlay() {
    _closeSearchOverlay();

    final RenderBox? renderBox =
        _searchKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final width = renderBox.size.width;

    _searchEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: offset.dy + renderBox.size.height + 8,
        left: offset.dx,
        width: width,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: ListView.separated(
                padding: const EdgeInsets.all(10),
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.paper),
                itemBuilder: (context, index) {
                  final r = _results[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    title: Text(
                      "Список: ${r.listName}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      r.matchedText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      _toggleSearch();
                      widget.onSearchResultTap(r.listId, r.taskId);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_searchEntry!);
  }

  void _closeSearchOverlay() {
    _searchEntry?.remove();
    _searchEntry = null;
  }

  void _toggleSearch() {
    setState(() {
      if (_showSearch) {
        _closeSearchOverlay();
        _searchController.clear();
      }
      _showSearch = !_showSearch;
    });
  }

  Future<void> _checkUnreadNotifications() async {
    final user = authState.currentUser;
    if (user == null) return;
    try {
      final notifications = await NotificationsService().getNotifications(
        user.$id,
      );
      final hasUnread = notifications.any((n) => n.isRead == false);
      if (mounted) setState(() => _hasUnreadNotifications = hasUnread);
    } catch (_) {}
  }

  Future<void> _loadAvatar() async {
    final user = authState.currentUser;
    if (user == null) return;
    try {
      final doc = await _appwriteService.databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.usersCollectionId,
        documentId: user.$id,
      );
      final url = doc.data['avatar_url'] as String?;
      if (mounted) setState(() => _avatarUrl = url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: AppColors.darkWhite.withOpacity(0.7),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: SizedBox(
                  height: 45,
                  child: Row(
                    children: [
                      if (!_showSearch) ...[
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MobileProfileItem(),
                              ),
                            );
                            _loadAvatar();
                          },
                          child: _buildAvatar(),
                        ),
                        const Spacer(),
                        _iconBtn(
                          asset: 'assets/icons/search.png',
                          onTap: _toggleSearch,
                          applyColor: false,
                        ),
                        const SizedBox(width: 8),
                        _iconBtn(
                          asset: 'assets/icons/team.png',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MobileTeamContactsItem(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _iconBtn(
                          asset: 'assets/icons/notifications.png',
                          showDot: _hasUnreadNotifications,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MobileNotificationsItem(),
                              ),
                            );
                            _checkUnreadNotifications();
                          },
                        ),
                      ] else ...[
                        Expanded(
                          child: Container(
                            key: _searchKey,
                            decoration: BoxDecoration(
                              color: AppColors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.black.withOpacity(0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                Image.asset(
                                  'assets/icons/search.png',
                                  width: 18,
                                  height: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    style: const TextStyle(fontSize: 16),
                                    decoration: const InputDecoration(
                                      hintText: 'Поиск задач...',
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                    ),
                                    onChanged: (val) {
                                      _debounce?.cancel();
                                      _debounce = Timer(
                                        const Duration(milliseconds: 350),
                                        () => _search(val),
                                      );
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    size: 20,
                                    color: AppColors.black,
                                  ),
                                  onPressed: _toggleSearch,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final user = authState.currentUser;
    final bool hasAvatar = _avatarUrl != null && _avatarUrl!.trim().isNotEmpty;
    final String firstLetter = (user?.name.isNotEmpty == true)
        ? user!.name.trim()[0].toUpperCase()
        : 'A';

    return Container(
      width: 45,
      height: 45,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasAvatar ? null : AppColors.skyBlue,
        image: hasAvatar
            ? DecorationImage(
                image: NetworkImage(_avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: !hasAvatar
          ? Text(
              firstLetter,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            )
          : null,
    );
  }

  Widget _iconBtn({
    required String asset,
    required VoidCallback onTap,
    bool applyColor = true,
    bool showDot = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.paper.withOpacity(0.2)),
            ),
            child: Center(
              child: Image.asset(
                asset,
                width: 20,
                height: 20,
                color: applyColor ? AppColors.black : null,
              ),
            ),
          ),
          if (showDot)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.skyBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
