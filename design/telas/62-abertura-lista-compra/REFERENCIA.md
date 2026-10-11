# Splash — lista para compra

Referência Stitch: `projects/15729736264095734439/screens/7a1f49dd00be494c80b76b75f65965c1`.

Projeto: https://stitch.withgoogle.com/projects/15729736264095734439

Skill pesquisada na internet e aplicada: [Flutter Animations](https://github.com/MADTeacher/mad-agents-skills/tree/main/flutter-animations). Leitura de `SKILL.md` e `references/staggered.md`; sequência coordenada com um controlador, intervalos, descarte e preferência de movimento reduzido.

## Implementação

- `launch.dart`: símbolo de lista e sacola, título, mensagem real de carregamento e indicador indeterminado.
- `splash/notebook_painter.dart`: coordenadas vetoriais transportadas do SVG do Stitch, sem imagens de rede.
- `splash/splash_motion.dart`: sequência única de 1800 ms; lista, linhas, checkmarks e sacola. O símbolo fica estático após concluir.
- `main.dart`: abertura durante o bootstrap de Firebase e preferências. O tempo mínimo decorativo é dispensado com movimento reduzido.
- `web/index.html` e `web/splash.css`: abertura HTML antes do primeiro frame Flutter, removida pelo evento real `flutter-first-frame`.
- Recursos Android: emblema correspondente em versões claras e escuras, também antes do Flutter iniciar.

O desenho é decorativo. Não lê ou altera itens de compras e não representa porcentagens nem etapas da sincronização. Os dados existentes são preservados.

## Verificação

10 testes de carregamento, splash e recursos nativos passaram, incluindo comparação visual da nova composição. A referência visual foi inspecionada e o conjunto passou novamente sem atualização de goldens.

Análise Flutter sem problemas. Build web release publicado em 11/10/2026 no canal `redesign-teste-20261011`, na URL temporária existente. Navegador confirmou abertura animada, remoção do HTML no primeiro frame e chegada ao painel sincronizado.

APK release 1.0.1 (2007) instalado como atualização no Motorola Edge 50 Fusion; logs confirmaram inicialização e sincronização bem-sucedidas, sem erro fatal de abertura. A inspeção visual do Android fica a cargo do usuário, pois esta sessão não expõe a tela do aparelho.
