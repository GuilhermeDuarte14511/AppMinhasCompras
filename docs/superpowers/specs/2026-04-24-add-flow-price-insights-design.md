# Design: fluxo de adicao rapida com catalogo e insights de preco

Data: 2026-04-24
Status: proposta aprovada para revisao

## Objetivo

Melhorar o fluxo de adicionar produtos para que ele entregue tres beneficios juntos, sem quebrar o design atual do app:

1. ativacao inicial mais clara do valor do produto,
2. adicao rapida de multiplos itens,
3. insight imediato de economia ou aumento de preco ao editar um item vindo do catalogo.

O foco desta iteracao e a experiencia de adicionar item. Nesta proposta, "ativacao inicial" significa ajudar o usuario a perceber valor logo na primeira vez que tenta adicionar um produto, sem abrir um novo onboarding. A reposicao inteligente continua existindo, mas entra como segunda etapa de integracao sobre esse novo fluxo principal.

## Problema atual

Hoje o app ja possui:

- sugestoes por nome parcial no editor de item,
- preenchimento de dados vindos do catalogo local,
- historico de preco salvo no catalogo,
- suporte a adicionar varios itens em sequencia.

Mesmo assim, o fluxo ainda tem tres limitacoes perceptiveis:

- a busca por sugestoes nao se comporta como protagonista da tela,
- ao tocar em uma sugestao o preenchimento automatico nao fica claro como parte central da experiencia,
- o usuario nao recebe feedback comparativo quando altera o preco sugerido.

Na pratica, o app ja tem os dados, mas ainda nao transforma esses dados em decisao rapida durante a compra.

## Resultado esperado

Quando o usuario abrir o sheet de adicionar item e digitar algo como `to`:

- o app deve mostrar resultados relevantes do catalogo local por trecho digitado,
- ao tocar num resultado, o app deve preencher nome, codigo de barras e valor unitario,
- o usuario pode ajustar quantidade e preco normalmente,
- se o preco for alterado em relacao ao valor sugerido, aparece uma label explicando se o valor subiu, caiu ou se manteve,
- o fluxo de `Adicionar e continuar` continua rapido para montar varios itens de uma vez,
- se o item for preenchido manualmente e salvo, ele continua entrando automaticamente no catalogo como hoje.

## Fora de escopo nesta etapa

- mudar a linguagem visual geral do app,
- redesenhar onboarding completo,
- alterar o comportamento de sincronizacao ou Firestore,
- mudar a logica de persistencia do catalogo fora do necessario para o comparativo,
- adicionar CTA explicito de `Criar item "<texto digitado>"`,
- reposicao inteligente como tela inicial obrigatoria.

## Abordagem recomendada

Implementar um fluxo guiado por catalogo dentro do mesmo bottom sheet atual, preservando:

- `AppGradientScene`,
- componentes de formulario e chips ja usados no projeto,
- linguagem atual de botoes, sheets e feedbacks,
- estrutura atual de `Adicionar item` e `Adicionar e continuar`.

Em vez de criar uma nova tela, o editor existente sera fortalecido para que:

- a busca por catalogo seja o centro da interacao,
- as sugestoes fiquem mais informativas,
- a comparacao de preco apareca exatamente no momento em que o usuario altera o valor sugerido.

## Experiencia do usuario

### 1. Entrada no fluxo

O usuario continua entrando pelo mesmo CTA de adicionar item.

O bottom sheet continua com:

- scanner de codigo de barras,
- campo de codigo,
- campo de nome,
- categoria,
- quantidade,
- valor unitario,
- botoes de adicionar.

Para reforcar a ativacao inicial, o primeiro uso desse sheet deve comunicar melhor o valor do recurso. A orientacao textual do topo deve deixar claro que o usuario pode:

- digitar parte do nome para buscar no catalogo,
- tocar numa sugestao para preencher os dados,
- ajustar o valor e ver a comparacao de preco na hora.

Isso deve ser feito com microcopy e hierarquia visual no padrao atual do app, sem introduzir uma etapa nova obrigatoria.

### 2. Busca por nome parcial

Ao digitar no campo de nome:

- as sugestoes do catalogo devem aparecer de forma imediata,
- a busca deve funcionar por trecho contido no nome, nao apenas por nome completo,
- a lista de sugestoes deve priorizar itens do catalogo local e excluir nomes bloqueados na lista atual.

Visualmente, as sugestoes deixam de ser apenas `ActionChip` simples e passam a exibir contexto suficiente para tomada de decisao.

Cada sugestao deve mostrar:

- nome do produto,
- codigo de barras quando existir,
- ultimo preco salvo quando existir,
- microestado de preco, quando houver historico suficiente.

### 3. Toque na sugestao

Ao tocar em um produto sugerido:

- preencher nome com o valor padrao do catalogo,
- preencher codigo de barras do produto,
- preencher valor unitario com o ultimo preco salvo,
- aplicar categoria do catalogo,
- marcar internamente esse produto como referencia de comparacao.

Esse preenchimento deve acontecer de forma confiavel mesmo que o campo de codigo ja esteja vazio ou parcialmente editado. O objetivo e o toque na sugestao representar "usar este produto do catalogo".

### 4. Comparacao de preco

Depois que o produto do catalogo for aplicado, o campo de valor unitario passa a ser observado.

Se o usuario alterar o valor:

- mostrar uma label explicando a variacao em relacao ao valor base do catalogo,
- usar linguagem curta e direta,
- atualizar em tempo real sem exigir salvar.

Exemplos:

- `14% menor que o ultimo preco salvo`
- `9% maior que o ultimo preco salvo`
- `Mesmo preco da ultima compra`

Se nao houver historico suficiente, a label nao precisa aparecer. O app pode continuar exibindo apenas a dica de preco sugerido atual.

### 5. Adicao multipla

O fluxo atual de `Adicionar e continuar` sera mantido.

A melhora esperada e:

- o usuario digita,
- toca numa sugestao,
- ajusta quantidade e preco,
- ve a label de comparacao,
- adiciona o item a fila,
- segue para o proximo sem perder ritmo.

O preview de itens pendentes continua existindo.

### 6. Item manual sem sugestao

Se nenhuma sugestao for usada:

- o usuario preenche manualmente,
- salva normalmente,
- o item entra no catalogo automaticamente no fluxo ja existente.

Nao havera CTA separado para "criar item" a partir do texto digitado.

## Arquitetura e mudancas tecnicas

### Camada de apresentacao

Arquivo principal afetado:

- `lib/src/presentation/dialogs_and_sheets.dart`

Mudancas previstas:

- enriquecer a exibicao das sugestoes do campo de nome,
- tornar o toque na sugestao um preenchimento completo do formulario,
- introduzir estado derivado para comparacao de preco,
- exibir uma label de variacao abaixo do campo de valor quando houver produto-base selecionado,
- manter compatibilidade com modo simples e modo multiplo.

### Camada de aplicacao

Arquivo principal relacionado:

- `lib/src/application/store_and_services.dart`

Mudancas previstas:

- manter a busca por sugestoes por trecho, aproveitando a logica atual,
- se necessario, ajustar ordenacao e limites para melhorar relevancia,
- nao alterar contratos sem necessidade, a menos que a UI precise de dados mais ricos por sugestao.

### Camada de dominio

Arquivo principal relacionado:

- `lib/src/domain/models_and_utils.dart`

Mudancas previstas:

- provavelmente nao sera necessario mudar entidades persistidas,
- pode ser util introduzir um model auxiliar nao persistido para representar comparacao de preco na UI, caso isso deixe o codigo mais claro.

### Camada de dados

Arquivo principal relacionado:

- `lib/src/data/repositories/product_catalog_repository.dart`

Mudancas previstas:

- preservar a forma atual de gravacao do historico,
- garantir que o valor de referencia usado na comparacao venha do ultimo preco salvo do catalogo,
- evitar atualizar historico antes da confirmacao do salvamento.

## Regras de comparacao de preco

Referencia principal:

- usar o ultimo preco salvo do produto selecionado no catalogo.

Calculo:

- diferenca percentual = `(preco_digitado - preco_referencia) / preco_referencia * 100`.

Comportamento:

- se o produto nao veio do catalogo, nao mostrar label comparativa,
- se o preco de referencia for nulo ou menor/igual a zero, nao mostrar label comparativa,
- se a diferenca absoluta for desprezivel, mostrar estado neutro,
- a comparacao e apenas visual ate o usuario salvar.

## Reposicao inteligente na sequencia

Depois desta entrega, a segunda etapa sera aproximar a reposicao inteligente do fluxo de criacao de lista.

Direcao prevista:

- expor `Reposicao inteligente` como atalho mais forte ao criar lista,
- permitir partir de itens sugeridos e complementar com o mesmo editor melhorado,
- reutilizar a mesma label de comparacao de preco nos itens sugeridos.

Essa etapa nao entra agora para evitar acoplamento excessivo e manter a iteracao focada.

## Erros e estados especiais

- se a busca local nao encontrar produto, o formulario continua manualmente sem erro bloqueante,
- se o lookup por codigo falhar, manter mensagem leve e continuar fluxo manual,
- se o usuario editar o nome apos escolher uma sugestao, a referencia de comparacao deve ser invalidada quando deixar de representar aquele produto,
- se houver item duplicado na lista, a validacao existente deve continuar funcionando,
- se o usuario adicionar varios itens, sugestoes ja enfileiradas nao devem reaparecer como validas para a mesma lista.

## Testes

### Widget tests

Adicionar cobertura para:

- sugestao aparecer ao digitar trecho parcial como `to`,
- toque na sugestao preencher nome, codigo e preco,
- alterar o preco depois da sugestao mostrar label de `subiu`,
- alterar o preco depois da sugestao mostrar label de `caiu`,
- manter label neutra quando o preco for igual,
- fluxo de `Adicionar e continuar` com sugestao aplicada,
- item manual continuar sendo salvo e reutilizado pelo catalogo.

### Riscos

- regressao no editor de item por concentrar muita logica em um arquivo grande,
- conflito entre estado de lookup por codigo e lookup por nome,
- UX poluida caso a lista de sugestoes fique visualmente pesada demais,
- comparacao enganosa se a referencia mudar sem feedback claro.

## Decisoes finais registradas

- seguir o design atual do projeto, sem reinventar a linguagem visual,
- nao adicionar CTA de `Criar item "<texto>"`,
- usar o catalogo como fonte principal do preenchimento automatico,
- comparar o preco digitado contra o ultimo preco salvo do produto selecionado,
- mostrar a label de comparacao somente apos uma sugestao do catalogo ter sido escolhida,
- manter o fluxo de adicao multipla como parte central da experiencia.

## Plano de implementacao esperado

1. fortalecer o editor atual de item em vez de criar nova tela,
2. enriquecer sugestoes de catalogo e o comportamento de toque,
3. adicionar comparacao dinamica de preco no campo de valor,
4. cobrir o fluxo com widget tests,
5. em iteracao futura, aproximar reposicao inteligente da criacao de lista.
