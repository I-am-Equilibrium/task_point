class CustomCalendarLocalization {
  static const List<String> months = [
    "январь",
    "февраль",
    "март",
    "апрель",
    "май",
    "июнь",
    "июль",
    "август",
    "сентябрь",
    "октябрь",
    "ноябрь",
    "декабрь",
  ];

  static const List<String> weekDaysShort = [
    "Пн",
    "Вт",
    "Ср",
    "Чт",
    "Пт",
    "Сб",
    "Вс",
  ];

  static String getMonthName(int month) {
    return months[month - 1];
  }

  static String formatCalendarHeader(DateTime date) {
    return "${getMonthName(date.month)} ${date.year}";
  }
}
