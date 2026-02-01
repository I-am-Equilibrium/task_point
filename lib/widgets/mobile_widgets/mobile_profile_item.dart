import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/router/app_router.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class MobileProfileItem extends StatefulWidget {
  const MobileProfileItem({super.key});

  @override
  State<MobileProfileItem> createState() => _MobileProfileItemState();
}

class _MobileProfileItemState extends State<MobileProfileItem> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  final AppwriteService _appwriteService = AppwriteService();

  Uint8List? _avatarBytes;
  String? _avatarFilename;
  String? _avatarUrl;

  final _passwordController = TextEditingController();
  bool _isEmailChanged = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _emailController.addListener(() {
      final u = authState.currentUser;
      if (u == null) return;
      setState(() {
        _isEmailChanged = _emailController.text.trim() != u.email;
      });
    });
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _avatarBytes = file.bytes;
      _avatarFilename = file.name;
    });
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
            content: Text('✅ Профиль обновлён'),
            backgroundColor: Colors.green,
          ),
        );
      }
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
      setState(() {
        _avatarUrl = doc.data['avatar_url'];
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = authState.currentUser;

    return Scaffold(
      backgroundColor: AppColors.darkWhite,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),

            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Image.asset(
                    'assets/icons/back.png',
                    width: 48,
                    height: 48,
                    color: AppColors.black,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.skyBlue,
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
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.25),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            _label('Имя пользователя'),
            _field(_nameController),

            const SizedBox(height: 5),

            _label('Эл. почта'),
            _field(_emailController),

            if (_isEmailChanged) ...[
              const SizedBox(height: 10),
              _label('Текущий пароль'),
              _field(_passwordController, obscure: true),
            ],

            const SizedBox(height: 15),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.skyBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Сохранить',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            GestureDetector(
              onTap: () async {
                await authState.logout();
                if (context.mounted) {
                  Navigator.popUntil(context, (r) => r.isFirst);
                }
              },
              child: const Text(
                'Выйти из аккаунта',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 35, bottom: 2, top: 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.black,
        ),
      ),
    ),
  );

  Widget _field(TextEditingController controller, {bool obscure = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.paper),
            ),
          ),
        ),
      );
}
