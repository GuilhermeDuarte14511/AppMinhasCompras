# Produto

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Pessoas que planejam compras domésticas, compram no mercado e, em alguns casos, compartilham listas e pagamentos com outra pessoa.

## Product Purpose

Criar, acompanhar e fechar listas de compras com itens, quantidades, preços, orçamento e histórico. Apoiar a compra em tempo real e a reposição de produtos da despensa.

## Operating Context

O app Flutter roda em Android e Web. A pessoa pode preparar a lista em casa, usá-la com uma mão no mercado, revisar o valor pago no fechamento e consultar compras anteriores. Há operação local e sincronização em nuvem para a conta e listas compartilhadas.

## Capabilities and Constraints

- Listas pessoais: criar, editar, duplicar, filtrar, buscar, fechar, reabrir, excluir e recuperar da lixeira.
- Itens: nome, categoria, quantidade, preço, código de barras, status comprado, histórico de preço; adicionar manualmente, por voz, código ou cupom fiscal.
- Modo compra com progresso, marcação rápida e ajuste de quantidade.
- Orçamento, saldos e divisão de pagamento; integração opcional com Minhas Finanças.
- Listas compartilhadas com convites por código, membros e sincronização.
- Catálogo, despensa com estados de reposição, histórico mensal e detalhes de fechamentos.
- Conta, tema claro/escuro, backup, diagnóstico de sincronização e onboarding.
- Preservar as informações, ações e regras existentes no redesign. Alterações locais já presentes no repositório pertencem ao usuário.
- Priorizar as funcionalidades existentes. Recursos adicionais presentes no Stitch podem ser implementados quando sua utilidade justificar o impacto no fluxo, usando dados reais e registrando a decisão na documentação da tela.
- Quando uma melhoria funcional do Stitch for justificada, integrar também as mudanças necessárias em modelos, persistência, Data Connect ou regras de acesso existentes no projeto. Avaliar o fluxo completo e documentar a diferença funcional e seu impacto.

## Brand Commitments

O nome exibido no app é “Minhas Compras”. O usuário autorizou substituir toda a aparência, preservando nome, conteúdo e funcionalidade.

## Evidence on Hand

Código Flutter em `lib/src/presentation` e composição em `lib/src/app/shopping_list_app.dart`; inventário funcional em `README.md`. A interface atual usa Material 3, Nunito Sans e Rubik, teal e laranja e superfícies com gradientes e cartões.

## Product Principles

- A próxima ação deve ser evidente sem esconder os detalhes da compra.
- Valores, quantidades e estados precisam ser lidos rapidamente no mercado.
- Recursos avançados permanecem acessíveis sem dominar o fluxo principal.
- A mesma lista deve fazer sentido para uso individual e compartilhado.

