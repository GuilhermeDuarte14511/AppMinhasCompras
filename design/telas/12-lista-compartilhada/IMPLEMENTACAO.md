# Lista compartilhada no Flutter

Branch: `feat/redesign-login`. Referências: `index.html` e `preview.png`.

## Implementação e arquitetura

SharedListEditorPage mantém streams e operações do SharedListsRepository,
conversão ao modelo local, espelhamento, importação de catálogo, lembretes,
avisos de orçamento e fechamento existente. `SharedEditorialSummary` apresenta
contagem de membros, papel, orçamento existente, estimado, pego e progresso real.
Os detalhes expansíveis mantêm resumo, orçamento, saldos e lembrete.

CustomScrollView permite rolar resumo, busca, filtros e itens juntos. As linhas
são construídas sob demanda e limitadas a 600 dp. Adicionar item fica no rodapé
com área segura; Fechar compra chama o mesmo fechamento já usado pelo menu.
As linhas preservam checkbox, quantidade, subtotal, edição e exclusão.

O provedor opcional de UID permite testar a apresentação com autenticação
injetada; o padrão continua lendo FirebaseAuth.instance.currentUser. Não houve
alteração do repository, das regras do Firestore ou dos contratos de gravação.

## Funcionalidades preservadas

- Busca pelo nome e filtros Pendentes, Todos e Comprados com contagens reais.
- Aumentar/diminuir quantidade, marcar comprado, editar e excluir pelo repository.
- Aviso de itens comprados ocultos e atalho para visualizar esses itens.
- Orçamento, saldos e lembrete nos detalhes expansíveis.
- Renomear, compartilhar para o dono, histórico, importação ao catálogo,
  fechamento e reabertura pelos callbacks existentes.
- Lista fechada mantém ações de gravação desabilitadas; reabertura permanece no menu.
- Loading, lista sem acesso, lista vazia e busca sem resultados possuem estados reais.

Não foram adicionados modo de compra separado, nomes/fotos de membros nem um
estado de sincronização que o app não informa. Código continua no fluxo de
convite existente. Não são usados valores ou contagens ilustrativos do HTML.

## Verificação

`shared_redesign_test.dart` usa streams e repository de teste para verificar
quantidade e comprado, filtros/busca, modo fechado e reabertura, opções de
orçamento/saldos/lembrete e abertura do formulário real. Inclui 320 × 568 dp,
tema escuro e texto ampliado a 1,5×. O estado vazio passou a ser um sliver
rolável para evitar overflow com o teclado aberto.

Captura: `test/presentation/goldens/shared_editor_stitch_390.png`.

Regressão desta etapa: 92 testes distintos aprovados; análise estática sem problemas.
