import 'package:flutter/material.dart';
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
  final bool showListName;
  final String taskListName;

  const MobileTaskCard({
    super.key,
    required this.task,
    required this.listColor,
    this.executorName,
    this.onTap,
    this.onStatusToggle,
    this.onFavoriteToggle,
    this.isHighlighted = false,
    this.showListName = false,
    this.taskListName = "",
  });

  @override
  Widget build(BuildContext context) {
    final topTextStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: listColor,
      height: 1.0,
      leadingDistribution: TextLeadingDistribution.even,
    );

    final secondaryHeaderStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: listColor,
      height: 20 / 14,
    );

    final bool hasUtd = task.utd != null && task.utd!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 5, top: 0),
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlighted ? listColor : Colors.transparent,
            width: isHighlighted ? 3.0 : 0.0,
          ),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 4),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showListName && taskListName.isNotEmpty) ...[
                  Text(taskListName, style: topTextStyle),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: listColor.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                Text(task.invoice ?? "Без номера", style: topTextStyle),
                if (hasUtd) ...[
                  const SizedBox(width: 6),
                  Text("-", style: topTextStyle),
                  const SizedBox(width: 6),
                  Text(task.utd!, style: topTextStyle),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: onFavoriteToggle,
                  child: Image.asset(
                    task.isImportant
                        ? 'assets/icons/star_filled.png'
                        : 'assets/icons/star_outline.png',
                    width: 24,
                    height: 24,
                    color: task.isImportant ? listColor : AppColors.black,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onStatusToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    child: Image.asset(
                      task.isDone
                          ? 'assets/icons/radio_button_confirm.png'
                          : 'assets/icons/radio_button_unconfirm.png',
                      color: AppColors.black,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(task.company ?? "Компания", style: secondaryHeaderStyle),
                const SizedBox(width: 4),
                Text("•", style: secondaryHeaderStyle),
                const SizedBox(width: 4),
                Text("Товары: ", style: secondaryHeaderStyle),
                const SizedBox(width: 2),
                Expanded(
                  child: Baseline(
                    baselineType: TextBaseline.alphabetic,
                    baseline: 14,
                    child: Text(
                      task.products ?? "—",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.black,
                        height: 20 / 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            const Divider(height: 1, thickness: 1, color: AppColors.paper),
            const SizedBox(height: 8),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Адрес: ",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: listColor,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Baseline(
                    baselineType: TextBaseline.alphabetic,
                    baseline: 14,
                    child: Text(
                      (task.address != null && task.address!.isNotEmpty)
                          ? task.address!
                          : "Адрес не назначен",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
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
