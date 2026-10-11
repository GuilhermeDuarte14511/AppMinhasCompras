# Inventário de telas e ações existentes

Este mapa foi conferido contra `lib/src/presentation` e os fluxos do app. Cada número corresponde à imagem em [Stitch](stitch/README.md). Os layouts usam valores de exemplo apenas para mostrar hierarquia; campos, estados e ações são os do aplicativo.

| Nº | Tela | Informações e ações existentes |
|---|---|---|
| 01 | Início | Resumo das listas, listas recentes, atalhos para listas, catálogo, despensa e histórico, sugestão de reposição baseada no histórico. |
| 02 | Minhas listas | Buscar, filtrar e selecionar listas; criar, abrir, duplicar, excluir e desfazer exclusão. |
| 03 | Lista detalhada | Nome, orçamento, progresso e itens; adicionar, editar, marcar, ajustar quantidade, usar modo compra, compartilhar, fechar e configurar lembrete. |
| 04 | Modo compra | Buscar ou filtrar pendentes, marcar item com toque ou gesto, ajustar quantidade e preço, ver progresso e valor pendente. |
| 05 | Novo item | Nome, categoria, quantidade, unidade, preço, código de barras e consulta ao catálogo; adicionar e continuar. |
| 06 | Catálogo | Buscar e filtrar produtos cadastrados; abrir detalhes e usar produto em lista ou despensa. |
| 07 | Detalhe do produto | Dados cadastrados, preço e histórico disponíveis; editar e usar o produto nos fluxos atuais. |
| 08 | Despensa | Buscar, filtrar por estado, mudar estado, adicionar produto do catálogo ou à lista, remover. |
| 09 | Histórico de compras | Consultar compras por período e abrir o detalhe de um fechamento. |
| 10 | Detalhe da compra fechada | Ver itens, quantidades, valores e dados registrados no fechamento. |
| 11 | Listas compartilhadas | Ver e abrir listas compartilhadas, entrar por convite e acessar convites. |
| 12 | Lista compartilhada | Consultar membros e itens, adicionar ou editar, marcar, ajustar quantidade e acompanhar totais. |
| 13 | Convidar para lista | Usar o código de convite do fluxo compartilhado. |
| 14 | Fechamento de compra | Revisar itens e valores, escolher pagamento, concluir e gravar no histórico. |
| 15 | Importar cupom fiscal | Capturar ou selecionar cupom, revisar itens reconhecidos e importar os itens confirmados. |
| 16 | Adicionar por voz | Gravar fala, revisar itens reconhecidos e confirmar inclusão. |
| 17 | Entrar | Login com e-mail e senha ou Google; mostrar/ocultar senha, recuperar senha e criar conta. |
| 18 | Criar conta | Cadastro da conta existente. |
| 19 | Onboarding | Apresentação do uso das listas e continuação para criar a primeira lista. |
| 20 | Opções | Acessar conta, preferências, backup, sincronização, integração financeira e lixeira. |
| 21 | Meus dados | Ver e editar dados de perfil disponíveis. |
| 22 | Minhas Finanças | Configurar e acompanhar a integração financeira opcional. |
| 23 | Sincronização e diagnóstico | Ver estado e detalhes de sincronização da conta e listas compartilhadas. |
| 24 | Lixeira | Ver listas excluídas e restaurar. |
| 25 | Selecionar meio de pagamento | Escolher uma fonte de pagamento disponível no fluxo de fechamento. |
| 26 | Abertura | Mostrar a marca enquanto os dados iniciais carregam. |
| 27 | Leitor de código | Ler código pela câmera ou digitá-lo manualmente. |
| 28 | Reposição inteligente | Revisar sugestões de itens recorrentes e criar uma lista com os selecionados. |
| 29 | Dividir pagamento | Distribuir o valor da compra entre meios de pagamento e confirmar a divisão. |
| 30 | Revisar itens pendentes | Revisar rascunhos pendentes antes de concluir o fechamento. |
| 31 | Compra concluída | Mostrar o resultado do fechamento e o estado da integração financeira quando aplicável. |
| 32 | Atualizar preço unitário | Editar o preço de um item no modo compra. |
| 33 | Histórico compartilhado | Consultar compras registradas na lista compartilhada. |
| 34 | Nome da lista | Criar ou renomear uma lista. |
| 35 | Orçamento da lista | Definir ou alterar o orçamento de uma lista. |
| 36 | Saldos de pagamento | Ver, ordenar, editar e excluir saldos usados no pagamento. |
| 37 | Lembrete da lista | Definir ou alterar um lembrete. |
| 38 | Usar lista como modelo | Escolher uma lista existente para servir de modelo. |

| 39 | Fechamento: valor final | Ajustar o total pago sem mudar os preços dos itens; confirmar o fechamento. |
| 40 | Cupom fiscal: revisão | Selecionar e corrigir itens reconhecidos, relacioná-los à lista e conferir totais. |
| 41 | Voz: captura | Ouvir ou digitar a frase e analisar os itens reconhecidos. |
| 42 | Voz: revisão | Selecionar e editar os produtos reconhecidos antes de adicioná-los. |
| 43 | Fechamento: itens pendentes | Revisar item pendente e decidir se entra no fechamento. |
| 44 | Fechamento: Finanças | Ativar lançamento financeiro e escolher meio de pagamento quando há integração. |
| 45 | Corrigir item no fechamento | Corrigir quantidade, preço unitário e estado comprado. |
| 46 | Opções: online | Ver conta, tema, sincronização, catálogo compartilhado, integração e ajuda com nuvem disponível. |
| 47 | Opções: offline escuro | Consultar pendências de sincronização em modo offline com tema escuro. |
| 48 | Leitor: câmera bloqueada | Ler instrução de permissão, tentar reabrir a câmera ou voltar à digitação manual. |
| 49 | Cupom fiscal: captura | Colar texto ou escolher/fotografar cupom; editar texto e iniciar revisão. |
| 50 | Novo saldo | Informar nome, tipo e saldo disponível de um meio de pagamento. |
| 51 | Minhas Finanças: conectar | Informar o código temporário de conexão gerado no app de Finanças. |
| 52 | Compra salva: envio pendente | Confirmar compra salva e informar pendência do envio financeiro. |
| 53 | Cupom fiscal: fechar na revisão | Na revisão, ativar fechamento e confirmar a compra importada. |
| 54 | Fechamento: pagamento e categoria | Selecionar meio e categoria disponíveis e ler o impacto financeiro. |

| 55 | Ações da lista | Abrir as ações disponíveis da lista pessoal conforme seu estado. |
| 56 | Ações do item | Editar, duplicar ou iniciar exclusão do item. |
| 57 | Excluir item | Confirmar ou cancelar a remoção de um item da lista. |
| 58 | Histórico de preços do item | Consultar registros de preço do item em ordem recente, com diferença em reais. |
| 59 | Adicionar saldo do Finanças | Escolher fonte sincronizada e valor reservado, criar fonte no Finanças ou usar entrada manual. |
| 60 | Novo meio no Finanças | Criar fonte de pagamento com campos condicionais ao tipo selecionado. |

As condições de conta, compartilhamento, pagamento e integração continuam controladas pelo estado real do app. Uma imagem isolada representa apenas um desses estados.
