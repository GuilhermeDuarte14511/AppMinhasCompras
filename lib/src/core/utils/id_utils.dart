import 'dart:math';

final Random _rng = Random();

/// Gera um ID único seguro para Web + Mobile.
/// Evita (1 << 32), que no Web vira 0 e quebra o Random.nextInt().
String uniqueId() {
  final now = DateTime.now().microsecondsSinceEpoch;

  // 2^31 - 1 → sempre válido no dart2js
  const int max = 0x7fffffff;

  final suffix = _rng.nextInt(max);

  // radix 36 deixa menor e mais bonito
  return '${now.toRadixString(36)}_${suffix.toRadixString(36)}';
}
