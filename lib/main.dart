import 'package:flutter/material.dart';
import 'package:task_point/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await authState.checkSession();

  runApp(const TaskPointApp());
}

class TaskPointApp extends StatelessWidget {
  const TaskPointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Task Point',
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
    );
  }
}
