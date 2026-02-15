import 'dart:math';

String uniqueId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final suffix = Random().nextInt(1 << 32);
  return '${now}_$suffix';
}
