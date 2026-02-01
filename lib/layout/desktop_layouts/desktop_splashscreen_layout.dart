import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:task_point/router/app_router.dart' as router;

class DesktopSplashScreenLayout extends StatefulWidget {
  const DesktopSplashScreenLayout({super.key});

  @override
  State<DesktopSplashScreenLayout> createState() =>
      _DesktopSplashScreenLayoutState();
}

class _DesktopSplashScreenLayoutState extends State<DesktopSplashScreenLayout> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Проверяем, авторизован ли пользователь
    await router.authState.checkSession();

    if (!mounted) return;

    if (router.authState.isVerified) {
      context.go('/home'); // Если авторизован, на главную
    } else {
      context.go('/login'); // Если нет — на экран логина
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
