import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:task_point/router/app_router.dart';
import 'package:task_point/constants/colors.dart';

class DesktopLoginLayout extends StatefulWidget {
  const DesktopLoginLayout({super.key});

  @override
  State<DesktopLoginLayout> createState() => _DesktopLoginLayoutState();
}

class _DesktopLoginLayoutState extends State<DesktopLoginLayout> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _loginUser() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Поля не могут быть пустыми';
        _isLoading = false;
      });
      return;
    }

    final success = await authState.login(email, password);

    if (success && mounted) {
      context.go('/home');
    } else {
      setState(() {
        _errorMessage = 'Неверная почта или пароль';
      });
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

  Widget _buildAnimatedError() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: _errorMessage == null ? 15 : 35,
      alignment: Alignment.center,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _errorMessage == null ? 0 : 1,
        child: Text(
          _errorMessage ?? '',
          textAlign: TextAlign.center,
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
              'assets/images/background_login_image.png',
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
                    'С возвращением!',
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
                      controller: _emailController,
                      cursorColor: AppColors.asphalt,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: AppColors.black,
                      ),
                      decoration: _inputDecoration('Введите почту'),
                    ),
                  ),
                  const SizedBox(height: 15),

                  SizedBox(
                    width: 440,
                    height: 60,
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      cursorColor: AppColors.asphalt,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: AppColors.black,
                      ),
                      decoration: _inputDecoration('Введите пароль').copyWith(
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.black,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  _buildAnimatedError(),
                  const SizedBox(height: 15),

                  SizedBox(
                    width: 440,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.skyBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _isLoading ? null : _loginUser,
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: AppColors.black,
                            )
                          : const Text(
                              'Войти',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _HoverableRegisterText(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverableRegisterText extends StatefulWidget {
  const _HoverableRegisterText();

  @override
  State<_HoverableRegisterText> createState() => _HoverableRegisterTextState();
}

class _HoverableRegisterTextState extends State<_HoverableRegisterText> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => context.go('/register'),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: _isHovered ? AppColors.skyBlue : AppColors.black,
            decoration: _isHovered
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
          child: const Text('Нет аккаунта? Зарегистрироваться'),
        ),
      ),
    );
  }
}
