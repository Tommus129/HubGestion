class DateHelpers {
  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  static String formatTime(String time) => time;

  static double calculateHours(String start, String end) {
    final s = start.split(':');
    final e = end.split(':');
    final startMin = int.parse(s[0]) * 60 + int.parse(s[1]);
    final endMin = int.parse(e[0]) * 60 + int.parse(e[1]);
    return (endMin - startMin) / 60.0;
  }

  static String formatCurrency(double amount) =>
      '€ ${amount.toStringAsFixed(2)}';
}
