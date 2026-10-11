# Abertura animada

- Stitch: `projects/15729736264095734439/screens/2fc3147881624839813529ae672ba58f`
- Projeto: https://stitch.withgoogle.com/projects/15729736264095734439
- HTML original com animação CSS: `index.html`.
- Flutter: `lib/src/presentation/launch.dart` e `splash/notebook_painter.dart`.
- Skill aplicada: `interaction-design`; testes com `flutter-add-widget-test`.

O caderno entra em 900 ms, abre a folha e desenha linhas/marcações em sequência até 1700 ms. Durante a inicialização, flutua discretamente em um ciclo de 4200 ms. O indicador é indeterminado: o desenho não representa etapas ou porcentagens de sincronização. A preferência de reduzir movimento mostra o desenho completo, sem flutuação.

O bootstrap exibe a cena antes da inicialização do Firebase. A apresentação inicial dura no mínimo 1700 ms, em paralelo com os serviços, exceto quando reduzir movimento está ativo. A abertura nativa usa o mesmo caderno vetorial e cores claras/escuras, com animação compatível com Android 12+.

Adaptações do HTML: textos decorativos 'Mercado Editorial', 'Edição Cotidiana' e 'Registro Local Seguro' não entram no app; o nome real, subtítulo e mensagem de carregamento são preservados. Não há novas funcionalidades ou afirmações de segurança.
