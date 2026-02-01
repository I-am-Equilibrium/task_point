import 'package:flutter/material.dart';
import 'package:task_point/widgets/mobile_widgets/mobile_tasks_item.dart';
import 'package:task_point/widgets/mobile_widgets/mobile_top_bar_item.dart';
import 'package:task_point/widgets/mobile_widgets/mobile_elements_item.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/constants/colors.dart';

class MobileLayout extends StatelessWidget {
  final double fontSize;
  final AppwriteService _appwrite = AppwriteService();

  MobileLayout({super.key, required this.fontSize});

  Future<void> _handleSearchNavigation(
    BuildContext context,
    String listId,
    String taskId,
  ) async {
    try {
      final listDoc = await _appwrite.databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.listsCollectionId,
        documentId: listId,
      );

      final String name = listDoc.data['name'] ?? 'Список';
      final Color color = _parseColor(listDoc.data['color']);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MobileTasksScreen(
              listId: listId,
              listName: name,
              listColor: color,
              scrollToTaskId: taskId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Ошибка навигации поиска: $e');
    }
  }

  Color _parseColor(dynamic raw) {
    try {
      if (raw == null) return AppColors.skyBlue;
      if (raw is int) return Color(raw);
      if (raw is String) {
        if (raw.startsWith('0x')) return Color(int.parse(raw));
        if (RegExp(r'^\d+$').hasMatch(raw)) return Color(int.parse(raw));
      }
    } catch (_) {}
    return AppColors.skyBlue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MobileTopBarItem(
        openList: (listId) {
          _handleSearchNavigation(context, listId, "");
        },
        scrollToTask: (taskId) {},
        onSearchResultTap: (listId, taskId) {
          _handleSearchNavigation(context, listId, taskId);
        },
      ),
      body: MobileElementsItem(
        onListSelected: (listId, listName, color) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MobileTasksScreen(
                listId: listId,
                listName: listName,
                listColor: color,
              ),
            ),
          );
        },
      ),
    );
  }
}
