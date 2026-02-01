import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:task_point/router/app_router.dart' as router;

class MobileSplashScreenLayout extends StatefulWidget {
  const MobileSplashScreenLayout({super.key});

  @override
  State<MobileSplashScreenLayout> createState() =>
      _MobileSplashScreenLayoutState();
}

class _MobileSplashScreenLayoutState extends State<MobileSplashScreenLayout> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await router.authState.checkSession();

    if (!mounted) return;

    if (router.authState.isVerified) {
      context.go('/home'); // Переход на главный экран
    } else {
      context.go('/login'); // Переход на экран входа
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
