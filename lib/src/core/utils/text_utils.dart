String? sanitizeBarcode(String? rawValue) {
  if (rawValue == null) {
    return null;
  }
  final digits = rawValue.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) {
    return null;
  }
  if (digits.length < 8) {
    return null;
  }
  return digits;
}

String normalizeQuery(String value) => value.trim().toLowerCase();
