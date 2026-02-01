import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:flutter/gestures.dart';
import 'package:task_point/utils/mouse_scroll_behavior.dart';

class AlarmItem extends StatefulWidget {
  final ValueChanged<TimeOfDay> onTimeSelected;

  const AlarmItem({super.key, required this.onTimeSelected});

  @override
  State<AlarmItem> createState() => _AlarmItemState();
}

class _AlarmItemState extends State<AlarmItem> {
  int selectedHour = TimeOfDay.now().hour;
  int selectedMinute = TimeOfDay.now().minute;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  static const double itemHeight = 40;

  @override
  void initState() {
    super.initState();
    _hourController = FixedExtentScrollController(initialItem: selectedHour);
    _minuteController = FixedExtentScrollController(
      initialItem: selectedMinute,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTimeSelected(
        TimeOfDay(hour: selectedHour, minute: selectedMinute),
      );
    });
  }

  void _updateTime() {
    widget.onTimeSelected(
      TimeOfDay(hour: selectedHour, minute: selectedMinute),
    );
  }

  Widget _buildWheel({
    required int maxValue,
    required int selectedValue,
    required ValueChanged<int> onSelected,
    required FixedExtentScrollController controller,
  }) {
    return SizedBox(
      width: 60,
      height: itemHeight * 3,
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            final scroll = pointerSignal.scrollDelta.dy;

            if (scroll > 0) {
              controller.animateToItem(
                controller.selectedItem + 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
              );
            } else if (scroll < 0) {
              controller.animateToItem(
                controller.selectedItem - 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
              );
            }
          }
        },
        child: ScrollConfiguration(
          behavior: NoMouseScrollBehavior(),
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: itemHeight,
            physics: const NeverScrollableScrollPhysics(),

            overAndUnderCenterOpacity: 0.5,
            perspective: 0.001,
            onSelectedItemChanged: (index) {
              onSelected(index);
              _updateTime();
            },
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < 0 || index >= maxValue) return null;
                final isSelected = index == selectedValue;
                return Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.black.withOpacity(0.9)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
              childCount: maxValue,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "Выберите время",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildWheel(
              maxValue: 24,
              selectedValue: selectedHour,
              onSelected: (value) => setState(() => selectedHour = value),
              controller: _hourController,
            ),
            const SizedBox(width: 10),
            const Text(
              ":",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            const SizedBox(width: 10),
            _buildWheel(
              maxValue: 60,
              selectedValue: selectedMinute,
              onSelected: (value) => setState(() => selectedMinute = value),
              controller: _minuteController,
            ),
          ],
        ),
      ],
    );
  }
}
