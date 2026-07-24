import 'dart:io';

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Uso: dart run tool/check_coverage.dart <lcov.info> <mínimo-percentual>',
    );
    exitCode = 64;
    return;
  }

  final coverageFile = File(arguments.first);
  final minimum = double.tryParse(arguments.last);
  if (!coverageFile.existsSync() || minimum == null) {
    stderr.writeln('Arquivo de cobertura ou percentual mínimo inválido.');
    exitCode = 64;
    return;
  }

  var foundLines = 0;
  var hitLines = 0;
  for (final line in coverageFile.readAsLinesSync()) {
    if (line.startsWith('LF:')) {
      foundLines += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hitLines += int.parse(line.substring(3));
    }
  }

  final percentage = foundLines == 0 ? 0 : (hitLines * 100 / foundLines);
  stdout.writeln(
    'Cobertura: ${percentage.toStringAsFixed(1)}% '
    '($hitLines/$foundLines linhas). Mínimo: ${minimum.toStringAsFixed(1)}%.',
  );
  if (percentage < minimum) {
    exitCode = 1;
  }
}
