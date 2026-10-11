# 32 — Atualizar preço unitário

## Implementação

`lib/src/presentation/dialogs/sheets/item_unit_price_sheet.dart` aplica o tema Mercado Editorial apenas ao modal. Mantém a API `showItemUnitPriceSheet`, nome e preço recebidos pelo chamador, máscara BRL, autofocus, teclado decimal, conclusão pelo IME, chave `market_price_field` e validação de valor finito maior que zero.

Título Newsreader, nome real em superfície discreta, campo Public Sans com algarismos tabulares e borda de 8 dp, modal de 12 dp e ações de pelo menos 48 dp. Conteúdo rolável; confirmação e cancelamento permanecem acima do teclado. Mesma implementação utilizada no mercado e na revisão dos rascunhos.

## Decisões sobre o Stitch

- **Fechar:** incluído por facilitar o retorno sem alterar o preço; devolve `null`, como Cancelar e a navegação nativa.
- **Nome do item:** somente leitura; utiliza o argumento existente, sem criar edição de nome neste fluxo.
- **Explicação do subtotal:** ajuda contextual sobre um cálculo já existente (`quantidade × preço unitário`); não adiciona novo cálculo nem unidade de medida desconhecida.
- **Item da lista:** rótulo decorativo omitido, pois o título e o nome já orientam o usuário.
- **Preço ilustrativo:** substituído pelo valor real do chamador, sem preço anterior, estoque, precisão ou comparação inventados.

## Verificação

5 testes novos: golden de 390 × 844, retorno do preço BRL, envio pelo IME e validação de vazio/zero/não finito, Fechar/Cancelar retornando null e 320 × 568 em modo escuro com texto 1,5 e teclado de 210 dp (ambas as ações acima de 358 dp).

18 regressões de revisão e mercado aprovadas, incluindo edição sem marcar o item como comprado, cancelamento preservando dados e revisão aninhada. Golden: `test/presentation/goldens/unit_price_stitch_390.png`.
