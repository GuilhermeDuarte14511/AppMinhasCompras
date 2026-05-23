import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptOcrTextNormalizer {
  const ReceiptOcrTextNormalizer();

  String normalize(RecognizedText recognizedText) {
    final rows = _rowsFromGeometry(recognizedText);
    if (rows.isEmpty) {
      return normalizeRawText(recognizedText.text);
    }
    return normalizeRawText(
      rows.map((row) => row.map((line) => line.text).join(' ')).join('\n'),
    );
  }

  String normalizeRawText(String raw) {
    return raw
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
  }

  List<List<TextLine>> _rowsFromGeometry(RecognizedText recognizedText) {
    final lines = [
      for (final block in recognizedText.blocks)
        for (final line in block.lines)
          if (line.text.trim().isNotEmpty) line,
    ]..sort(_compareLinesByPosition);

    final rows = <List<TextLine>>[];
    for (final line in lines) {
      if (rows.isEmpty) {
        rows.add([line]);
        continue;
      }

      final currentRow = rows.last;
      final reference = currentRow.first;
      final threshold = _rowThreshold(reference, line);
      if ((line.boundingBox.top - reference.boundingBox.top).abs() <=
          threshold) {
        currentRow.add(line);
        currentRow.sort((left, right) {
          return left.boundingBox.left.compareTo(right.boundingBox.left);
        });
      } else {
        rows.add([line]);
      }
    }
    return rows;
  }

  int _compareLinesByPosition(TextLine left, TextLine right) {
    final vertical = left.boundingBox.top.compareTo(right.boundingBox.top);
    if (vertical != 0) {
      return vertical;
    }
    return left.boundingBox.left.compareTo(right.boundingBox.left);
  }

  double _rowThreshold(TextLine first, TextLine second) {
    final firstHeight = first.boundingBox.height.abs();
    final secondHeight = second.boundingBox.height.abs();
    final height = firstHeight > secondHeight ? firstHeight : secondHeight;
    return height <= 0 ? 8 : height * 0.7;
  }
}
