# 34 — Nome da lista

## Implementação

`lib/src/presentation/dialogs/list_name_dialog.dart`, exportado pela fachada `dialogs_and_sheets.dart`, mantém a API pública `showListNameDialog(context, title, confirmLabel, initialValue)`. Os chamadores continuam fornecendo o título, ação e nome real para criação, renomeação e duplicação. Não há nome fictício inserido no app.

Tema Mercado Editorial restrito ao modal: superfície marfim/carvão, título Newsreader, conteúdo Public Sans, borda externa de 12 dp e campo/botões com raio de 8 dp. Ações com pelo menos 48 dp. Largura máxima de 390 dp; cabeçalho e formulário rolam quando necessário, com ações fixas acima do teclado.

Validação de nome não vazio após `trim`, retorno aparado, autofocus e envio pelo IME preservados. Cancelar, Fechar e voltar devolvem `null`. O controlador agora pertence ao estado do widget e é descartado junto com o formulário.

## Decisões sobre o Stitch

- **Fechar:** incluído. Atalho simples para a ação de cancelamento já existente; nenhuma informação é persistida.
- **Indicador de arrastar:** omitido. Este fluxo continua como diálogo central, sem gesto de arraste; o indicador prometeria uma interação inexistente.
- **Nome e rótulos ilustrativos:** substituídos pelos argumentos reais. O mesmo desenho atende Criar, Salvar e Duplicar sem transformar todos os fluxos em criação.
- **Obrigatoriedade e exemplo:** o asterisco e a dica explicam a validação existente; não criam novas regras, limite de tamanho ou dados adicionais.
- **Sombra ampla e raio de 16 dp:** adaptados ao sistema editorial vigente, com borda discreta e raio de 12 dp.

## Verificação

5 testes novos aprovados: golden em 390 × 844; autofocus, nome inicial e áreas de toque; títulos/ações de criação, renomeação e duplicação com retorno aparado; validação por botão e IME; Cancelar/Fechar/voltar sem salvar; 320 × 568 em modo escuro com texto 1,5, título longo e teclado de 210 dp, confirmando geometria das duas ações acima de 358 dp.

Análise estática dos arquivos novos sem problemas. Golden conferido: `test/presentation/goldens/list_name_stitch_390.png`.
