import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';

typedef EditListCallback = void Function();
typedef DuplicateListCallback = void Function();
typedef DeleteListCallback = void Function();

class ListContextMenu {
  OverlayEntry? _entry;

  void show({
    required BuildContext context,
    required Offset globalPosition,
    required Widget Function({
      required String title,
      required String iconPath,
      required Color color,
      required VoidCallback onTap,
    })
    buildRow,
    required EditListCallback onEdit,
    required DuplicateListCallback onDuplicate,
    required DeleteListCallback onDelete,
  }) {
    final left = 130.0;
    final top = globalPosition.dy + 15.0;
    double opacity = 0.0;

    _entry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: hide, // ← закрытие при клике вне меню
            child: Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  child: Material(
                    color: Colors.transparent,
                    child: AnimatedOpacity(
                      opacity: opacity,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Container(
                        width: 150,
                        height: 115,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withOpacity(0.15),
                              offset: const Offset(0, 4),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildRow(
                              title: 'Изменить',
                              iconPath: 'assets/icons/edit.png',
                              color: AppColors.black,
                              onTap: () {
                                hide();
                                onEdit();
                              },
                            ),
                            const SizedBox(height: 10),
                            buildRow(
                              title: 'Дублировать',
                              iconPath: 'assets/icons/copy.png',
                              color: AppColors.black,
                              onTap: () {
                                hide();
                                onDuplicate();
                              },
                            ),
                            const SizedBox(height: 10),
                            buildRow(
                              title: 'Удалить',
                              iconPath: 'assets/icons/delete.png',
                              color: AppColors.red,
                              onTap: () {
                                hide();
                                onDelete();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Navigator.of(context).overlay!.insert(_entry!);

    Future.delayed(const Duration(milliseconds: 10), () {
      opacity = 1;
      _entry?.markNeedsBuild();
    });
  }

  void hide() {
    _entry?.remove();
    _entry = null;
  }
}
