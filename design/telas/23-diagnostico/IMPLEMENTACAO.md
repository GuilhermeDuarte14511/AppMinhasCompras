# Sincronização e diagnóstico — implementação Flutter

Referência: `index.html` e `preview.png` desta pasta, projeto Stitch existente.

## Apresentação

- Tema Mercado Editorial local, Newsreader no título, Public Sans nos controles, superfícies planas e linhas de registros.
- Painel de estado com descrição e última verificação reais. Ações de sincronizar e copiar relatório dentro do painel.
- Registros locais, identificação, ambiente, sincronização, políticas de importação e listas compartilhadas em seções legíveis.
- Coluna limitada a 600 dp; linhas empilhadas em tela estreita ou texto ampliado; cores de tema escuro e áreas seguras preservadas.

## Funcionalidade e dados

Implementação: `lib/src/presentation/sync_diagnostics_page.dart`.

As operações originais de sincronizar, atualizar o snapshot depois da operação, impedir requisições concorrentes, informar falha/sucesso e copiar `buildSupportReport()` permanecem intactas. O ícone de atualização executa a mesma sincronização manual existente.

O layout usa somente campos já disponíveis em `SyncDiagnosticsSnapshot` e `SharedListDiagnosticEntry`. Mantém as contagens locais/pendentes/sincronizadas, papel e membros, itens, importação, espelho local e erros de cada lista. Identificação e datas usam o snapshot real; ausência de sync mostra “Nunca”.

Os exemplos do HTML “Estável”, contagem separada na nuvem e indicação de que cada lista está sincronizada não foram implementados: não há essas garantias nos dados disponíveis. Não há nomes, datas ou provedores ilustrativos fixos na interface.

## Verificação

- 9 testes de apresentação aprovados: 3 existentes em `sync_diagnostics_page_test.dart` e 6 novos em `diagnostics_redesign_test.dart`.
- Golden `test/presentation/goldens/diagnostics_stitch_390.png`, 390 × 884, inspecionado visualmente.
- Casos adicionais: bloqueio de ação durante sync, atualização real, falha e retorno do botão, relatório atualizado, infos completas e modo escuro 320 × 568 com escala de texto 1,5.
- Nenhuma alteração nos serviços, repositórios ou lógica de sincronização.
