# 59 — Adicionar saldo do Minhas Finanças

Implementação em `lib/src/presentation/payment_source_picker_sheet.dart`.

## Visual e comportamento

Header alinhado à esquerda, título Newsreader, contexto Minhas Finanças, seleção por cartões de fonte, reserva e ações empilhadas seguem o Stitch. Controles têm alvo mínimo de 48 dp; rodapé permanece acessível com teclado em 320 px e texto ampliado, respeitando áreas seguras e tema escuro. Conteúdo longo rola.

Escolha permanece explícita. Nome, tipo, disponibilidade, limite e final são dados reais do repository; detalhes opcionais ausentes não são inventados. Reserva usa BRL e preserva ID e tipo financeiro no PaymentBalance. Cancelar/fechar e alternativa manual preservados. Criação do meio mantém o fluxo da tela 60.

## Diferenças funcionais avaliadas

O Stitch mostra estado fixo “Atualizado”, finais e valores ilustrativos. Foram substituídos por data `FinanceWorkspace.asOf`, valores e metadados reais. Ação de atualizar fontes e recuperação “Tentar novamente” são úteis para disponibilidade financeira: usam `loadWorkspace`, revalidam a seleção por ID e disponibilidade, bloqueiam confirmação durante carga/falha e não reiniciam o valor digitado. Erro de reserva fica junto ao campo e não bloqueia criação de fonte. Reserva inválida, não finita ou superior ao disponível não pode ser confirmada; copiar a reserva não registra pagamento externo.

Nenhuma alteração em Data Connect, rules ou modelos foi necessária; APIs públicas existentes preservadas.

## Validação

8 testes do seletor: golden, metadados/centavos, limite real, desconexão/manual, vazio/cancelar, falha/retry/data, refresh com limite alterado, entrada ilimitada, compacto escuro com teclado. Golden atualizado em `test/presentation/goldens/payment_picker_stitch_390.png`. Integração pai e gates finais executados pelo agente principal.

## Evidência visual

Preview do Stitch inspecionado antes da implementação; golden claro comparado em duas rodadas de resultado. A variante compacta escura foi verificada por teste de layout em 320×568, texto 1,5 e teclado de 210 px, sem overflow e com ambas as ações acessíveis; não houve captura visual adicional dessa variante. O fixture final do golden usa duas fontes para corresponder à composição da referência; os testes de operação usam também três fontes para exercitar rolagem.

## Integração e gates finais do par 58/59

Histórico integrado ao editor com altura máxima de 85%, foco dispensado antes da abertura, arraste/Voltar/barreira e botão explícito de fechar. O fluxo pai do Finanças continua usando o seletor existente, preservando cancelamento, alternativa manual e criação de meio.

**79 testes distintos aprovados:** 68 de apresentação/fluxos do app e 11 de repository/bridge financeiro. A suíte de apresentação encontrou duas expectativas antigas que não rolavam até a ação Criar no Finanças; os testes foram corrigidos para navegar pelo conteúdo rolável e os quatro testes desse fluxo pai passaram novamente. O histórico real não modifica storage; cancelar fonte mantém saldos, usar fonte preserva metadados e criar meio continua integrado.

`flutter analyze --no-pub` sem problemas; sete arquivos formatados sem alterações pendentes de formato; `git diff --check` dos arquivos alterados nesta etapa aprovado. Sem mudanças necessárias em Data Connect ou rules nesta etapa.
