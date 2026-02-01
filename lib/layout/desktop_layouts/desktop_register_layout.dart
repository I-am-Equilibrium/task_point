import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/router/app_router.dart';

class DesktopRegisterLayout extends StatefulWidget {
  const DesktopRegisterLayout({super.key});

  @override
  State<DesktopRegisterLayout> createState() => _DesktopRegisterLayoutState();
}

class _DesktopRegisterLayoutState extends State<DesktopRegisterLayout> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _showErrors = false;
  bool _isLoading = false;

  String? _nameError;
  String? _emailError;
  String? _passwordError;

  void _validateFields() {
    final emailPattern = RegExp(r'^[\w.-]+@moydodyrof\.ru$');
    final emailText = _emailController.text.trim();
    final passwordText = _passwordController.text;
    final nameText = _nameController.text.trim();

    setState(() {
      _nameError = nameText.isEmpty ? 'Введите имя' : null;
      _emailError = emailText.isEmpty
          ? 'Введите почту'
          : (!emailPattern.hasMatch(emailText)
                ? 'Почта должна оканчиваться на @moydodyrof.ru'
                : null);
      _passwordError = passwordText.isEmpty
          ? 'Введите пароль'
          : (passwordText.length < 8
                ? 'Пароль должен содержать минимум 8 символов'
                : null);
    });
  }

  Future<void> _onRegisterPressed() async {
    setState(() {
      _showErrors = true;
      _isLoading = true;
    });

    _validateFields();

    if (_nameError != null || _emailError != null || _passwordError != null) {
      setState(() => _isLoading = false);
      return;
    }

    final success = await authState.register(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _nameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ошибка регистрации или сохранения данных в базу данных.',
          ),
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: AppColors.black.withOpacity(0.6),
      ),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: AppColors.asphalt, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: AppColors.asphalt, width: 1.5),
      ),
    );
  }

  Widget _buildError(String? text) {
    final visible = _showErrors && text != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: visible ? 21 : 15,
      width: 440,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 20),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: visible ? 1.0 : 0.0,
        child: Text(
          text ?? '',
          style: const TextStyle(
            color: AppColors.red,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_register_image.png',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/moydodyrof_logo.jpg',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Добро пожаловать',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: AppColors.asphalt,
                    ),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: 440,
                    height: 60,
                    child: TextField(
                      controller: _nameController,
                      cursorColor: AppColors.asphalt,
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.black,
                      ),
                      decoration: _inputDecoration('Введите имя'),
                    ),
                  ),
                  _buildError(_nameError),

                  SizedBox(
                    width: 440,
                    height: 60,
                    child: TextField(
                      controller: _emailController,
                      cursorColor: AppColors.asphalt,
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.black,
                      ),
                      decoration: _inputDecoration('Введите почту'),
                    ),
                  ),
                  _buildError(_emailError),

                  SizedBox(
                    width: 440,
                    height: 60,
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      cursorColor: AppColors.asphalt,
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.black,
                      ),
                      decoration: _inputDecoration('Введите пароль').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.black,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildError(_passwordError),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: 440,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _onRegisterPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lavendar,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: AppColors.black,
                            )
                          : const Text(
                              'Зарегистрироваться',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _HoverableLoginText(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverableLoginText extends StatefulWidget {
  const _HoverableLoginText();

  @override
  State<_HoverableLoginText> createState() => _HoverableLoginTextState();
}

class _HoverableLoginTextState extends State<_HoverableLoginText> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go('/login'),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: _hovered ? AppColors.lavendar : AppColors.black,
            decoration: _hovered
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
          child: const Text('Уже есть аккаунт? Войти'),
        ),
      ),
    );
  }
}
