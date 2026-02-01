import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';

Future<void> showCreateListDialog({
  required BuildContext context,
  required List<Color> listColors,
  // теперь гибкий тип: может вернуть Map<String,dynamic> или Appwrite User (или любой объект)
  required Future<dynamic> Function() getCurrentUser,
  required Future<Map<String, dynamic>?> Function({
    required String userId,
    required String name,
    required String color,
  })
  createList,

  required Future<void> Function(Map<String, dynamic> createdList) reloadLists,

  required bool mounted,
  required VoidCallback onExpand,
  required bool isExpanded,
}) async {
  final TextEditingController listNameController = TextEditingController();
  int? selectedColorIndex;
  bool isCreateEnabled = false;

  String? _extractUserId(dynamic user) {
    if (user == null) return null;
    try {
      // Map-like
      if (user is Map)
        return user['\$id']?.toString() ?? user['id']?.toString();
      // Object with $id property (Appwrite User)
      final id = (user as dynamic).$id;
      return id?.toString();
    } catch (_) {
      return null;
    }
  }

  if (!isExpanded) {
    onExpand();
    await Future.delayed(const Duration(milliseconds: 200));
    await showCreateListDialog(
      context: context,
      listColors: listColors,
      getCurrentUser: getCurrentUser,
      createList: createList,
      reloadLists: reloadLists,
      mounted: mounted,
      onExpand: onExpand,
      isExpanded: true,
    );
    return;
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          void updateButtonState() {
            final hasName = listNameController.text.trim().isNotEmpty;
            final hasColor = selectedColorIndex != null;
            setModalState(() {
              isCreateEnabled = hasName && hasColor;
            });
          }

          Future<void> createNewList() async {
            try {
              final listName = listNameController.text.trim();
              if (listName.isEmpty) return;

              final color = listColors[selectedColorIndex!];
              final user = await getCurrentUser();
              final userId = _extractUserId(user);
              if (userId == null) {
                print('❌ Не удалось получить id пользователя');
                return;
              }

              final result = await createList(
                userId: userId,
                name: listName,
                color: color.value.toString(),
              );

              if (result != null && mounted) {
                await reloadLists(result);
                Navigator.of(context, rootNavigator: true).pop();
              }
            } catch (e) {
              print('❌ Ошибка при создании списка: $e');
            }
          }

          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 350,
                height: 220,
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
                        "Новый список",
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
                      const Text(
                        "Выберите цвет списка",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 5),
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
                            onPressed: isCreateEnabled ? createNewList : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCreateEnabled
                                  ? listColors[selectedColorIndex ?? 0]
                                  : AppColors.paper,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Создать",
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
