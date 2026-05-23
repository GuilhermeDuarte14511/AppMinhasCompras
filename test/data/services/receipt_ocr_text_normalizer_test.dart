import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:lista_compras_material/src/data/services/receipt_ocr_text_normalizer.dart';

void main() {
  const normalizer = ReceiptOcrTextNormalizer();

  test('sorts ML Kit text lines by visual position', () {
    final recognizedText = RecognizedText(
      text: 'Vl Total\nProduto A\nProduto B',
      blocks: [
        _block(text: 'Produto B', left: 20, top: 80),
        _block(text: 'Vl Total', left: 220, top: 10),
        _block(text: 'Produto A', left: 20, top: 10),
      ],
    );

    expect(
      normalizer.normalize(recognizedText),
      'Produto A Vl Total\nProduto B',
    );
  });

  test('falls back to recognized text when geometry has no lines', () {
    final recognizedText = RecognizedText(
      text: ' CNPJ  93\n\nProduto ',
      blocks: const [],
    );

    expect(normalizer.normalize(recognizedText), 'CNPJ 93\nProduto');
  });
}

TextBlock _block({
  required String text,
  required double left,
  required double top,
}) {
  final rect = Rect.fromLTWH(left, top, 90, 14);
  return TextBlock(
    text: text,
    lines: [
      TextLine(
        text: text,
        elements: const [],
        boundingBox: rect,
        recognizedLanguages: const [],
        cornerPoints: [
          Point(left.round(), top.round()),
          Point((left + 90).round(), top.round()),
          Point((left + 90).round(), (top + 14).round()),
          Point(left.round(), (top + 14).round()),
        ],
        confidence: 0.9,
        angle: 0,
      ),
    ],
    boundingBox: rect,
    recognizedLanguages: const [],
    cornerPoints: [
      Point(left.round(), top.round()),
      Point((left + 90).round(), top.round()),
      Point((left + 90).round(), (top + 14).round()),
      Point(left.round(), (top + 14).round()),
    ],
  );
}
