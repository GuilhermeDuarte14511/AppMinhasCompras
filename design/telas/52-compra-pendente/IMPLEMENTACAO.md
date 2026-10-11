# Implementação — Compra salva: envio pendente

## Visual e arquitetura

Referência: `index.html` e `preview.png` desta pasta. A variante pendente de `showPurchaseCompletionDialog` agora usa modal centralizado de até 340 dp, margem de 20 dp, superfície editorial com raio de 16 dp, ícone de nuvem discreto, título Newsreader centralizado, divisor curto, duas linhas de status, mensagem recebida em bloco contornado e ação Concluir de 48 dp. Corpo rolável e ação persistente respeitam texto ampliado, modo escuro e altura disponível com teclado.

O componente privado `_PendingCompletionDialog` mantém o contrato público existente (`financeMessage`) e a navegação do chamador. A variante concluída da tela 31 e o estado de atenção mantêm seu visual e suas regras. O diálogo não grava compras, repete envios nem modifica o resultado já registrado: o fechamento continua no editor e no serviço existente.

## Diferenças funcionais e decisões

- Mantidos histórico salvo, sincronização da conta em segundo plano, mensagem integral selecionável e Concluir. Barreira externa permanece bloqueada; voltar do sistema retorna ao fluxo como antes.
- Retorno parcial real (`1 de 2 pagamentos sincronizados`) mantém o estado pendente e indica **Envio parcial**. Retorno completo (`2 de 2`) continua concluído. Falha que também menciona pendência mantém **Requer atenção** como prioridade.
- A promessa fixa do Stitch de envio futuro “sem duplicar” e “fila de transmissão ativada” foi substituída pela mensagem real do serviço. O diálogo não recebe evidência que permita afirmar esses resultados para toda falha. Não adicionamos repetição de envio ou indicador de progresso sem operação ativa.
- Valores, loja, data, produtos e unidades ilustrativos do fundo do Stitch não são reproduzidos: o fundo é a tela real que abriu o diálogo, e o contrato não fornece esses dados. Não acrescentamos uma segunda fonte de totais nem uma chamada adicional para decoração.
- O ícone de espera utiliza a cor secundária da paleta existente e texto explícito, preservando acessibilidade nos dois temas.
- Nenhuma alteração em modelos, Data Connect ou rules é necessária: esta tela comunica o resultado do fluxo já integrado.

## Verificação

14 testes de widget aprovados: seis novos desta variante e oito regressões da conclusão existente. Cobrem golden de 390 × 844 inspecionado, retorno da Future ao concluir/voltar, toque externo bloqueado, texto real selecionável, parcial versus completo, atenção prioritária, ausência de valores inventados e conteúdo longo em 320 × 568 com tema escuro, escala de texto 1,5 e teclado de 180 dp. Golden: `test/presentation/goldens/purchase_pending_completion_stitch_390.png`.

Validação integrada de 52/53: 67 testes de apresentação e fluxos principais aprovados, mais 21 testes de importação fiscal, correspondência, bridge financeiro e sincronização dividida (88 no total). Análise estática completa sem problemas; formatação e verificação de diff limpas.
