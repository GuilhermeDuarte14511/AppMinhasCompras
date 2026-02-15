# Minhas Compras

App Flutter moderno (Material 3) para lista de compras, com foco em uso local/offline e produtividade.

## O que o app tem hoje
- Menu inicial com:
  - `Comecar nova lista de compras`
  - `Minhas listas de compras`
  - `Nova lista baseada em antiga`
- Animacao de abertura moderna ao iniciar o app (carrinhos/bolsas, ~2.5s).
- Persistencia local no celular com `SharedPreferences`.
- Criacao, edicao, exclusao e clonagem de listas.
- Exclusao em lote e `Limpar todas as listas` em `Minhas listas`.
- Cadastro de itens com:
  - botao `Ler codigo de barras` (opcional)
  - campo manual de codigo de barras opcional
  - nome
  - categoria
  - quantidade
  - valor unitario com mascara monetaria (`R$ 0,00`)
- Consulta por codigo em APIs online:
  - Cosmos API (Brasil, quando `COSMOS_API_TOKEN` for informado)
  - Open Products Facts
  - Open Food Facts
- Fallback para catalogo local por codigo quando nenhuma API retorna produto.
- Cadastro manual continua disponivel (scanner nao e obrigatorio).
- Importacao de cupom fiscal por texto (OCR/PDF):
  - cola o texto bruto do cupom
  - parser tenta extrair nome, quantidade e valor
  - preview antes de importar
  - mescla com itens existentes da lista
- Todo produto adicionado/atualizado entra no catalogo local para autocomplete.
- Calculo automatico de subtotal por item e total da lista.
- Busca, ordenacao, filtro por categoria e modo mercado.
- Modo compra no mercado (tela dedicada):
  - foco em itens pendentes
  - swipe para marcar comprado/pendente
  - controle rapido de quantidade
  - progresso de compra em tempo real
- Fechamento de compra:
  - botao para fechar compra direto na tela da lista
  - opcao de marcar pendentes como comprados no fechamento
  - snapshot completo salvo no historico
  - ao fechar, volta automaticamente para a tela inicial
  - lista fica bloqueada para edicao ate ser reaberta manualmente
- Historico mensal de compras:
  - agrupamento por mes/ano
  - totais planejado x comprado por mes
  - detalhe por fechamento (itens, valores, status)
  - snapshot de saldos no fechamento e consumo por prioridade
  - exclusao individual e limpeza total do historico
- Orcamento por lista com alerta de excesso.
- Historico de preco por produto.
- Bloqueio de item duplicado por nome na mesma lista.
- Lembrete local por data e horario (dia/mes/ano + hora), sem servidor.
- Widgets de tela inicial (Android), atualizados automaticamente:
  - `Resumo de Compras` (listas, pendentes, total, ultima atualizacao)
  - `Lista Prioritaria` (lista em foco, total e status de orcamento)
- Backup local em JSON:
  - exportar para arquivo (ou area de transferencia)
  - importar de arquivo JSON
  - escolher entre mesclar ou substituir listas
  - inclui listas + historico mensal de fechamentos

## Arquitetura aplicada
- `app`:
  - `shopping_list_app.dart` (composicao do app, DI e ciclo de inicializacao)
- `core`:
  - `utils/id_utils.dart` (geracao de IDs)
  - `utils/text_utils.dart` (normalizacao e sanitizacao)
  - `utils/format_utils.dart` (formatacao monetaria e datas)
- `presentation`:
  - `launch.dart` (splash/entrada animada)
  - `pages.dart` (telas principais)
  - `dialogs_and_sheets.dart` (modais, formularios, scanner, formatadores)
  - `extensions/classification_ui_extensions.dart` (icones e adaptacao visual)
  - `utils/time_utils.dart` (formatacao de horario para UI)
- `domain`:
  - `models_and_utils.dart` (entidades e value objects)
  - `classifications.dart` (categorias, filtros e ordenacao sem dependencia de UI)
- `application`:
  - `ports.dart` (contratos/interfaces e gateways)
  - `store_and_services.dart` (`ShoppingListsStore`, orquestracao e regras)
- `data`:
  - `local/storages.dart` (persistencia local via `SharedPreferences`, incluindo historico de fechamentos)
  - `repositories/product_catalog_repository.dart` (implementa gateway de catalogo)
  - `remote/open_food_facts_product_lookup_service.dart` (Open Facts)
  - `remote/cosmos_product_lookup_service.dart` (Cosmos API Brasil)
  - `services/backup_service.dart` (import/export JSON)
  - `services/reminder_service.dart` (notificacoes locais)
  - `services/home_widget_service.dart` (integracao com widgets Android)
- Injecao de dependencias pelo `ShoppingListApp` para facilitar testes e evolucao.
- Sem uso de `part/part of`: cada modulo e um arquivo Dart independente.
- `main.dart` contem apenas bootstrap (sem export global de camadas internas).

## Tecnologias
- Flutter + Dart
- Material 3
- `shared_preferences`
- `intl`
- `file_picker`
- `flutter_local_notifications`
- `flutter_timezone`
- `http`
- `mobile_scanner`
- `timezone`
- `home_widget`

## Executar (Windows)
```powershell
cd "d:\Projetos\Android Flutter\lista_compras_material"
& "C:\flutter\bin\flutter.bat" pub get
& "C:\flutter\bin\flutter.bat" run
```

## Executar com Cosmos API (opcional)
Se quiser habilitar busca da Cosmos por GTIN, rode com `--dart-define`:
```powershell
cd "d:\Projetos\Android Flutter\lista_compras_material"
& "C:\flutter\bin\flutter.bat" run `
  --dart-define=COSMOS_API_TOKEN=SEU_TOKEN_AQUI
```
Para release:
```powershell
& "C:\flutter\bin\flutter.bat" run -d ZF524V2GB4 --release `
  --dart-define=COSMOS_API_TOKEN=SEU_TOKEN_AQUI
```
Nao salve token hardcoded no codigo ou em arquivo versionado.

## Emulador Android
```powershell
cd "d:\Projetos\Android Flutter\lista_compras_material"
& "C:\flutter\bin\flutter.bat" emulators
& "C:\flutter\bin\flutter.bat" emulators --launch <ID_DO_EMULADOR>
& "C:\flutter\bin\flutter.bat" run
```

## Importante no Windows (Developer Mode)
Como o app usa plugins, habilite `Developer Mode` para symlink:
```powershell
start ms-settings:developers
```

Depois:
```powershell
cd "d:\Projetos\Android Flutter\lista_compras_material"
& "C:\flutter\bin\flutter.bat" clean
& "C:\flutter\bin\flutter.bat" pub get
```

## Permissoes Android
No `AndroidManifest.xml` foram adicionadas:
- `POST_NOTIFICATIONS`
- `SCHEDULE_EXACT_ALARM`
- `RECEIVE_BOOT_COMPLETED`
- `VIBRATE`
- `CAMERA`

## Widgets na tela inicial (Android)
1. Abra o app e crie/atualize listas.
2. Na tela inicial do celular, toque e segure em uma area vazia.
3. Entre em `Widgets`.
4. Procure por `Minhas Compras`.
5. Adicione:
   - `Resumo de Compras`
   - `Lista Prioritaria`
6. Toque no widget para abrir o app.

## Testes e analise
```powershell
cd "d:\Projetos\Android Flutter\lista_compras_material"
& "C:\flutter\bin\flutter.bat" analyze
& "C:\flutter\bin\flutter.bat" test
```

## Estrutura principal
- `lib/main.dart`: bootstrap do app e exports publicos para testes.
- `lib/src/app/shopping_list_app.dart`: configuracao do MaterialApp e composicao de dependencias.
- `lib/src/presentation/*`: telas e componentes visuais.
- `lib/src/domain/*`: modelos e utilitarios de dominio.
- `lib/src/application/*`: contratos e store.
- `lib/src/data/*`: persistencia, repositorio e servicos.
- `test/widget_test.dart`: testes de fluxo principal.

## Proximo passo natural (quando quiser servidor)
- Adicionar autenticacao e sincronizacao para compartilhar listas entre dispositivos.
