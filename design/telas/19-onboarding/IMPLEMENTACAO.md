# Onboarding no Flutter

Branch: `feat/redesign-login`.

Referência visual: HTML desta pasta, tela Stitch
`projects/15729736264095734439/screens/f0499e19f0ab4159b476bf7a2db63ff5`.

## Implementação

`lib/src/presentation/onboarding_page.dart` mantém três etapas com PageView,
navegação por gesto e botão, pular e conclusão através dos callbacks existentes.
O estado de gravação bloqueia ações repetidas e gestos até concluir o callback.
O retorno visual às etapas anteriores usa o mesmo PageController.

`lib/src/presentation/onboarding/onboarding_styles.dart` reúne as cores,
tipografia e estilo dos controles do Stitch, incluindo a escolha claro/escuro.
Fontes e Material Symbols são assets locais. O conteúdo de cada etapa pode
rolar, enquanto o cabeçalho e as ações permanecem acessíveis.

## Compatibilidade com o app atual

O mockup concentra conteúdos e ações em uma imagem. A implementação preserva
os três passos, títulos, descrições e os nove tópicos anteriores do app:
listas e totais/histórico; catálogo, scanner e cupom; funcionamento offline,
lembretes e tema. O visual dos tópicos usa os blocos compactos da referência.

Tema e conclusão permanecem na terceira etapa; Pular aparece nas duas primeiras.
Concluir envia `createFirstList: false`; Concluir e Criar Lista envia `true`.
A persistência local/remota e a criação da primeira lista continuam na camada
do app, sem mudanças. Nenhuma nova informação de usuário é exigida.

## Verificação

`test/presentation/onboarding_page_test.dart`: oito testes para conteúdo,
navegação, gestos, pular, as duas formas de conclusão, tema, bloqueio durante
gravação, comparação visual e tela pequena em modo escuro com texto ampliado.

Capturas Flutter:

- `test/presentation/goldens/onboarding_first_stitch_390.png`
- `test/presentation/goldens/onboarding_last_stitch_390.png`

```sh
flutter test --no-pub test/presentation/auth_page_test.dart test/presentation/create_account_page_test.dart test/presentation/onboarding_page_test.dart
flutter analyze --no-pub
```
