import 'package:intl/intl.dart';

final NumberFormat _currencyFormat = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 2,
);

String formatCurrency(double value) => _currencyFormat.format(value);

String formatShortDate(DateTime value) {
  final formatter = DateFormat('dd/MM/yyyy');
  return formatter.format(value);
}

String formatDateTime(DateTime value) {
  final formatter = DateFormat('dd/MM/yyyy HH:mm');
  return formatter.format(value);
}
