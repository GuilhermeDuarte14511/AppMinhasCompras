# 47 — Opções offline, modo escuro

## Implementação

- A tela usa `AppOptionsPage`, compartilhada com 46. A apresentação dos estados reais foi extraída para `lib/src/presentation/account/cloud_sync_status_panel.dart`, com o mesmo contrato de conectividade, sincronização, contadores e última sincronização.
- O painel editorial apresenta ícone, estado, selo **Sem rede**, pendências, data real da última sincronização, totais e contagens de listas, histórico, catálogo e despensa. O corpo rola e as métricas se empilham em largura reduzida ou com texto ampliado.
- Conta, tema, atualização de catálogo, diagnóstico, finanças e onboarding continuam integrados às ações existentes. Nenhum dado ilustrativo do HTML foi persistido.

## Diferenças avaliadas entre Stitch e app

| Stitch | Decisão integrada |
| --- | --- |
| Nome Helena Ramos e e-mail de exemplo | Perfil real recebido pela tela. |
| 2 registros e “Há 42 minutos” | Contadores reais; data `dd/MM HH:mm` recebida pelo repositório, ou **Nunca sincronizado**. Não depende de um contador temporal fictício. |
| Selo **Sem rede** | Adicionado como indicação acessível da conectividade real. |
| Selo **Orçamento ativo** | Não exibido: a tela não recebe evidência de um orçamento ativo. Não justifica criar uma regra nova para um detalhe visual. |
| Apenas claro/escuro | Preservado também o tema **Sistema**, funcionalidade existente. |
| Apenas duas métricas | Mantidos os totais e a distribuição por entidade disponíveis hoje, úteis para diagnóstico. |

## Correções funcionais justificadas

- Sem internet tem prioridade sobre uma indicação transitória de envio. Uma atualização concorrente das flags não anuncia **Sincronizando online** enquanto offline.
- Pendência parada não mostra progresso indeterminado. Progresso aparece somente durante sincronização real com conexão, evitando indicar que uma fila está sendo processada quando apenas aguarda.
- Flag de pendência sem quantidade conhecida usa **Alterações aguardando sincronização**, sem afirmar que zero registros aguardam envio.
- Contadores negativos são limitados a zero; pendências são limitadas ao total. Sem uma sincronização anterior confirmada, a quantidade **Sincronizados** mostra `—`, pois total menos pendências não comprova envio inicial.
- Essas correções são de apresentação dos dados já existentes. Não exigem alterações em Data Connect, rules ou contratos remotos.

## Validação

`test/presentation/options_offline_redesign_test.dart` cobre sete cenários: referência visual escura 390×884, corrida de flags offline/envio, fila parada e envio ativo, quantidade desconhecida, atualização dos dados recebidos, contadores inválidos e largura 320×568 com escala de texto 1,5. Golden com fontes locais: `test/presentation/goldens/options_offline_stitch_390.png`.

Validação integrada de 46 e 47: 65 testes aprovados, incluindo as opções online, perfil, diagnóstico, fluxos principais do app e política de sincronização. Análise estática completa sem problemas.
