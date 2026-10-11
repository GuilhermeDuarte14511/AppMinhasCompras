import '../application/finance_integration.dart';
import 'local/secure_finance_integration_store.dart';
import 'remote/http_finance_integration_repository.dart';

const _productionFinanceApi =
    'https://southamerica-east1-financaadois-8de95.cloudfunctions.net/'
    'shoppingIntegrationApi';

FinanceIntegrationRepository createFinanceIntegrationRepository() {
  const configuredUrl = String.fromEnvironment(
    'FINANCE_INTEGRATION_API_URL',
    defaultValue: _productionFinanceApi,
  );
  return HttpFinanceIntegrationRepository(
    baseUri: Uri.parse(configuredUrl),
    store: SecureFinanceIntegrationStore(),
  );
}
