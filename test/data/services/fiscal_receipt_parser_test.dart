import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/data/services/fiscal_receipt_parser.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';

void main() {
  const parser = FiscalReceiptParser();

  test(
    'parses WMS receipt rows with alpha codes, weights, and unit columns',
    () {
      const rawText = '''
Codigo Descricao Qtde UN Vl Unit Vl Total
AR085684 LING.T.CALAB.SADIA 0,426kg x 29,90 R\$/kg 12,74
AR04692 CEBOLA ATACADAO 0,335kg x 6,49 R\$/kg 2,17
AR060861 PACOCA S.HELENA 1X50X15G 1 UND9 25,98 25,98
AR014395 BEB.LACTEA TODDYNHO 1X200ML 5 UND9 2,99 14,95
AR035266 MARG.QUALY C/S 1X500G 1 UND9 9,45 9,45
''';

      final items = parser.parse(rawText);

      expect(items.map((item) => item.name), [
        'LING T CALAB SADIA',
        'CEBOLA ATACADAO',
        'PACOCA S HELENA',
        'BEB LACTEA TODDYNHO',
        'MARG QUALY C S',
      ]);
      expect(items.map((item) => item.quantity), [1, 1, 1, 5, 1]);
      expect(items.map((item) => item.unitPrice), [
        closeTo(12.74, 0.001),
        closeTo(2.17, 0.001),
        closeTo(25.98, 0.001),
        closeTo(2.99, 0.001),
        closeTo(9.45, 0.001),
      ]);
      expect(items[1].category, ShoppingCategory.produce);
      expect(items[2].category, ShoppingCategory.sweets);
      expect(items[3].category, ShoppingCategory.dairy);
      expect(items[4].category, ShoppingCategory.dairy);
    },
  );

  test(
    'parses Fazenda NFC-e WMS product blocks without reading CNPJ as item',
    () {
      const rawText = '''
NFC-e
DOCUMENTO AUXILIAR DA NOTA FISCAL DE CONSUMIDOR ELETRÔNICA
WMS SUPERMERCADOS DO BRASIL LTDA
CNPJ: 93.209.765/0654-05
LING.T.CALAB.SADIA (Código: AR085684 )
Qtde.:0,426   UN: KG9   Vl. Unit.:   29,9 	Vl. Total
12,74
CEBOLA ATACADAO (Código: AR014692 )
Qtde.:0,335   UN: KG9   Vl. Unit.:   6,49 	Vl. Total
2,17
BEB.LACTEA TODDYNHO (Código: AR014595 )
Qtde.:5   UN: UND9   Vl. Unit.:   2,99 	Vl. Total
14,95
Qtd. total de itens:64
Valor total R\$:954,79
''';

      final items = parser.parse(rawText);

      expect(items.map((item) => item.name), [
        'LING T CALAB SADIA',
        'CEBOLA ATACADAO',
        'BEB LACTEA TODDYNHO',
      ]);
      expect(items.map((item) => item.quantity), [1, 1, 5]);
      expect(items.map((item) => item.unitPrice), [
        closeTo(12.74, 0.001),
        closeTo(2.17, 0.001),
        closeTo(2.99, 0.001),
      ]);
    },
  );

  test('ignores OCR header and split kilo continuation rows', () {
    const rawText = '''
CNP J: 93,209.765/0654-05 UMS SUPERMERCADOS DO BRASIL LTDA
EST ESTRADA DA GABIROBA, 750, JD. GUAPIUVA, CARAPICUIBA,SP
tocunento Auxiliar da Note Fiscal de Carsunidor Eletronica
MAO E DOCUNENTO FISCAL
Codigt DeseriCOD
AR085684 LING.T.CALAB.SADIA 0,426kg x 29,90 R\$/kg
0,426 KG9 X 29,90
12,74
AR014692 CEBOLA ATACADAO 0,335kg x 6,49 R\$/kg
0,335 KG9 X 6,49
2,17
AR087134 SALSICHA PERDIGAO 1,646kg x 17,90 R\$/kg
1,646 KR9 X 17,90
29,46
''';

    final items = parser.parse(rawText);

    expect(items.map((item) => item.name), [
      'LING T CALAB SADIA',
      'CEBOLA ATACADAO',
      'SALSICHA PERDIGAO',
    ]);
    expect(items.map((item) => item.quantity), [1, 1, 1]);
    expect(items.map((item) => item.unitPrice), [
      closeTo(12.74, 0.001),
      closeTo(2.17, 0.001),
      closeTo(29.46, 0.001),
    ]);
  });

  test('calculates kilo item total when OCR image cuts off total column', () {
    const rawText = '''
AR005144 BACON PDC SEARA 0,252kg x 46,80 R\$/kg
AR001805 LIMAO TAITI TROPICAL 0,370kg x 3,99 R\$/kg
AR087134 SALSICHA PERDIGAO 1,646kg x 17,90 R\$/kg
''';

    final items = parser.parse(rawText);

    expect(items.map((item) => item.name), [
      'BACON PDC SEARA',
      'LIMAO TAITI TROPICAL',
      'SALSICHA PERDIGAO',
    ]);
    expect(items.map((item) => item.unitPrice), [
      closeTo(11.79, 0.01),
      closeTo(1.48, 0.01),
      closeTo(29.46, 0.01),
    ]);
  });

  test('merges OCR rows when product name and kilo prices are split', () {
    const rawText = '''
Codigo Descricao Qtde UN Vl Unit Vl Total
AR085684 LING.T.CALAB.SADIA Codiga Descricos
0,426 K89 29,90 12,74
AR014692 CEROLA ATACADAU
0,335 KG9 6,49 2,17
AR087134 SALSICHA PERDIGAO
1,646 KG9 X17,90 29,46
AR00724\$ PAO FORMA PANCO 1X500G 1 PCT9 7,29 7,29
AR06086i PACOCA S HELENA1
ND9 25,98 25,98
''';

    final items = parser.parse(rawText);

    expect(items.map((item) => item.name), [
      'LING T CALAB SADIA',
      'CEROLA ATACADAU',
      'SALSICHA PERDIGAO',
      'PAO FORMA PANCO',
      'PACOCA S HELENA',
    ]);
    expect(items.map((item) => item.quantity), [1, 1, 1, 1, 1]);
    expect(items.map((item) => item.unitPrice), [
      closeTo(12.74, 0.001),
      closeTo(2.17, 0.001),
      closeTo(29.46, 0.001),
      closeTo(7.29, 0.001),
      closeTo(25.98, 0.001),
    ]);
  });

  test(
    'parses detailed WMS receipt slices without duplicated numeric items',
    () {
      const rawText = '''
AR086392 LEITE FERM.YAKULT 1X6X80ML 2 UND9 9,97 19,94
AR001805 LIMAO TAITI TROPICAL 0,370kg x 3,99 R\$/kg 1,48
0,370 KG9 X 3,99
desconto sobre item
0,37
AR007454 LAVA ROUPA LIQ.OMO 1X1,4L 1 UND9 26,90 26,90
AR056943 PAPEL HIG.NEVE 1X12IR30M 1 UND9 51,91 51,91
AR059557 REF.COCA-COLA ZERO 12X200ML 2 BDJ1 25,08 50,16
AR072085 REF.PEPSI COLA 1X200ML 12 UND9 1,79 21,48
AR007386 REF.TISS TUBAINA 1X200ML 12 UND9 1,49 17,88
AR064206 REF.ANTARCTICA GUARA 1X200ML 12 UND9 1,79 21,48
AR060076 RF.FANTA LARANJA PET 12X200ML 1 BDJ1 20,28 20,28
Qtd. total de itens
Valor total R\$
''';

      final items = parser.parse(rawText);

      expect(items.map((item) => item.name), [
        'LEITE FERM YAKULT',
        'LIMAO TAITI TROPICAL',
        'LAVA ROUPA LIQ OMO',
        'PAPEL HIG NEVE',
        'REF COCA-COLA ZERO',
        'REF PEPSI COLA',
        'REF TISS TUBAINA',
        'REF ANTARCTICA GUARA',
        'RF FANTA LARANJA PET',
      ]);
      expect(items.map((item) => item.quantity), [
        2,
        1,
        1,
        1,
        2,
        12,
        12,
        12,
        1,
      ]);
      expect(items.map((item) => item.unitPrice), [
        closeTo(9.97, 0.001),
        closeTo(1.48, 0.001),
        closeTo(26.90, 0.001),
        closeTo(51.91, 0.001),
        closeTo(25.08, 0.001),
        closeTo(1.79, 0.001),
        closeTo(1.49, 0.001),
        closeTo(1.79, 0.001),
        closeTo(20.28, 0.001),
      ]);
    },
  );

  test('ignores WMS discount and totals rows', () {
    const rawText = '''
AR052734 BACON PDC SEARA 0,252kg x 46,80 R\$/kg 11,79
desconto sobre item
0,37 X69 X
AR075610 REFR.PEPSI COLA 1X200ML 12 UND9 1,79 21,48
desconto sobre item
1,20
Qtd. total de itens 125
Valor total R\$ 954,79
Desconto total R\$ 7,77
''';

    final items = parser.parse(rawText);

    expect(items.map((item) => item.name), [
      'BACON PDC SEARA',
      'REFR PEPSI COLA',
    ]);
    expect(items.map((item) => item.quantity), [1, 12]);
    expect(items.map((item) => item.unitPrice), [
      closeTo(11.79, 0.001),
      closeTo(1.79, 0.001),
    ]);
    expect(items[0].category, ShoppingCategory.meat);
    expect(items[1].category, ShoppingCategory.beverages);
  });

  test(
    'parses WMS middle receipt rows with package decimals and noisy units',
    () {
      const rawText = '''
AR007454 LAVA ROUPA LIQ.OMO 1X1,4L 1 UND9 26,90 26,90
AR065006 BISC.TRAKINAS RECH. 1X126G 1 UND9 3,25 3,25
AR072456 SALG.ELMA CHIPS 1X115G 1 UND9 10,98 10,98
AR083282 QJO.RALADO PARMESAO 1X40G 5 UND9 3,69 18,45
AR059557 REF.COCA-COLA ZERO 12X200ML 2 BDJ1 25,08 50,16
AR060076 RF.FANTA LARANJA PET 12X200ML 1 BDJ1 20,28 20,28
AR092035 ABS.ALWAYS NOITE 1X26UND 1 UND9 28,50 28,50
AR004986 DET.LIQ.MINUANO 1X500ML 3 UND9 2,35 7,05
AR023836 HASTES JOHNSON 1X1UND 1 CXT9 6,99 6,99
AR077513 DESINF.PATO GERM. 1X750ML 1 UND8 16,99 16,99
''';

      final items = parser.parse(rawText);

      expect(items.map((item) => item.name), [
        'LAVA ROUPA LIQ OMO',
        'BISC TRAKINAS RECH',
        'SALG ELMA CHIPS',
        'QJO RALADO PARMESAO',
        'REF COCA-COLA ZERO',
        'RF FANTA LARANJA PET',
        'ABS ALWAYS NOITE',
        'DET LIQ MINUANO',
        'HASTES JOHNSON',
        'DESINF PATO GERM',
      ]);
      expect(items.map((item) => item.quantity), [
        1,
        1,
        1,
        5,
        2,
        1,
        1,
        3,
        1,
        1,
      ]);
      expect(items.map((item) => item.unitPrice), [
        closeTo(26.90, 0.001),
        closeTo(3.25, 0.001),
        closeTo(10.98, 0.001),
        closeTo(3.69, 0.001),
        closeTo(25.08, 0.001),
        closeTo(20.28, 0.001),
        closeTo(28.50, 0.001),
        closeTo(2.35, 0.001),
        closeTo(6.99, 0.001),
        closeTo(16.99, 0.001),
      ]);
      expect(items.map((item) => item.category), [
        ShoppingCategory.cleaning,
        ShoppingCategory.bakery,
        ShoppingCategory.snacks,
        ShoppingCategory.dairy,
        ShoppingCategory.beverages,
        ShoppingCategory.beverages,
        ShoppingCategory.personalCare,
        ShoppingCategory.cleaning,
        ShoppingCategory.personalCare,
        ShoppingCategory.cleaning,
      ]);
    },
  );

  test('stops parsing before WMS fiscal footer and TEF details', () {
    const rawText = '''
AR001201 REFR.PO TANG 1X18G 4 UND9 1,39 5,56
desconto sobre item
0,40
AR080975 REFR.PO TANG 1X18G 1 UND9 1,39 1,39
Qtd. total de itens 125
Valor total R\$ 954,79
Desconto total R\$ 7,77
VALOR PAGO R\$ 947,02
Consulte pela Chave de Acesso em
3526 0593 2097 6505 5405 6551 8000 0316 9510 4657 9170
CIEL0-ALELO ALIMENTACAO
VALOR:947,02 S.DISP:24,59
TEL:(11) 2133-9425
''';

    final items = parser.parse(rawText);

    expect(items.map((item) => item.name), ['REFR PO TANG']);
    expect(items.single.quantity, 5);
    expect(items.single.unitPrice, closeTo(1.39, 0.001));
    expect(items.single.category, ShoppingCategory.beverages);
  });

  test('classifies WMS bottom receipt abbreviations by market category', () {
    const rawText = '''
AR077815 L.COND.ITAMBE SEMI 1X395G 3 UND9 6,79 20,37
AR008621 KIT DOVE SHAMPCOND 1X1KIT 1 UND9 29,90 29,90
AR048849 MAC.D.BENTA PENA 1X500G 1 UND9 3,57 3,57
AR001730 CHEIRO VERDE 1X1UND 1 UND9 3,99 3,99
AR096401 SHAMP.CLEAR 1X400ML 1 UND9 29,98 29,98
AR013190 CR.D.COLGATE T.12 1X90G 1 UND9 9,80 9,80
AR054637 BISC.CLUB SOCIAL 1X288G 1 UND9 11,49 11,49
AR006035 LIMP.PERF.CONC.COALA 1X120ML 2 UND9 14,50 29,00
AR065760 FOLHA LOURO KISABOR 1X4G 2 UND9 1,99 3,98
AR034787 AZEITE OLIVA GALLO 1X250ML 1 UND9 17,90 17,90
AR072176 POLPA VERI UDO 1X680G 1 UND9 15,90 15,90
AR069813 REFR.PO MID ABACAXI 1X20G 4 UND9 0,98 3,92
AR056942 PAPEL HIG.NEVE 1X12IR30M 1 UND9 51,91 51,91
AR025200 SAB.DOVE BRANCO 1X90G 2 UND9 5,39 10,78
AR007242 CHAI LEAO CAMOMILA 1X10G 1 UND9 2,58 2,58
''';

    final items = parser.parse(rawText);

    expect(items.map((item) => item.name), [
      'L COND ITAMBE SEMI',
      'KIT DOVE SHAMPCOND',
      'MAC D BENTA PENA',
      'CHEIRO VERDE',
      'SHAMP CLEAR',
      'CR D COLGATE T 12',
      'BISC CLUB SOCIAL',
      'LIMP PERF CONC COALA',
      'FOLHA LOURO KISABOR',
      'AZEITE OLIVA GALLO',
      'POLPA VERI UDO',
      'REFR PO MID ABACAXI',
      'PAPEL HIG NEVE',
      'SAB DOVE BRANCO',
      'CHAI LEAO CAMOMILA',
    ]);
    expect(items.map((item) => item.quantity), [
      3,
      1,
      1,
      1,
      1,
      1,
      1,
      2,
      2,
      1,
      1,
      4,
      1,
      2,
      1,
    ]);
    expect(items.map((item) => item.category), [
      ShoppingCategory.dairy,
      ShoppingCategory.personalCare,
      ShoppingCategory.grainsAndPasta,
      ShoppingCategory.produce,
      ShoppingCategory.personalCare,
      ShoppingCategory.personalCare,
      ShoppingCategory.bakery,
      ShoppingCategory.cleaning,
      ShoppingCategory.condiments,
      ShoppingCategory.condiments,
      ShoppingCategory.frozen,
      ShoppingCategory.beverages,
      ShoppingCategory.personalCare,
      ShoppingCategory.personalCare,
      ShoppingCategory.beverages,
    ]);
  });

  test('returns declared total and the recognized difference', () {
    const rawText = '''
AR001 ARROZ TIPO 1 1 UND9 20,00 20,00
AR002 FEIJAO CARIOCA 2 UND9 7,50 15,00
Valor total R\$ 36,90
VALOR PAGO R\$ 34,00
''';

    final result = parser.parseReceipt(rawText);

    expect(result.items, hasLength(2));
    expect(result.recognizedTotal, closeTo(35, 0.001));
    expect(result.declaredTotal, closeTo(36.90, 0.001));
    expect(result.differenceFromDeclaredTotal, closeTo(-1.90, 0.001));
  });

  test('returns no declared total when the receipt does not expose one', () {
    const rawText = 'AR001 CAFE TORRADO 1 UND9 18,90 18,90';

    final result = parser.parseReceipt(rawText);

    expect(result.items, hasLength(1));
    expect(result.declaredTotal, isNull);
    expect(result.differenceFromDeclaredTotal, isNull);
  });

  test(
    'extracts declared total when OCR splits its value onto the next line',
    () {
      const rawText = '''
AR001 CAFE TORRADO 1 UND9 18,90 18,90
Valor total R\$
18,90
''';

      final result = parser.parseReceipt(rawText);

      expect(result.declaredTotal, 18.90);
      expect(result.differenceFromDeclaredTotal, closeTo(0, 0.001));
    },
  );
}
