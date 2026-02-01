import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/services/task_model.dart';

class MobileTaskCard extends StatelessWidget {
  final TaskModel task;
  final Color listColor;
  final String? executorName;
  final VoidCallback? onTap;
  final VoidCallback? onStatusToggle;
  final VoidCallback? onFavoriteToggle;
  final bool isHighlighted;

  const MobileTaskCard({
    super.key,
    required this.task,
    required this.listColor,
    this.executorName,
    this.onTap,
    this.onStatusToggle,
    this.onFavoriteToggle,
    this.isHighlighted = false,
  });

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Дата не назначена";
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (_) {
      return "Дата не назначена";
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlighted ? listColor : Colors.transparent,
            width: isHighlighted ? 3.0 : 2.0,
          ),
          boxShadow: [
            BoxShadow(
              offset: isHighlighted ? const Offset(0, 0) : const Offset(0, 4),
              blurRadius: isHighlighted ? 35 : 20,
              spreadRadius: isHighlighted ? 8 : 0,
              color: isHighlighted
                  ? listColor.withOpacity(0.8)
                  : AppColors.black.withOpacity(0.15),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.invoice ?? "Без номера",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: listColor,
                    ),
                  ),
                ),
                if (task.reminder != null && task.reminder!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Image.asset(
                      'assets/icons/notification_fill.png',
                      width: 30,
                      height: 30,
                      color: listColor,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: GestureDetector(
                    onTap: onFavoriteToggle,
                    child: Image.asset(
                      task.isImportant
                          ? 'assets/icons/star_filled.png'
                          : 'assets/icons/star_outline.png',
                      width: 30,
                      height: 30,
                      color: task.isImportant ? listColor : AppColors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 0),
                  child: GestureDetector(
                    onTap: onStatusToggle,
                    child: Image.asset(
                      task.isDone
                          ? 'assets/icons/radio_button_confirm.png'
                          : 'assets/icons/radio_button_unconfirm.png',
                      width: task.isDone ? 36 : 48,
                      height: task.isDone ? 36 : 48,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              _formatDate(task.date),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                height: 16 / 14,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Товары: ",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.products ?? "—",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(height: 1, thickness: 1, color: AppColors.paper),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  "Адрес: ",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: listColor,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    (task.address != null && task.address!.isNotEmpty)
                        ? task.address!
                        : "Адрес не назначен",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: AppColors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  "Передано: ",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: listColor,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    (executorName != null && executorName!.isNotEmpty)
                        ? executorName!
                        : "Исполнитель не назначен",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: AppColors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
