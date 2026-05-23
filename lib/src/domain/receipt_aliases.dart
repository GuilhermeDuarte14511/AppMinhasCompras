String expandReceiptAliases(String raw) {
  var value = stripReceiptDiacritics(raw.toLowerCase())
      .replaceAllMapped(
        RegExp(r'([a-z])(\d)'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAllMapped(
        RegExp(r'(\d)([a-z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  for (final entry in receiptPhraseAliases.entries) {
    value = value.replaceAll(
      RegExp('(?:^| )${RegExp.escape(entry.key)}(?: |\$)'),
      ' ${entry.value} ',
    );
  }

  final expanded = value
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .map((token) => receiptTokenAliases[token] ?? token)
      .join(' ');

  return expanded.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String stripReceiptDiacritics(String input) {
  const replacements = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  final buffer = StringBuffer();
  for (final codeUnit in input.runes) {
    final char = String.fromCharCode(codeUnit);
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}

const Map<String, String> receiptPhraseAliases = <String, String>{
  'achoc po': 'achocolatado po',
  'agua sanit': 'agua sanitaria',
  'cr d': 'creme dental',
  'cr dental': 'creme dental',
  'det liq': 'detergente liquido',
  'det po': 'detergente po',
  'l cond': 'leite condensado',
  'limp perf conc': 'limpador perfumado concentrado',
  'papel hig': 'papel higienico',
  'ref po': 'refresco po',
  'refr po': 'refresco po',
  'shamp cond': 'shampoo condicionador',
  'toalha papel': 'papel toalha',
};

const Map<String, String> receiptTokenAliases = <String, String>{
  'abs': 'absorvente',
  'achoc': 'achocolatado',
  'amac': 'amaciante',
  'arr': 'arroz',
  'arz': 'arroz',
  'bisc': 'biscoito',
  'choc': 'chocolate',
  'conc': 'concentrado',
  'cond': 'condicionador',
  'desinf': 'desinfetante',
  'det': 'detergente',
  'gua': 'guarana',
  'hig': 'higienico',
  'int': 'integral',
  'integ': 'integral',
  'integr': 'integral',
  'iog': 'iogurte',
  'logurte': 'iogurte',
  'limp': 'limpador',
  'liq': 'liquido',
  'mac': 'macarrao',
  'marg': 'margarina',
  'natur': 'natural',
  'perf': 'perfumado',
  'pc': 'pacote',
  'pct': 'pacote',
  'qjo': 'queijo',
  'ref': 'refrigerante',
  'refr': 'refrigerante',
  'refri': 'refrigerante',
  'rf': 'refrigerante',
  'salg': 'salgadinho',
  'sab': 'sabonete',
  'sanit': 'sanitaria',
  'sh': 'shampoo',
  'shamp': 'shampoo',
  'shampcond': 'shampoo condicionador',
  'shbioextratus': 'shampoo bio extratus',
  'shhead': 'shampoo head',
  'should': 'shoulders',
  't': 'total',
  'tp': 'tipo',
  'tpo': 'tipo',
  'lt': 'litro',
  'und': 'unidade',
  'unid': 'unidade',
};
