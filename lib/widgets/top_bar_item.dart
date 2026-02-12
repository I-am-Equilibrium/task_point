import 'dart:async';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/router/app_router.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/services/notifications_service.dart';
import 'package:task_point/services/task_model.dart';
import 'package:task_point/widgets/team_contacts_item.dart';
import 'package:task_point/widgets/notifications_item.dart';

class TopBarItem extends StatefulWidget {
  final VoidCallback onToggleSidebar;
  final List<TaskModel> Function() getAllTasks;
  final void Function(String taskId) scrollToTask;
  final void Function(String listId, {String? taskId}) openList;
  final void Function(String taskId) onShowTask;

  const TopBarItem({
    super.key,
    required this.onToggleSidebar,
    required this.getAllTasks,
    required this.scrollToTask,
    required this.openList,
    required this.onShowTask,
  });

  @override
  State<TopBarItem> createState() => _TopBarItemState();
}

class _TopBarItemState extends State<TopBarItem>
    with SingleTickerProviderStateMixin {
  final AppwriteService _appwriteService = AppwriteService();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _searchFieldKey = GlobalKey();

  late AnimationController _clearBtnController;
  late Animation<double> _clearBtnOpacity;

  OverlayEntry? _searchEntry;
  List<_SearchResult> _results = [];

  bool _isHoverAvatar = false;
  bool _isHoverMenu = false;
  bool _hasUnreadNotifications = false;

  Timer? _debounce;

  Uint8List? _avatarBytes;
  String? _avatarFilename;
  String? _avatarUrl;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isEmailChanged = false;

  OverlayEntry? _popupEntry;
  OverlayEntry? _teamEntry;
  OverlayEntry? _notificationsEntry;

  final List<Color> _avatarColors = [
    AppColors.green,
    AppColors.skyBlue,
    AppColors.lavendar,
    AppColors.cheese,
    AppColors.red,
  ];

  Color _getAvatarColor(String? input) {
    if (input == null || input.isEmpty) return AppColors.grey;
    return _avatarColors[input.hashCode % _avatarColors.length];
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkUnreadNotifications();

    _clearBtnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _clearBtnOpacity = CurvedAnimation(
      parent: _clearBtnController,
      curve: Curves.easeInOut,
    );

    _searchController.addListener(() {
      if (_searchController.text.isNotEmpty) {
        _clearBtnController.forward();
      } else {
        _clearBtnController.reverse();
      }
      setState(() {});
    });
  }

  Future<void> _checkUnreadNotifications() async {
    final user = authState.currentUser;
    if (user == null) return;

    try {
      final notificationsService = NotificationsService();
      final notifications = await notificationsService.getNotifications(
        user.$id,
      );

      final hasUnread = notifications.any((n) => n.isRead == false);

      if (mounted) {
        setState(() => _hasUnreadNotifications = hasUnread);
      }
    } catch (e) {
      print('❌ Ошибка при получении уведомлений: $e');
    }
  }

  Future<void> _loadUserData() async {
    final user = authState.currentUser;
    if (user == null) return;

    _nameController.text = user.name;
    _emailController.text = user.email;

    try {
      final doc = await _appwriteService.databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.usersCollectionId,
        documentId: user.$id,
      );
      final avatarUrl = doc.data['avatar_url'] as String?;
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        setState(() => _avatarUrl = avatarUrl);
      }
    } catch (_) {}

    _emailController.addListener(() {
      final u = authState.currentUser;
      if (u == null) return;
      setState(() {
        _isEmailChanged = _emailController.text.trim() != (u.email);
      });
    });
  }

  @override
  void dispose() {
    _popupEntry?.remove();
    _teamEntry?.remove();
    _notificationsEntry?.remove();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _searchEntry?.remove();
    _searchController.dispose();
    _clearBtnController.dispose();

    super.dispose();
  }

  Future _search(String query) async {
    if (query.trim().isEmpty) {
      _closeSearchOverlay();
      return;
    }
    final user = authState.currentUser;
    if (user == null) return;

    final allTasks = await _appwriteService.getAllAccessibleTasks(user.$id);
    final q = query.toLowerCase();
    final List<_SearchResult> found = [];

    for (final t in allTasks) {
      String? executorName;
      String? executorAvatar;
      bool matchPerformer = false;

      if (t.executor != null && t.executor!.isNotEmpty) {
        try {
          final userDoc = await _appwriteService.databases.getDocument(
            databaseId: AppwriteService.databaseId,
            collectionId: AppwriteService.usersCollectionId,
            documentId: t.executor!,
          );
          executorName = userDoc.data['name'];
          executorAvatar = userDoc.data['avatar_url'];

          if (executorName != null && executorName.toLowerCase().contains(q)) {
            matchPerformer = true;
          }
        } catch (e) {
          print("Ошибка загрузки данных исполнителя: $e");
        }
      }

      bool matchInvoice = t.invoice?.toLowerCase().contains(q) ?? false;
      bool matchCompany = t.company?.toLowerCase().contains(q) ?? false;
      bool matchProduct = t.products?.toLowerCase().contains(q) ?? false;

      if (matchInvoice || matchCompany || matchProduct || matchPerformer) {
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

        String displayMatchedText = "";
        if (matchInvoice)
          displayMatchedText = "Счет: ${t.invoice}";
        else if (matchCompany)
          displayMatchedText = "Компания: ${t.company}";
        else if (matchPerformer)
          displayMatchedText = "Исполнитель: $executorName";
        else
          displayMatchedText = "Товары: ${t.products}";

        found.add(
          _SearchResult(
            taskId: t.id,
            listId: t.listId ?? "",
            listName: listName,
            matchedText: displayMatchedText,
            executorName: executorName,
            executorAvatarUrl: executorAvatar,
          ),
        );
      }
    }

    _results = found;
    _showSearchOverlay();
  }

  void _showSearchOverlay() {
    _searchEntry?.remove();

    final renderBox =
        _searchFieldKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    _searchEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: offset.dy + renderBox.size.height + 10,
          left: offset.dx,
          width: 590,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50, maxHeight: 300),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.15),
                      offset: const Offset(0, 4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _results.map((r) {
                      bool hasExecutor = r.executorName != null;
                      bool hasAvatar =
                          r.executorAvatarUrl != null &&
                          r.executorAvatarUrl!.isNotEmpty;

                      return GestureDetector(
                        onTap: () {
                          _closeSearchOverlay();
                          if (r.listId.isNotEmpty) {
                            widget.openList(r.listId, taskId: r.taskId);
                          } else {
                            widget.scrollToTask(r.taskId);
                            widget.onShowTask(r.taskId);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasExecutor
                                      ? _getAvatarColor(r.executorName)
                                      : AppColors.lightGrey.withOpacity(0.3),
                                  image: hasAvatar
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            r.executorAvatarUrl!,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: !hasAvatar
                                    ? Center(
                                        child: hasExecutor
                                            ? Text(
                                                r.executorName![0]
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  color: AppColors.black,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.person,
                                                size: 20,
                                                color: AppColors.grey,
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
                                      "Список: ${r.listName}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      r.matchedText,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_searchEntry!);
  }

  void _closeSearchOverlay() {
    _searchEntry?.remove();
    _searchEntry = null;
  }

  Future<void> _pickAvatar() async {
    try {
      Uint8List? bytes;
      String? filename;

      if (kIsWeb) {
        final html.FileUploadInputElement uploadInput =
            html.FileUploadInputElement();
        uploadInput.accept = 'image/*';
        uploadInput.click();

        await uploadInput.onChange.first;
        if (uploadInput.files == null || uploadInput.files!.isEmpty) return;

        final file = uploadInput.files!.first;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;

        bytes = reader.result as Uint8List;
        filename = file.name;
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        final file = result.files.first;
        if (file.bytes == null) return;
        bytes = file.bytes!;
        filename = file.name;
      }

      if (bytes != null && filename != null) {
        setState(() {
          _avatarBytes = bytes;
          _avatarFilename = filename;
        });

        final user = authState.currentUser;
        if (user != null) {
          final success = await _appwriteService.uploadAvatarAndSaveToUser(
            userId: user.$id,
            bytes: bytes,
            filename: filename,
          );
          if (success) {
            final updatedDoc = await _appwriteService.databases.getDocument(
              databaseId: AppwriteService.databaseId,
              collectionId: AppwriteService.usersCollectionId,
              documentId: user.$id,
            );

            final newUrl = updatedDoc.data['avatar_url'] as String?;
            if (newUrl != null && newUrl.isNotEmpty) {
              setState(() => _avatarUrl = newUrl);
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Аватарка успешно обновлена'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Ошибка при обновлении аватарки'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Ошибка при выборе аватарки: $e');
    }
  }

  Future<void> _saveProfile() async {
    final user = authState.currentUser;
    if (user == null) return;

    String? avatarUrl = _avatarUrl;

    if (_avatarBytes != null && _avatarFilename != null) {
      avatarUrl = await _appwriteService.uploadAvatarFromBytes(
        bytes: _avatarBytes!,
        filename: _avatarFilename!,
      );
    }

    final ok = await _appwriteService.updateUserProfile(
      userId: user.$id,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      avatarUrl: avatarUrl,
      currentPasswordForEmailChange: _isEmailChanged
          ? _passwordController.text.trim()
          : null,
    );

    if (ok) {
      await authState.checkSession();
      if (mounted) {
        setState(() => _avatarUrl = avatarUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Профиль успешно обновлён!'),
            backgroundColor: Colors.green,
          ),
        );
        _closePopup();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Не удалось сохранить изменения'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _openTeamPanel() {
    if (_teamEntry != null) return;

    _teamEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeTeamPanel,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: 110,
              bottom: 0,
              right: 0,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                tween: Tween(begin: 300, end: 0),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(value, 0),
                    child: child,
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: 300,
                    child: TeamContactsItem(
                      onClose: _closeTeamPanel,
                      topBarHeight: 110,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_teamEntry!);
  }

  void _openNotificationsPanel() {
    if (_notificationsEntry != null) return;

    _notificationsEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              top: 110,
              bottom: 0,
              right: 0,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                tween: Tween(begin: 300, end: 0),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(value, 0),
                    child: child,
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: 300,
                    child: NotificationsItem(onClose: _closeNotificationsPanel),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_notificationsEntry!);
  }

  Future<void> _closeNotificationsPanel() async {
    _notificationsEntry?.remove();
    _notificationsEntry = null;

    final user = authState.currentUser;
    if (user == null) return;

    try {
      final notificationsService = NotificationsService();
      await notificationsService.markAllAsRead(user.$id);

      if (mounted) {
        setState(() => _hasUnreadNotifications = false);
      }
    } catch (e) {
      print('❌ Ошибка при отметке уведомлений как прочитанных: $e');
    }
  }

  void _closeTeamPanel() {
    _teamEntry?.remove();
    _teamEntry = null;
  }

  void _togglePopup() {
    if (_popupEntry != null) {
      _closePopup();
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    _popupEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: offset.dy + 85,
        right: 40,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff000000).withOpacity(0.15),
                  offset: const Offset(0, 4),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    behavior: HitTestBehavior.opaque,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[200],
                            image: _avatarBytes != null
                                ? DecorationImage(
                                    image: MemoryImage(_avatarBytes!),
                                    fit: BoxFit.cover,
                                  )
                                : (_avatarUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(_avatarUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null),
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.25),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildEditableField(
                  label: 'Имя пользователя',
                  controller: _nameController,
                ),
                const SizedBox(height: 8),
                _buildEditableField(
                  label: 'Эл. почта',
                  controller: _emailController,
                ),
                if (_isEmailChanged) ...[
                  const SizedBox(height: 8),
                  _buildEditableField(
                    label: 'Введите текущий пароль',
                    controller: _passwordController,
                    obscureText: true,
                  ),
                ],
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.skyBlue,
                    minimumSize: const Size(230, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Сохранить',
                    style: TextStyle(
                      color: AppColors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    await authState.logout();
                    if (mounted) context.go('/login');
                  },
                  child: const Text(
                    'Выйти из аккаунта',
                    style: TextStyle(
                      color: AppColors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_popupEntry!);
  }

  void _closePopup() {
    _popupEntry?.remove();
    _popupEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final user = authState.currentUser;

    final avatarDecoration = _avatarBytes != null
        ? DecorationImage(image: MemoryImage(_avatarBytes!), fit: BoxFit.cover)
        : (_avatarUrl != null
              ? DecorationImage(
                  image: NetworkImage(_avatarUrl!),
                  fit: BoxFit.cover,
                )
              : null);

    return Container(
      color: AppColors.darkWhite,
      padding: const EdgeInsets.only(top: 30, left: 40, right: 40, bottom: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _isHoverMenu = true),
            onExit: (_) => setState(() => _isHoverMenu = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onToggleSidebar,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                transform: Matrix4.identity()..scale(_isHoverMenu ? 1.1 : 1.0),
                child: const Icon(Icons.menu, size: 32),
              ),
            ),
          ),

          Container(
            key: _searchFieldKey,
            width: 590,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.black, width: 1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 20),
                  child: Icon(Icons.search, color: AppColors.black, size: 32),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();

                      _debounce = Timer(const Duration(milliseconds: 350), () {
                        _search(value);
                      });
                    },

                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Найти заметку...',
                      hintStyle: TextStyle(color: AppColors.grey, fontSize: 16),
                    ),
                  ),
                ),
                FadeTransition(
                  opacity: _clearBtnOpacity,
                  child: GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _closeSearchOverlay();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Image.asset(
                        'assets/icons/close.png',
                        width: 24,
                        height: 24,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Row(
            children: [
              const SizedBox(width: 12),
              _buildCircleButton('assets/icons/team.png', _openTeamPanel),

              const SizedBox(width: 5),
              _buildNotificationButton(
                'assets/icons/notifications.png',
                _openNotificationsPanel,
              ),

              const SizedBox(width: 12),
              MouseRegion(
                onEnter: (_) => setState(() => _isHoverAvatar = true),
                onExit: (_) => setState(() => _isHoverAvatar = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _togglePopup,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.skyBlue,
                      shape: BoxShape.circle,
                      image: avatarDecoration,
                      boxShadow: _isHoverAvatar
                          ? [
                              BoxShadow(
                                color: AppColors.skyBlue.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: avatarDecoration == null
                        ? Text(
                            (user?.name != null && user!.name!.isNotEmpty)
                                ? user.name![0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              color: AppColors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(String assetPath, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: AppColors.paper, width: 1.5),
          ),
          child: Center(child: Image.asset(assetPath, width: 25, height: 25)),
        ),
      ),
    );
  }

  Widget _buildNotificationButton(String assetPath, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          onTap();
          setState(() => _hasUnreadNotifications = false);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: AppColors.paper, width: 1.5),
              ),
              child: Center(
                child: Image.asset(assetPath, width: 25, height: 25),
              ),
            ),
            if (_hasUnreadNotifications)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.skyBlue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 230,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.black, width: 1),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 10),
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResult {
  final String taskId;
  final String listId;
  final String listName;
  final String matchedText;
  final String? executorName;
  final String? executorAvatarUrl;

  _SearchResult({
    required this.taskId,
    required this.listId,
    required this.listName,
    required this.matchedText,
    this.executorName,
    this.executorAvatarUrl,
  });
}
