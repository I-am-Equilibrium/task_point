import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../utils/custom_calendar_localization.dart';

class MobileRussianCalendar extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateChanged;
  final Color accentColor;

  const MobileRussianCalendar({
    super.key,
    required this.initialDate,
    required this.onDateChanged,
    required this.accentColor,
  });

  @override
  State<MobileRussianCalendar> createState() => _MobileRussianCalendarState();
}

class _MobileRussianCalendarState extends State<MobileRussianCalendar> {
  late DateTime _visibleMonth;
  DateTime? _selected;
  double _dragDelta = 0;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _selected = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
  }

  List<DateTime> _generateDaysForMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final firstWeekday = (firstDay.weekday + 6) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final List<DateTime> days = [];
    for (int i = 0; i < firstWeekday; i++) days.add(DateTime(0));
    for (int d = 1; d <= daysInMonth; d++)
      days.add(DateTime(month.year, month.month, d));
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final days = _generateDaysForMonth(_visibleMonth);
    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);

    return Container(
      color: AppColors.white,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) =>
            _dragDelta += details.primaryDelta!,
        onHorizontalDragEnd: (details) {
          if (_dragDelta.abs() > 30) {
            setState(
              () => _visibleMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month + (_dragDelta > 0 ? -1 : 1),
                1,
              ),
            );
          }
          _dragDelta = 0;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month - 1,
                      1,
                    ),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  CustomCalendarLocalization.formatCalendarHeader(
                    _visibleMonth,
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month + 1,
                      1,
                    ),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: CustomCalendarLocalization.weekDaysShort
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            color: AppColors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final day = days[index];
                if (day.year == 0) return const SizedBox.shrink();

                final d = DateTime(day.year, day.month, day.day);
                final isToday = d == todayClean;
                final isSelected =
                    _selected != null &&
                    d.year == _selected!.year &&
                    d.month == _selected!.month &&
                    d.day == _selected!.day;
                final isPast = d.isBefore(todayClean);

                Color bgColor = Colors.transparent;
                Color textColor = AppColors.black;

                if (isSelected) {
                  bgColor = widget.accentColor;
                  textColor = AppColors.white;
                } else if (isToday) {
                  bgColor = AppColors.black;
                  textColor = AppColors.white;
                } else if (isPast) {
                  textColor = AppColors.grey;
                }

                return GestureDetector(
                  onTap: isPast
                      ? null
                      : () {
                          setState(() => _selected = d);
                          widget.onDateChanged(d);
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "${d.day}",
                      style: TextStyle(
                        color: textColor,
                        fontWeight: isSelected || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
