# Lixeira — implementação Flutter

Referência: `index.html` e `preview.png` desta pasta (Stitch, tela 24).

## Implementação

- `lib/src/presentation/trash_lists_page.dart`: tema Mercado Editorial local, Newsreader/Public Sans, fundo marfim e lista com divisórias; composição sem cartões ou gradientes.
- Contador, nomes, datas de exclusão e prazo calculados a partir das listas reais do store. Aviso de retenção de 30 dias. Prazo restante usa fração de dia completa, evitando exibir zero quando ainda restam minutos.
- Restaurar e excluir definitivamente mantêm os métodos existentes do store, confirmação, retorno pela navegação, haptics e mensagens atuais. Exclusão usa vermelho terroso e confirmação no tema editorial.
- Estado vazio, conteúdo longo, rolagem, modo escuro e texto ampliado. Ações de ao menos 48 dp; títulos não são truncados.
- `nowProvider` opcional permite relógio determinístico para apresentação/purge nos testes; produção segue o relógio atual.

## Compatibilidade com o app

O ícone ilustrativo “Esvaziar lixeira” do HTML não foi implementado: a tela original oferece exclusão definitiva por lista, sem ação em lote. Nenhum novo comportamento de exclusão ou informação fictícia foi criado. Também não foi introduzido desfazer onde não existia.

## Verificação

- `test/presentation/trash_redesign_test.dart`: 6 testes, todos aprovados; golden em 390×884, restauração persistente preservando itens, cancelar/confirmar exclusão definitiva, vazio e voltar, expiração após 30 dias e prazo inferior a uma hora, 320×568 escuro com escala de texto 1,5.
- Golden `test/presentation/goldens/trash_stitch_390.png` inspecionado visualmente.
- Regressão existente: 2 testes de retenção/restauração no store e 1 teste integrado “Trash shows a deleted list and restores it” aprovados.
- Análise estática dos arquivos alterados sem problemas. Regressão integrada a cargo da revisão principal.
