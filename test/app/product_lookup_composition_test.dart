import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/app/shopping_list_app.dart';
import 'package:lista_compras_material/src/data/remote/cosmos_backend_product_lookup_service.dart';
import 'package:lista_compras_material/src/data/remote/open_food_facts_product_lookup_service.dart';

void main() {
  group('default product lookup composition', () {
    test('always uses the authenticated backend before Open Facts', () {
      final services = buildDefaultProductLookupServices();

      expect(services, hasLength(3));
      expect(services[0], isA<CosmosBackendProductLookupService>());
      expect(services[1], isA<OpenProductsFactsProductLookupService>());
      expect(services[2], isA<OpenFoodFactsProductLookupService>());
    });
  });
}
