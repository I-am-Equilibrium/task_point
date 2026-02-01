import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../utils/custom_calendar_localization.dart';

class RussianCalendar extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateChanged;

  final Color listColor;

  const RussianCalendar({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateChanged,
    required this.listColor,
  });

  @override
  State<RussianCalendar> createState() => _RussianCalendarState();
}

class _RussianCalendarState extends State<RussianCalendar>
    with SingleTickerProviderStateMixin {
  late DateTime _visibleMonth;
  DateTime? _selected;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  double _dragDelta = 0;

  @override
  void initState() {
    super.initState();

    _visibleMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _selected = widget.initialDate;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );

    _scaleAnim = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<DateTime> _generateDaysForMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final firstWeekday = (firstDay.weekday + 6) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final List<DateTime> days = [];

    for (int i = 0; i < firstWeekday; i++) {
      days.add(DateTime(0));
    }

    for (int d = 1; d <= daysInMonth; d++) {
      days.add(DateTime(month.year, month.month, d));
    }

    return days;
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
        1,
      );
      _animController.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = _generateDaysForMonth(_visibleMonth);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Listener(
      onPointerSignal: (PointerSignalEvent event) {
        if (event is PointerScrollEvent) {
          final dy = event.scrollDelta.dy;
          if (dy > 0) {
            _changeMonth(1);
          } else if (dy < 0) {
            _changeMonth(-1);
          }
        }
      },
      onPointerMove: (event) {
        _dragDelta += event.delta.dy;
      },
      onPointerUp: (_) {
        if (_dragDelta.abs() > 40) {
          if (_dragDelta < 0) {
            _changeMonth(1);
          } else {
            _changeMonth(-1);
          }
        }
        _dragDelta = 0;
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              const SizedBox(height: 5),

              Text(
                CustomCalendarLocalization.formatCalendarHeader(_visibleMonth),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: CustomCalendarLocalization.weekDaysShort
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 5),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 2,
                ),
                itemBuilder: (context, index) {
                  final day = days[index];

                  if (day.year == 0) {
                    return const SizedBox.shrink();
                  }

                  final d = DateTime(day.year, day.month, day.day);
                  final isToday = d == today;
                  final isSelected =
                      _selected != null &&
                      d.year == _selected!.year &&
                      d.month == _selected!.month &&
                      d.day == _selected!.day;

                  final isPast = d.isBefore(today);

                  Color bg = Colors.transparent;
                  Color textColor = Colors.black;
                  bool canTap = true;

                  if (isPast) {
                    textColor = Colors.grey;
                    canTap = false;
                  }

                  if (isToday && !isSelected) {
                    bg = widget.listColor;
                    textColor = Colors.white;
                  }

                  if (isSelected) {
                    bg = Colors.black;
                    textColor = Colors.white;
                  }

                  return GestureDetector(
                    onTap: canTap
                        ? () {
                            setState(() => _selected = d);
                            widget.onDateChanged(d);
                          }
                        : null,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: isSelected ? 30 : 26,
                        height: isSelected ? 30 : 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${d.day}",
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
