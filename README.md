# Minhas Compras

App Flutter moderno (Material 3) para lista de compras, com foco em uso local/offline e produtividade.

## O que o app tem hoje
- Menu inicial com:
- `Começar nova lista de compras`
  - `Minhas listas de compras`
  - `Nova lista baseada em antiga`
- Animação de abertura moderna ao iniciar o app (carrinhos/bolsas, ~2.5s).
- Persistência local no celular com `SharedPreferences`.
- Criação, edição, exclusão e clonagem de listas.
- Exclusão em lote e `Limpar todas as listas` em `Minhas listas`.
- Cadastro de itens com:
  - botão `Ler código de barras` (opcional)
  - campo manual de código de barras opcional
  - nome
  - categoria
  - quantidade
  - valor unitário com máscara monetária (`R$ 0,00`)
- Consulta por código em APIs online:
  - Cosmos API (Brasil, quando `COSMOS_API_TOKEN` for informado)
  - Open Products Facts
  - Open Food Facts
- Fallback para catálogo local por código quando nenhuma API retorna produto.
- Cadastro manual continua disponível (scanner não é obrigatório).
- Importação de cupom fiscal por texto (OCR/PDF):
  - cola o texto bruto do cupom
  - parser tenta extrair nome, quantidade e valor
  - preview antes de importar
  - mescla com itens existentes da lista
- Todo produto adicionado/atualizado entra no catálogo local para autocomplete.
- Cálculo automático de subtotal por item e total da lista.
- Busca, ordenação, filtro por categoria e modo mercado.
- Modo compra no mercado (tela dedicada):
  - foco em itens pendentes
  - swipe para marcar comprado/pendente
  - controle rápido de quantidade
  - progresso de compra em tempo real
- Fechamento de compra:
  - botão para fechar compra direto na tela da lista
  - opção de marcar pendentes como comprados no fechamento
  - snapshot completo salvo no histórico
  - ao fechar, volta automaticamente para a tela inicial
  - lista fica bloqueada para edição até ser reaberta manualmente
- Histórico mensal de compras:
  - agrupamento por mês/ano
  - totais planejado x comprado por mês
  - detalhe por fechamento (itens, valores, status)
  - snapshot de saldos no fechamento e consumo por prioridade
  - exclusão individual e limpeza total do histórico
- Orçamento por lista com alerta de excesso.
- Histórico de preço por produto.
- Bloqueio de item duplicado por nome na mesma lista.
- Lembrete local por data e horário (dia/mês/ano + hora), sem servidor.
- Widgets de tela inicial (Android), atualizados automaticamente:
  - `Resumo de Compras` (listas, pendentes, total, última atualização)
  - `Lista Prioritária` (lista em foco, total e status de orçamento)
- Backup local em JSON:
  - exportar para arquivo (ou área de transferência)
  - importar de arquivo JSON
  - escolher entre mesclar ou substituir listas
  - inclui listas + histórico mensal de fechamentos

## Arquitetura aplicada
- `app`:
  - `shopping_list_app.dart` (composição do app, DI e ciclo de inicialização)
- `core`:
  - `utils/id_utils.dart` (geração de IDs)
  - `utils/text_utils.dart` (normalização e sanitização)
  - `utils/format_utils.dart` (formatação monetária e datas)
- `presentation`:
  - `launch.dart` (splash/entrada animada)
  - `pages.dart` (telas principais)
  - `dialogs_and_sheets.dart` (modais, formulários, scanner, formatadores)
  - `extensions/classification_ui_extensions.dart` (ícones e adaptação visual)
  - `utils/time_utils.dart` (formatação de horário para UI)
- `domain`:
  - `models_and_utils.dart` (entidades e value objects)
  - `classifications.dart` (categorias, filtros e ordenação sem dependência de UI)
- `application`:
  - `ports.dart` (contratos/interfaces e gateways)
  - `store_and_services.dart` (`ShoppingListsStore`, orquestração e regras)
- `data`:
  - `local/storages.dart` (persistência local via `SharedPreferences`, incluindo histórico de fechamentos)
  - `repositories/product_catalog_repository.dart` (implementa gateway de catálogo)
  - `remote/open_food_facts_product_lookup_service.dart` (Open Facts)
  - `remote/cosmos_product_lookup_service.dart` (Cosmos API Brasil)
  - `services/backup_service.dart` (import/export JSON)
  - `services/reminder_service.dart` (notificações locais)
  - `services/home_widget_service.dart` (integração com widgets Android)
- Injeção de dependências pelo `ShoppingListApp` para facilitar testes e evolução.
- Sem uso de `part/part of`: cada módulo é um arquivo Dart independente.
- `main.dart` contém apenas bootstrap (sem export global de camadas internas).

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

## Executar no navegador (Flutter Web)
```powershell
cd "d:\Projetos\Android Flutter\lista_compras_material"
& "C:\flutter\bin\flutter.bat" run -d chrome
```

## Publicar Web no Firebase Hosting
Pré-requisitos:
- Firebase CLI instalado (`npm i -g firebase-tools`)
- Login no Firebase (`firebase login`)
- Projeto selecionado (este repo já inclui `.firebaserc` com `minhascompras-3abbe`)

Build e deploy:
```powershell
cd "d:\Projetos\Android Flutter\lista_compras_material"
& "C:\flutter\bin\flutter.bat" build web --release
firebase deploy --only hosting
```

Observações:
- O app Web usa a mesma base de código Dart, mesmas telas e mesma lógica.
- O Hosting está configurado para SPA (qualquer rota cai em `index.html`).
- O conteúdo servido vem de `build/web`.

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
Não salve token hardcoded no código ou em arquivo versionado.

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

## Permissões Android
No `AndroidManifest.xml` foram adicionadas:
- `POST_NOTIFICATIONS`
- `SCHEDULE_EXACT_ALARM`
- `RECEIVE_BOOT_COMPLETED`
- `VIBRATE`
- `CAMERA`

## Widgets na tela inicial (Android)
1. Abra o app e crie/atualize listas.
2. Na tela inicial do celular, toque e segure em uma área vazia.
3. Entre em `Widgets`.
4. Procure por `Minhas Compras`.
5. Adicione:
   - `Resumo de Compras`
   - `Lista Prioritária`
6. Toque no widget para abrir o app.

## Testes e análise
```powershell
cd "d:\Projetos\Android Flutter\lista_compras_material"
& "C:\flutter\bin\flutter.bat" analyze
& "C:\flutter\bin\flutter.bat" test
```

## Estrutura principal
- `lib/main.dart`: bootstrap do app e exports públicos para testes.
- `lib/src/app/shopping_list_app.dart`: configuração do MaterialApp e composição de dependências.
- `lib/src/presentation/*`: telas e componentes visuais.
- `lib/src/domain/*`: modelos e utilitários de domínio.
- `lib/src/application/*`: contratos e store.
- `lib/src/data/*`: persistência, repositório e serviços.
- `test/widget_test.dart`: testes de fluxo principal.

## Próximo passo natural (quando quiser servidor)
- Adicionar autenticação e sincronização para compartilhar listas entre dispositivos.
