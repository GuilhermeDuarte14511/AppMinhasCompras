# Mercado Editorial

<!-- impeccable:design-schema 1 -->

## Direção

Modo **Operate**. A compra é apresentada como uma lista bem composta, com a precisão de uma etiqueta de preço e o ritmo de um caderno de mercado contemporâneo. O primeiro olhar deve mostrar o que falta comprar, quanto custa e a próxima ação.

**Tese visual:** superfícies calmas, tipografia de publicação e uma coluna de operação direta, com a energia concentrada na marcação de itens e no fechamento.

**Plano de conteúdo:** contexto da lista e total; itens e filtros; orçamento, saldos e histórico quando relevantes; ação principal no fim ou ao alcance do polegar. Telas de formulário começam pelo campo necessário, sem abertura promocional.

**Tese de interação:** marcar um item atualiza progresso e valores com transição curta; abrir detalhes preserva a posição da lista; sheets entram com movimento discreto e respeitam a preferência de reduzir animações.

## Sistema

- Fundo marfim `#F7F5EF`, superfície `#FFFEFA`, texto carvão `#252923`, secundário `#62695F`, divisória `#D9DCD3`.
- Verde folha `#365943` para ações e seleção. Vermelho terroso `#A44438` apenas para erros, excesso e exclusão.
- Newsreader em títulos e Public Sans em conteúdo e controles. Valores usam algarismos tabulares.
- Escala de espaçamento em 4 px; controles com pelo menos 48 dp. Raios discretos de 6–12 dp.
- Layout em linhas e seções com divisores. Cartão somente quando o bloco inteiro é uma ação. Sem gradientes decorativos, brilho, sombras amplas e grade de métricas.
- Modo escuro com fundo carvão e acento verde claro mantém o mesmo contraste e hierarquia.
- Material 3 preserva navegação, diálogos, sheets, foco, gestos e áreas seguras. Movimento breve sinaliza mudança de estado e respeita redução de animações.

## Padrões por tela

- Início: listas recentes e ações diretas primeiro; resumos compactos e reposição em seguida.
- Listas: busca e filtros no topo, linhas com estado e valores; criação persistente.
- Lista/mercado: título, total e progresso, filtros, itens com checkbox e preços alinhados; ação principal no alcance do polegar.
- Produto: nome, preço atual, análise de preço e histórico; sem dados de loja ou localização.
- Histórico/fechamento: valores e itens com rótulos explícitos, confirmação antes de gravar.
- Configuração e conta: grupos de linhas, formulários simples e estados de sincronização textuais.

## Fonte de verdade

`PRODUCT.md`, `README.md` e implementações de `lib/src/presentation`. As telas no Stitch devem corresponder aos campos e ações existentes; valores ilustrativos não representam dados do usuário. Projeto Stitch: `projects/15729736264095734439`, sistema `assets/8416557048808320397`.
