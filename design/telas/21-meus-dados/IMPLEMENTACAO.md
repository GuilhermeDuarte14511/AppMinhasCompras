# Implementação — Meus dados

Referência: `index.html` e `preview.png` da tela 21 do Stitch.

## Interface

- Ficha editorial com superfície marfim, título Newsreader, textos Public Sans e ação verde.
- Avatar, URL opcional, nome e e-mail em formulário aberto com divisórias discretas.
- Salvar alterações fixo no rodapé; formulário rolável e largura máxima de 600 px.
- Cores adaptadas ao tema escuro e controles acessíveis com texto ampliado e teclado aberto.

## Funcionalidades preservadas

- Nome validado com mínimo de 2 e máximo de 80 caracteres.
- Foto da galeria, upload no Firebase Storage, prévia por URL e remoção da foto.
- Atualização no Firebase Auth, persistência do perfil no Firestore e retorno à tela anterior com o resultado.
- Estados de upload e gravação, mensagens existentes de erro e sucesso e limpeza da foto anterior no Storage.
- E-mail permanece somente leitura. O HTML ilustrativo sugeria edição, mas o app não possui esse fluxo.
- Escolher foto permanece disponível, mesmo ausente no HTML ilustrativo, porque já fazia parte do app.
- Nenhum dado ilustrativo do Stitch foi introduzido no aplicativo.

## Verificação

5 testes em `test/presentation/profile_redesign_test.dart`:

- Captura editorial de 390 × 884 px: `test/presentation/goldens/profile_stitch_390.png`.
- Validação dos limites de nome antes de chamar o Firebase.
- Remoção da URL da foto e disponibilidade do botão.
- Layout de 320 × 568 px, tema escuro, escala de texto 1,5 e teclado aberto; a posição do botão é verificada acima do limite do teclado.
- E-mail somente leitura e navegação de retorno.

A captura foi inspecionada visualmente. Upload da galeria e persistência Firebase utilizam a implementação existente; estes testes não executam serviços remotos nem galeria real.
