import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';

Future<void> showEditListDialog({
  required BuildContext context,
  required Map<String, dynamic> list,
  required List<Color> listColors,
  // гибкий тип — поддерживаем Map или Appwrite User
  required Future<dynamic> Function() getCurrentUser,
  required Future<bool> Function({
    required String listId,
    required String userId,
    required String name,
    required String color,
  })
  updateList,
  required Future<void> Function(Map<String, dynamic> updatedList) reloadLists,

  required bool mounted,
}) async {
  final TextEditingController listNameController = TextEditingController(
    text: list['name'],
  );
  int selectedColorIndex = listColors.indexWhere(
    (color) =>
        color.value ==
        (list['color'] is Color
            ? list['color'].value
            : int.parse(list['color'].toString())),
  );
  if (selectedColorIndex == -1) selectedColorIndex = 0;
  bool isUpdateEnabled = true;

  String? _extractUserId(dynamic user) {
    if (user == null) return null;
    try {
      if (user is Map)
        return user['\$id']?.toString() ?? user['id']?.toString();
      final id = (user as dynamic).$id;
      return id?.toString();
    } catch (_) {
      return null;
    }
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          void updateButtonState() {
            final hasName = listNameController.text.trim().isNotEmpty;
            setModalState(() {
              isUpdateEnabled = hasName && selectedColorIndex != -1;
            });
          }

          Future<void> updateExistingList() async {
            try {
              final updatedName = listNameController.text.trim();
              final updatedColor = listColors[selectedColorIndex];
              final user = await getCurrentUser();
              final userId = _extractUserId(user);

              if (userId == null) {
                print('❌ Не удалось получить id пользователя');
                return;
              }

              final success = await updateList(
                listId: list['id'],
                userId: userId,
                name: updatedName,
                color: updatedColor.value.toString(),
              );

              if (success != null && mounted) {
                await reloadLists({
                  'id': list['id'],
                  'name': updatedName,
                  'color': updatedColor.value.toString(),
                });
                Navigator.pop(context);
              }
            } catch (e) {
              print('❌ Ошибка при обновлении списка: $e');
            }
          }

          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 350,
                height: 205,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.15),
                      offset: const Offset(0, 4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Редактировать список",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: listNameController,
                        onChanged: (_) => updateButtonState(),
                        decoration: const InputDecoration(
                          hintText: "Введите название списка",
                          isDense: true,
                          contentPadding: EdgeInsets.only(bottom: 2),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.black),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.black),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(listColors.length, (index) {
                          final color = listColors[index];
                          final isSelected = selectedColorIndex == index;
                          bool isHover = false;

                          return StatefulBuilder(
                            builder: (context, hoverSetState) {
                              return MouseRegion(
                                onEnter: (_) =>
                                    hoverSetState(() => isHover = true),
                                onExit: (_) =>
                                    hoverSetState(() => isHover = false),
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      selectedColorIndex = index;
                                      updateButtonState();
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    margin: const EdgeInsets.only(right: 8),
                                    width: isHover ? 43 : 40,
                                    height: isHover ? 43 : 40,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      boxShadow: isHover
                                          ? [
                                              BoxShadow(
                                                color: color.withOpacity(0.4),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: isSelected
                                        ? Center(
                                            child: Image.asset(
                                              "assets/icons/check.png",
                                              width: 20,
                                              height: 20,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ),

                      const Spacer(),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Отмена",
                              style: TextStyle(
                                color: AppColors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: isUpdateEnabled
                                ? updateExistingList
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isUpdateEnabled
                                  ? listColors[selectedColorIndex]
                                  : AppColors.paper,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Сохранить",
                              style: TextStyle(
                                color: AppColors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
