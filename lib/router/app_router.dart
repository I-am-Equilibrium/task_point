// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:appwrite/models.dart';
import 'package:task_point/services/appwrite_service.dart';

import 'package:task_point/layout/desktop_layouts/desktop_login_layout.dart';
import 'package:task_point/layout/desktop_layouts/desktop_register_layout.dart';
import 'package:task_point/layout/desktop_layouts/desktop_layout.dart';
import 'package:task_point/layout/desktop_layouts/desktop_splashscreen_layout.dart';

import 'package:task_point/layout/mobile_layouts/mobile_login_layout.dart';
import 'package:task_point/layout/mobile_layouts/mobile_register_layout.dart';
import 'package:task_point/layout/mobile_layouts/mobile_layout.dart';
import 'package:task_point/layout/mobile_layouts/mobile_splashscreen_layout.dart';

bool isMobile(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return width < 700;
}

class AuthState extends ChangeNotifier {
  final AppwriteService _appwrite = AppwriteService();
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isVerified => _currentUser != null;

  Future<void> checkSession() async {
    _currentUser = await _appwrite.getCurrentUser();
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    final session = await _appwrite.login(email: email, password: password);
    if (session != null) {
      await checkSession();
      return true;
    }
    return false;
  }

  Future<bool> register(String email, String password, String name) async {
    try {
      final user = await _appwrite.registerAndReturnUser(
        email: email,
        password: password,
        name: name,
      );
      if (user == null) return false;
      final session = await _appwrite.login(email: email, password: password);
      if (session == null) return false;

      await checkSession();

      final created = await _appwrite.createUserDocument(
        userId: user.$id,
        email: email,
        name: name,
      );

      if (!created) {
        print(
          '⚠️ Документ в таблице users не был создан (посмотрите логи AppwriteService).',
        );
      }

      print('✅ Пользователь успешно зарегистрирован и сохранён в базе');
      return true;
    } catch (e) {
      print('❌ Ошибка при регистрации: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _appwrite.logout();
    _currentUser = null;
    notifyListeners();
  }
}

final AuthState authState = AuthState();

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: authState,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => isMobile(context)
          ? const MobileSplashScreenLayout()
          : const DesktopSplashScreenLayout(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => isMobile(context)
          ? const MobileLoginLayout()
          : const DesktopLoginLayout(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => isMobile(context)
          ? const MobileRegisterLayout()
          : const DesktopRegisterLayout(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => isMobile(context)
          ? MobileLayout(fontSize: 14)
          : DesktopLayout(fontSize: 16, listId: ''),
    ),
  ],

  redirect: (context, state) {
    final loggedIn = authState.isVerified;
    final goingToLogin = state.matchedLocation == '/login';
    final goingToRegister = state.matchedLocation == '/register';

    if (!loggedIn && state.matchedLocation == '/home') {
      return '/login';
    }

    if (loggedIn && (goingToLogin || goingToRegister)) {
      return '/home';
    }

    return null;
  },
);
