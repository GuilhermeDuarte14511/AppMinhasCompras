# Lembrete da lista — implementação

Referência: `index.html`, `preview.png` e tela Stitch `08bd270eabfd42139e8b1809acb68751`.

## Implementação

`lib/src/presentation/dialogs/reminder_editor_dialog.dart`, exportado por `dialogs_and_sheets.dart`. Mantém ativação, seletores reais de data e hora, validação de horário futuro, remoção e cancelamento. Salvar retorna a configuração ao fluxo existente da lista; desativar ou remover retorna `clear: true`. Cancelar e fechar retornam `null`.

Título Newsreader, controles Public Sans, superfícies editoriais e botões de pelo menos 48 dp. Conteúdo rolável com rodapé fixo. A superfície do switch usa Material para manter pintura e interação corretas. Lembretes vencidos podem abrir o calendário sem erro: somente a data inicial do seletor é limitada ao intervalo permitido, sem modificar a configuração ao cancelar. O relógio pode ser injetado para verificação determinística e usa DateTime.now no app.

## Avaliação das diferenças do Stitch

- Fechar foi incluído como saída equivalente a Cancelar.
- O Salvar duplicado e a alça de arraste foram omitidos por serem redundantes ou incompatíveis com o diálogo.
- Não foi copiada a afirmação de alerta já agendado, som garantido ou operação sem internet em todas as plataformas. O agendamento continua sendo responsabilidade do serviço existente após salvar.
- A data e o horário apresentados vêm da configuração real ou do padrão existente de uma hora à frente.

## Verificação

Seis testes em `test/presentation/reminder_redesign_test.dart`: golden com data real inicial, salvar e padrão desativado, desativar/remover/cancelar/fechar, lembrete vencido, alteração pelos seletores de data e hora e layout escuro compacto com texto ampliado e teclado. Golden: `test/presentation/goldens/reminder_stitch_390.png`, conferido visualmente.

Regressão conjunta das duas telas, integração financeira, listas compartilhadas, orçamento e fluxos do app: 59 testes aprovados. `flutter analyze --no-pub`: sem problemas.
