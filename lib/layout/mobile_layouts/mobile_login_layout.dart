import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:task_point/router/app_router.dart';
import 'package:task_point/constants/colors.dart';

class MobileLoginLayout extends StatefulWidget {
  const MobileLoginLayout({super.key});

  @override
  State<MobileLoginLayout> createState() => _MobileLoginLayoutState();
}

class _MobileLoginLayoutState extends State<MobileLoginLayout> {
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
      setState(() => _errorMessage = 'Неверная почта или пароль');
    }

    setState(() => _isLoading = false);
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 16,
        color: AppColors.black.withOpacity(0.6),
      ),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      height: _errorMessage == null ? 10 : 30,
      alignment: Alignment.center,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _errorMessage == null ? 0 : 1,
        child: Text(
          _errorMessage ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.red, fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).size.width > 500 ? 80.0 : 30.0;

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
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/moydodyrof_logo.jpg',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'С возвращением!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: AppColors.asphalt,
                    ),
                  ),
                  const SizedBox(height: 30),

                  TextField(
                    controller: _emailController,
                    cursorColor: AppColors.asphalt,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.black,
                    ),
                    decoration: _inputDecoration('Введите почту'),
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    cursorColor: AppColors.asphalt,
                    style: const TextStyle(
                      fontSize: 16,
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

                  _buildAnimatedError(),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
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
                                fontSize: 18,
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

class _HoverableRegisterText extends StatelessWidget {
  const _HoverableRegisterText();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/register'),
      child: const Text(
        'Нет аккаунта? Зарегистрироваться',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.black,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
