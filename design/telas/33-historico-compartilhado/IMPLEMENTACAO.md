# Implementação — Histórico compartilhado

## Visual e arquitetura

Tela 33 do Stitch aplicada ao widget existente `SharedHistorySheet` com tema Mercado Editorial local: cabeçalho serifado, divisórias, agrupamento mensal, linhas de compras e rodapé fixo. Wrapper real `_openSharedHistory` usa sheet expansível, área segura e raio 12. Altura respeita as constraints disponíveis; conteúdo rola enquanto o botão Fechar permanece acessível.

`SharedHistorySheet` mantém uma assinatura de `repository.watchSharedHistory(list.id)` enquanto a lista/repositório não muda. Recebe atualizações reais, ordena uma cópia por data decrescente e conserva agrupamento mensal. Datas em português independem de inicialização externa do Intl. Sem mudanças no repositório, persistência ou modelo.

## Funcionalidades e decisões

- Mantidos nome da lista, datas, quantidade de produtos, valor pago (`spentValue`), todos os itens com quantidade/preço e saldos utilizados (`paymentUsage`). O total pago pode diferir da soma dos itens devido ao valor final informado no fechamento.
- Adicionada expansão inline de detalhes: benefício alto para consulta rápida sem sobreposição de outro modal. A compra mais recente começa expandida; o usuário pode recolher ou expandir cada compra. `SharedHistoryDetailsSheet` público permanece disponível para uso separado, compartilhando o mesmo conteúdo.
- Adicionados subtotal calculado de cada item e contagem real de registros. Ambos usam dados já disponíveis; não exigem novos serviços.
- Adicionados Fechar no cabeçalho e rodapé, com alvos de pelo menos 48 dp.
- Carregamento e falha do stream agora têm estados próprios; falhas antes apareciam como histórico vazio. Recuperação do stream atualiza a tela; fechar e reabrir reassina a consulta.
- Não foram adicionadas unidades kg/pct/un do mockup: o modelo não possui unidade comercial. Quantidade × preço e subtotal apresentam apenas informações reais. Texto do mockup sobre valores “conferidos” foi omitido por não haver verificação de valores nesse fluxo.

## Verificação

Seis testes de widget cobrem golden 390 × 844, carregamento/falha/vazio/recuperação, ordenação sem mutação do stream, expansão/fechamento, preços/subtotais/total final e utilização de saldos, API de detalhes isolada e 320 × 568 em tema escuro com texto ampliado 1,5×. Fontes locais reais carregadas no golden. Análise estática focada e diff conferidos.
