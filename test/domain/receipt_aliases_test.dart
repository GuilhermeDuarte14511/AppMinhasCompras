import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/receipt_aliases.dart';

void main() {
  test(
    'expands common supermarket receipt abbreviations from public NFC-e',
    () {
      expect(
        expandReceiptAliases('BISC TRAKINAS MORANGO'),
        contains('biscoito'),
      );
      expect(
        expandReceiptAliases('CHOC SNICKERS NOUGAT'),
        contains('chocolate'),
      );
      expect(
        expandReceiptAliases('DET LIQ GOTA LIMPA'),
        contains('detergente liquido'),
      );
      expect(
        expandReceiptAliases('CR.DENTAL SORRISO'),
        contains('creme dental'),
      );
      expect(
        expandReceiptAliases('ACHOC.PO TODDY'),
        contains('achocolatado po'),
      );
      expect(expandReceiptAliases('PAPEL HIG COTTON'), contains('higienico'));
      expect(expandReceiptAliases('SHHEAD SHOULD'), contains('shampoo'));
      expect(expandReceiptAliases('COND HUGGIES'), contains('condicionador'));
      expect(expandReceiptAliases('REFRI ANTARCTICA GUA'), contains('guarana'));
      expect(expandReceiptAliases('LOGURTE NESTLE NATUR'), contains('iogurte'));
    },
  );
}
