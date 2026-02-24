import 'package:intl/intl.dart';

class DateHelpers {
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // ✅ Versione corta per tabelle (es. 24/02/26)
  static String formatDateShort(DateTime date) {
    return DateFormat('dd/MM/yy').format(date);
  }

  static String formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'it_IT', symbol: '€', decimalDigits: 2)
        .format(amount);
  }

  static String formatMonth(DateTime date) {
    return DateFormat('MMMM yyyy', 'it_IT').format(date);
  }
}
