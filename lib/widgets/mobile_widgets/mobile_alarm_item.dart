import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class MobileAlarmItem extends StatefulWidget {
  final ValueChanged<TimeOfDay> onTimeSelected;
  final Color accentColor;
  final TimeOfDay? initialTime;

  const MobileAlarmItem({
    super.key,
    required this.onTimeSelected,
    required this.accentColor,
    this.initialTime,
  });

  @override
  State<MobileAlarmItem> createState() => _MobileAlarmItemState();
}

class _MobileAlarmItemState extends State<MobileAlarmItem> {
  late int selectedHour;
  late int selectedMinute;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final time = widget.initialTime ?? TimeOfDay.now();

    selectedHour = time.hour;
    selectedMinute = time.minute;

    _hourController = FixedExtentScrollController(initialItem: selectedHour);
    _minuteController = FixedExtentScrollController(
      initialItem: selectedMinute,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: Column(
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
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 40,
                width: 160,
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildWheel(24, _hourController, (v) {
                    selectedHour = v;
                    widget.onTimeSelected(
                      TimeOfDay(hour: selectedHour, minute: selectedMinute),
                    );
                  }),
                  const Text(
                    ":",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  _buildWheel(60, _minuteController, (v) {
                    selectedMinute = v;
                    widget.onTimeSelected(
                      TimeOfDay(hour: selectedHour, minute: selectedMinute),
                    );
                  }),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWheel(
    int max,
    FixedExtentScrollController controller,
    ValueChanged<int> onSelect,
  ) {
    return SizedBox(
      width: 70,
      height: 120,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 40,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onSelect,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) => (index >= 0 && index < max)
              ? Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                )
              : null,
          childCount: max,
        ),
      ),
    );
  }
}
