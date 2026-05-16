import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class BrlCurrencyInputFormatter extends TextInputFormatter {
  BrlCurrencyInputFormatter({NumberFormat? formatter})
    : _formatter =
          formatter ??
          NumberFormat.currency(
            locale: 'pt_BR',
            symbol: 'R\$',
            decimalDigits: 2,
          );

  final NumberFormat _formatter;

  String formatValue(double value) => _formatter.format(value);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final value = double.parse(digits) / 100;
    final formatted = _formatter.format(value);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static double? tryParse(String rawText) {
    final digits = rawText.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    return double.parse(digits) / 100;
  }
}
