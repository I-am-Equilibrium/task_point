import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/services/task_model.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');
final _dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');

class TaskCard extends StatefulWidget {
  final TaskModel task;
  final Color listColor;
  final bool isCompleted;
  final ValueChanged<TaskModel>? onStatusChanged;
  final VoidCallback? onTap;
  final List<Map<String, dynamic>> userLists;
  final VoidCallback? onTaskActionCompleted;
  final Function(TaskModel)? onTaskDuplicated;
  final Function(TaskModel, String)? onTaskMoved;
  final bool isAssignedToMeView;
  final bool isOwner;
  final bool isAdmin;

  final String? executorName;
  final String? executorAvatarUrl;

  final bool enableContextMenu;
  final bool canToggleImportant;
  final bool isPanelOpen;

  const TaskCard({
    super.key,
    required this.task,
    required this.listColor,
    required this.userLists,
    required this.executorName,
    this.executorAvatarUrl,
    required this.enableContextMenu,
    required this.canToggleImportant,
    this.isAssignedToMeView = false,
    this.isCompleted = false,
    this.onStatusChanged,
    this.onTap,
    this.onTaskActionCompleted,
    this.onTaskDuplicated,
    this.onTaskMoved,
    required this.isOwner,
    required this.isAdmin,
    this.isPanelOpen = false,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  late bool isDone;
  late bool isFavorite;
  bool _isHover = false;
  bool _overlayOpen = false;

  @override
  void initState() {
    super.initState();
    isDone = widget.task.isDone;
    isFavorite = widget.task.isImportant;
  }

  void _showContextMenu(BuildContext context, Offset position) {
    late OverlayEntry entry;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    const menuWidth = 180.0;
    const menuHeight = 110.0;
    const bottomPadding = 30.0;
    const sidePadding = 10.0;

    double left = position.dx;
    double top = position.dy;

    if (left + menuWidth + sidePadding > screenWidth) {
      left = screenWidth - menuWidth - sidePadding;
    }
    if (top + menuHeight + bottomPadding > screenHeight) {
      top = math.max(sidePadding, screenHeight - menuHeight - bottomPadding);
    }

    setState(() => _overlayOpen = true);

    entry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: _ContextMenuOverlay(
            position: Offset(left, top),
            onClose: () {
              _overlayOpen = false;
              entry.remove();
            },
            userLists: widget.userLists,
            task: widget.task,
            isOwner: widget.isOwner,
            onMove: widget.onTaskMoved != null
                ? (listId) async {
                    await widget.onTaskMoved!(widget.task, listId);
                  }
                : null,
            onDuplicate: (listId) async {
              final cleanedCopy = widget.task.copyWith(listId: listId);
              widget.onTaskDuplicated!(cleanedCopy);
            },
            onTaskChanged: () {
              widget.onTaskActionCompleted?.call();
            },
          ),
        );
      },
    );

    Overlay.of(context).insert(entry);
  }

  Future<void> _toggleStatus() async {
    final newValue = !isDone;
    setState(() => isDone = newValue);

    final updatedTask = widget.task.copyWith(isDone: newValue);
    widget.onStatusChanged?.call(updatedTask);

    await AppwriteService().updateTaskStatus(
      taskId: widget.task.id,
      isDone: newValue,
    );
  }

  Future<void> _toggleFavorite() async {
    if (!widget.canToggleImportant) return;

    final newValue = !isFavorite;
    setState(() => isFavorite = newValue);

    final updatedTask = widget.task.copyWith(isImportant: newValue);
    widget.onStatusChanged?.call(updatedTask);

    await AppwriteService().updateTaskStatus(
      taskId: widget.task.id,
      isImportant: newValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canEditImportant =
        widget.canToggleImportant && (widget.isOwner || widget.isAdmin);
    final listData = widget.userLists.firstWhere(
      (l) => (l['id'] ?? l['\$id']) == widget.task.listId,
      orElse: () => {},
    );
    final String taskListName = listData['name'] ?? "";

    return Listener(
      onPointerDown: (event) {
        if (!widget.enableContextMenu) return;

        if (event.kind == PointerDeviceKind.mouse &&
            event.buttons == kSecondaryMouseButton) {
          _showContextMenu(context, event.position);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHover = true),
          onExit: (_) => setState(() => _isHover = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            transform: Matrix4.identity()..scale(_isHover ? 1.01 : 1.0),
            child: Container(
              margin: EdgeInsets.only(
                top: 10,
                right: widget.isPanelOpen ? 340 : 40,
              ),
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, 2),
                    blurRadius: 10,
                    color: AppColors.black.withOpacity(0.08),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TaskCheckbox(
                    isDone: isDone,
                    listColor: widget.listColor,
                    onTap: _toggleStatus,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TaskHeader(
                          task: widget.task,
                          listColor: widget.listColor,
                          isCompleted: widget.isCompleted,
                          isFavorite: isFavorite,
                          taskListName: taskListName,
                          showListName: widget.isAssignedToMeView,
                          canEditImportant: canEditImportant,
                          onFavoriteToggle: canEditImportant
                              ? _toggleFavorite
                              : null,
                        ),
                        const SizedBox(height: 6),
                        _TaskDetails(
                          task: widget.task,
                          executorName: widget.executorName,
                          // Передаем URL аватарки внутрь деталей
                          executorAvatarUrl: widget.executorAvatarUrl,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCheckbox extends StatelessWidget {
  final bool isDone;
  final Color listColor;
  final VoidCallback onTap;

  const _TaskCheckbox({
    required this.isDone,
    required this.listColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        splashColor: listColor.withOpacity(0.2),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Image.asset(
            isDone
                ? "assets/icons/radio_button_confirm.png"
                : "assets/icons/radio_button.png",
            width: isDone ? 15 : 16,
            height: isDone ? 15 : 16,
          ),
        ),
      ),
    );
  }
}

class _TaskHeader extends StatelessWidget {
  final TaskModel task;
  final Color listColor;
  final bool isCompleted;
  final bool isFavorite;
  final bool canEditImportant;
  final VoidCallback? onFavoriteToggle;
  final String taskListName;
  final bool showListName;

  const _TaskHeader({
    required this.task,
    required this.listColor,
    required this.isCompleted,
    required this.isFavorite,
    required this.canEditImportant,
    required this.taskListName,
    required this.showListName,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle numberStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: listColor,
      height: 1.0,
      leadingDistribution: TextLeadingDistribution.even,
      decoration: isCompleted ? TextDecoration.lineThrough : null,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showListName && taskListName.isNotEmpty) ...[
          Text(taskListName, style: numberStyle.copyWith(fontSize: 12)),
          const SizedBox(width: 8),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: listColor.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(task.invoice ?? "", style: numberStyle),
        if ((task.utd ?? "").isNotEmpty) ...[
          const SizedBox(width: 6),
          Text("-", style: numberStyle),
          const SizedBox(width: 6),
          Text(task.utd!, style: numberStyle),
        ],
        const SizedBox(width: 12),
        Text(
          "Товары:",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.grey,
            height: 1.0,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            task.products ?? "",
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.black,
              height: 1.0,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        const SizedBox(width: 5),
        _FavoriteStar(
          isFavorite: isFavorite,
          color: listColor,
          isEnabled: canEditImportant,
          onPressed: onFavoriteToggle,
        ),
      ],
    );
  }
}

class _TaskDetails extends StatelessWidget {
  final TaskModel task;
  final String? executorName;
  final String? executorAvatarUrl;

  const _TaskDetails({
    required this.task,
    this.executorName,
    this.executorAvatarUrl,
  });

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      return _dateFormat.format(DateTime.parse(dateStr));
    } catch (_) {
      return '';
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      return _dateTimeFormat.format(DateTime.parse(dateStr));
    } catch (_) {
      return '';
    }
  }

  Color _getAvatarColor(String name) {
    if (name.isEmpty) return AppColors.grey;

    final List<Color> allowedColors = [
      AppColors.green,
      AppColors.skyBlue,
      AppColors.lavendar,
      AppColors.cheese,
      AppColors.red,
    ];

    final int index = name.hashCode.abs() % allowedColors.length;
    return allowedColors[index];
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "?";

    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Widget _buildAvatar(String? name, String? avatarUrl) {
    const double size = 28.0;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
          image: DecorationImage(
            image: NetworkImage(avatarUrl),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final String displayName = name ?? "";
    final Color bgColor = _getAvatarColor(displayName);
    final String initials = _getInitials(displayName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if ((task.company ?? "").isNotEmpty) ...[
          Text(
            task.company ?? "",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
        ],
        _TaskIconText(icon: "date.png", text: _formatDate(task.date)),
        _TaskIconText(icon: "address.png", text: task.address),

        if (executorName != null && executorName!.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: AppColors.black),
          const SizedBox(width: 10),
          _buildAvatar(executorName, executorAvatarUrl),
          const SizedBox(width: 8),
          Text(
            executorName!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.black,
            ),
          ),
        ],

        _TaskIconText(icon: "remind.png", text: _formatDateTime(task.reminder)),
        if (task.comment != null && task.comment!.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: AppColors.black),
          const SizedBox(width: 10),
          Image.asset(
            "assets/icons/comment.png",
            width: 16,
            height: 16,
            color: AppColors.black,
          ),
        ],
      ],
    );
  }
}

class _TaskIconText extends StatelessWidget {
  final String icon;
  final String? text;

  const _TaskIconText({required this.icon, this.text});

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const SizedBox(width: 8),
        Container(width: 1, height: 20, color: AppColors.black),
        const SizedBox(width: 8),
        Image.asset(
          "assets/icons/$icon",
          width: 16,
          height: 16,
          color: AppColors.black,
        ),
        const SizedBox(width: 4),
        Text(
          text!,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }
}

class _FavoriteStar extends StatefulWidget {
  final bool isFavorite;
  final Color color;
  final bool isEnabled;
  final VoidCallback? onPressed;

  const _FavoriteStar({
    required this.isFavorite,
    required this.color,
    required this.isEnabled,
    this.onPressed,
  });

  @override
  State<_FavoriteStar> createState() => _FavoriteStarState();
}

class _FavoriteStarState extends State<_FavoriteStar> {
  bool isHover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isEnabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: widget.isEnabled ? (_) => setState(() => isHover = true) : null,
      onExit: widget.isEnabled ? (_) => setState(() => isHover = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.isEnabled ? widget.onPressed : null,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: widget.isEnabled && isHover ? 1.12 : 1.0,
          child: Opacity(
            opacity: widget.isEnabled ? 1.0 : 0.35,
            child: Image.asset(
              widget.isFavorite
                  ? "assets/icons/star_filled.png"
                  : "assets/icons/star_outline.png",
              width: 20,
              height: 20,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextMenuOverlay extends StatefulWidget {
  final Offset position;
  final VoidCallback onClose;
  final List<Map<String, dynamic>> userLists;
  final TaskModel task;
  final Future<void> Function(String listId)? onMove;
  final Future<void> Function(String listId) onDuplicate;
  final VoidCallback onTaskChanged;
  final bool isOwner;

  const _ContextMenuOverlay({
    super.key,
    required this.position,
    required this.onClose,
    required this.userLists,
    required this.task,
    this.onMove,
    required this.onDuplicate,
    required this.onTaskChanged,
    required this.isOwner,
  });

  @override
  State<_ContextMenuOverlay> createState() => _ContextMenuOverlayState();
}

class _ContextMenuOverlayState extends State<_ContextMenuOverlay> {
  String? _hoveredMenu;
  Offset _submenuOffset = Offset.zero;
  final GlobalKey _mainMenuKey = GlobalKey();
  bool _submenuOpenToLeft = false;
  int _hoveredSubmenuIndex = -1;

  final double _submenuWidth = 200;
  final double _mainMenuWidth = 180;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              onSecondaryTap: widget.onClose,
              child: Container(color: Colors.transparent),
            ),
          ),

          Positioned(
            left: widget.position.dx,
            top: widget.position.dy,
            child: _buildMainMenu(),
          ),

          if (_hoveredMenu != null)
            Positioned(
              left: _submenuOpenToLeft
                  ? widget.position.dx - _submenuWidth - 5
                  : widget.position.dx + _mainMenuWidth + 5,
              top: widget.position.dy + _submenuOffset.dy,
              child: _buildSubmenu(_hoveredMenu!),
            ),
        ],
      ),
    );
  }

  Widget _buildMainMenu() {
    return Container(
      key: _mainMenuKey,
      width: _mainMenuWidth,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onMove != null) ...[
            _menuItem("Перенести", "assets/icons/back.png", "move"),
          ],

          _menuItem("Дублировать", "assets/icons/copy.png", "duplicate"),
        ],
      ),
    );
  }

  Widget _menuItem(String title, String icon, String type) {
    return MouseRegion(
      onEnter: (_) {},
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final menuBox =
              _mainMenuKey.currentContext?.findRenderObject() as RenderBox?;
          if (menuBox == null) return;

          final globalMenuPos = menuBox.localToGlobal(Offset.zero);
          final localClickPos = details.localPosition;

          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;

          final spaceOnRight =
              screenWidth - (globalMenuPos.dx + _mainMenuWidth);
          final shouldOpenLeft = spaceOnRight < _submenuWidth + 20;

          final estimatedHeight = 16.0 + (widget.userLists.length * 36.0);
          final globalCursorY = globalMenuPos.dy + localClickPos.dy;
          final spaceBelow = screenHeight - globalCursorY - 30.0;

          double top = localClickPos.dy - 10;
          if (spaceBelow < estimatedHeight) {
            top = localClickPos.dy - estimatedHeight + 20;
          }

          setState(() {
            _hoveredMenu = type;
            _submenuOffset = Offset(0, top);
            _submenuOpenToLeft = shouldOpenLeft;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: _hoveredMenu == type
                ? Colors.grey.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Image.asset(icon, width: 20, height: 20, color: AppColors.black),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.black,
                  ),
                ),
              ),
              const Icon(Icons.arrow_right, size: 16, color: AppColors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmenu(String type) {
    return Container(
      width: _submenuWidth,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.userLists.length, (index) {
          final list = widget.userLists[index];
          final listId = list["id"] ?? list["\$id"];
          final listName = list["name"] ?? "NO_NAME";
          final isHover = _hoveredSubmenuIndex == index;

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoveredSubmenuIndex = index),
            onExit: (_) => setState(() => _hoveredSubmenuIndex = -1),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () async {
                print("Action: $type -> List: $listName ($listId)");

                if (listId == null) return;

                widget.onClose();

                if (type == "move") {
                  if (widget.onMove != null) {
                    await widget.onMove!(listId);
                  }
                } else {
                  await widget.onDuplicate(listId);
                }
                widget.onTaskChanged();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: isHover
                      ? Colors.grey.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  listName,
                  style: TextStyle(
                    fontSize: 14,
                    color: isHover ? AppColors.black : AppColors.black,
                    fontWeight: isHover ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
