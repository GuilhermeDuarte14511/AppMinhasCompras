# Implementação — Opções

Referência: `index.html` e `preview.png` exportados do Stitch para a tela 20.

## Visual

- Superfície editorial marfim, título Newsreader e corpo Public Sans locais.
- Seções Conta, Aparência, Sincronização, Catálogo, Integrações e Ajuda e Guia organizadas por linhas e divisórias.
- Perfil e saída como ações de lista; seleção Claro/Escuro em controle compacto.
- Estado de sincronização em linhas com registros reais, data real e feedback de operação; sem cartões decorativos ou anéis de progresso.
- Área limitada a 600 px, rolagem vertical e adaptação ao modo escuro e texto ampliado.

## Funcionalidades preservadas

- `Meus dados` abre o editor existente e mantém resultado/atualização de perfil.
- `Deslogar` mantém callback original e bloqueio durante operação.
- Tema e importação de catálogo conservam callbacks e valores reais.
- Diagnóstico aparece somente quando snapshot e callback de sincronização existem.
- Minhas Finanças abre a integração existente; não apresenta `(Conectado)` sem informação real.
- Rever Onboarding fecha Opções e chama o fluxo existente.
- Offline, pendências, envio e sincronização concluída derivam das flags fornecidas pelo app. Nenhuma data ou contador foi inventado.

A tela salva inclui timestamp relativo e conexão financeira ilustrativos. A implementação usa a data disponível no app e omite o status financeiro sem fonte. Métricas de nuvem existentes continuam disponíveis, mesmo aumentando a altura da seção em relação à ilustração. Sistema é exibido apenas quando já recebido como preferência, evitando uma seleção inválida.

## Verificação

- `test/presentation/options_redesign_test.dart`: 6 testes aprovados.
- Golden 390 × 884: `test/presentation/goldens/options_stitch_390.png`.
- Cobertura de tema, catálogo, saída pendente, estados de sincronização, retorno ao onboarding e layout 320 × 568 com texto 1,5× no escuro.
- Captura visual inspecionada; análise global e regressão realizadas na integração das duas telas.
