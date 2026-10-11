# Varredura da prévia web — 11/10/2026

Prévia: https://minhascompras-3abbe--redesign-teste-20261011-5jpv1myh.web.app/

## Fluxos verificados com a conta de teste

- Autenticação por e-mail e senha, encerramento da sessão e novo login. Cadastro: abertura e validação de campos vazios. Recuperação: validação de e-mail inválido. O botão Google está presente; o OAuth externo não foi concluído.
- Painel, atalhos, resumo, listas recentes e estado de sincronização.
- Catálogo: busca, filtro de categoria, seleção em lote, detalhes, histórico de preço e formulários de cadastro/edição. Leitor de código abriu e a alternativa manual retornou ao formulário.
- Despensa: estado vazio, inclusão a partir do catálogo, mudança de estado, envio à lista e remoção da entrada criada para teste. A quantidade da lista preexistente foi restaurada ao valor anterior.
- Lista de teste: criação, inclusão de item, orçamento, modo compra, marcação como pego, saldos de pagamento, revisão e fechamento. A compra apareceu no histórico e no painel após novo login.
- Histórico: estado vazio inicial, agrupamento mensal após a compra, resumo e detalhe do fechamento.
- Compartilhamento: tela do convite, geração e revogação do código da lista de teste, visão compartilhada como proprietário. Entrada por código inválido exibiu erro.
- Minhas listas: filtros, seleção múltipla, escolha de modelo, exclusão recuperável e restauração pela lixeira. A lista `TESTE QA - edição e lixeira` voltou com seu item e duas unidades, total R$ 33,96.
- Edição: quantidade alterada de uma para duas unidades e salva. Lembrete: ativação no formulário, abertura do calendário e cancelamento sem salvar. Fechamento: inclusão de pendentes, validação de valor final zero, ajuste para R$ 30,00 e cancelamento preservando o total original R$ 33,96 e o item pendente.
- Voz: alternativa digitada, análise de itens e tela de revisão/edição. Importação fiscal: texto fictício reconhecido e revisão aberta sem aplicar à lista existente.
- Opções: perfil, tema claro e retorno ao tema escuro, diagnóstico, sincronização manual, integração Finanças desconectada e onboarding.

## Ajustes feitos durante o teste

- Corrigidas duas mensagens com acentuação quebrada na tela de diagnóstico.
- Corrigida a flexão de contagens de um item, produto, resultado e pendência em telas afetadas, incluindo os indicadores de lista fechada, despensa e progresso no painel.
- O histórico deixa de exibir falha de consulta ao Finanças quando a compra não tem lançamento financeiro.
- A análise por voz aceita quantidade após o nome (por exemplo, `Arroz 2`) e preserva nomes com tamanho/tipo explícito. `Leite` agora exige revisão antes de associar automaticamente `leite condensado` do catálogo.
- Testes de interface antigos foram atualizados para os controles e textos presentes no redesenho. Referências visuais afetadas pelas correções foram atualizadas.

## Limites do teste manual

- Câmera, microfone e upload de foto dependem de permissões/dispositivos que não foram concedidos nesta sessão. As rotas, mensagens e alternativas digitadas foram verificadas.
- A integração com Minhas Finanças está desconectada e não havia código de conexão disponível; o envio financeiro real e os saldos sincronizados não foram testados.
- Não havia uma segunda conta para aceitar convite e validar colaboração entre usuários.
- A compra de teste permanece identificada como `TESTE QA - fluxo completo 11-10`. Ela gerou uma lista fechada, um registro no histórico, um produto no catálogo, uma entrada na despensa e uma lista compartilhada de proprietário. O código de convite foi revogado. A remoção do histórico não foi executada porque é permanente.
- A lista adicional `TESTE QA - edição e lixeira` permanece aberta após a restauração, com um produto existente e duas unidades. Não foi fechado outro histórico de compra.

## Validação automatizada

### Correção de quantidade por extenso

Em 11/10/2026, foi corrigida a extração de quantidade após o nome do produto: `ARROZ CAMIL DUAS UNIDADES` agora equivale a `Arroz Camil 2 Unidades`. Quantidades por extenso nessa posição exigem o rótulo unidade/unidades para preservar nomes como `arroz tipo dois` e tamanhos como `cinco quilos`. Testes cobrem também três, vinte e duas e trinta unidades.

Suíte completa: 613 testes aprovados; análise Flutter sem problemas. Publicação atualizada no mesmo canal temporário. Pela interface publicada, a frase por extenso selecionou o arroz Camil do catálogo com 2 unidades, sem efetivar a inclusão de teste. APK release build 2008 instalado no Moto Edge 50 Fusion.

A suíte completa `flutter test --no-pub` passou com 611 testes. Após o último ajuste de contagens no painel, os cinco testes de `dashboard_content_test.dart` passaram novamente. `flutter analyze --no-pub` terminou sem problemas. O build web release e a publicação usam o mesmo canal temporário.

### Correspondência e sugestões de arroz/Penne

Verificados os produtos reais da conta: arroz Camil e macarrão Penne Dona Benta. A frase digitada no fluxo de voz `arroz duas unidades, macarrão PENNE duas unidades` encontrou ambos com quantidade 2. Selecionar o Penne em `Correspondência no catálogo` preservou as duas unidades e deixou o seletor disponível. Não foi efetivada a inclusão dos produtos na lista.

Corrigido também o caso em que o catálogo contém `Penne Barilla 500g` sem a palavra genérica `macarrão`: a correspondência parcial agora aparece como sugestão que exige escolha. Formatos de massa explicitamente falados precisam coincidir, evitando sugerir espaguete para Penne. O seletor passou a permanecer visível também após matches seguros e seleção manual, sempre que houver candidatos do catálogo.

Testes cobrem arroz com múltiplas variantes, maiúsculas/acentos, Penne com e sem a palavra macarrão, ausência de produto no catálogo e seleção real do dropdown preservando quantidade/preço. Suíte completa: 617 testes aprovados. Análise Flutter sem problemas. Build web release 2009 publicado no mesmo canal temporário e APK release 1.0.1 (2009) instalado e iniciado no Moto Edge 50 Fusion, com versão confirmada via ADB.

Evidência: `design/voz-arroz-penne-sugestoes-validada.png`. A verificação manual usou texto no fluxo de voz; não simula a precisão acústica do reconhecimento por microfone.

### Correção dos CRUDs e exclusões que reapareciam — build 2010

O armazenamento utilizado por esses registros é Firestore. A sincronização substituía alterações locais por cópias antigas da nuvem, espelhos compartilhados podiam recriar listas apagadas e o carregamento das listas podia repovoar produtos excluídos do catálogo.

Foi implementada sincronização por alterações de entidades, com operações persistidas na fila local e reaplicadas antes de importar dados remotos. Alterações de configurações são enviadas por propriedade. Registros de outros dispositivos não são apagados por estarem ausentes da cópia local. Datas de atualização são preservadas e versões remotas mais recentes são protegidas.

Exclusões definitivas agora geram marcadores persistentes no dispositivo e no Firestore. As regras publicadas impedem que clientes antigos recriem os IDs apagados ou removam esses marcadores. Espelhos de listas compartilhadas respeitam a exclusão e a versão local mais recente. Um catálogo explicitamente vazio permanece vazio após importação, sem recriação a partir das listas.

Validações:

- Suíte Flutter completa: 644 testes aprovados; análise estática sem problemas.
- Regras Firestore nos emuladores: 86 verificações aprovadas, incluindo isolamento por usuário e bloqueio de recriação após exclusão.
- Repositório real com FlutterFire nos emuladores: 24 verificações aprovadas para listas, histórico, catálogo e despensa, cobrindo criação, leitura, edição, exclusão persistente e tentativa de recriação por versão antiga.
- Na URL publicada: criada a lista vazia `TESTE QA CRUD 2010`, renomeada para `TESTE QA CRUD 2010 EDITADA`, recarregada para confirmar a edição, movida à lixeira e excluída definitivamente com autorização específica do usuário. Depois de recarregar e sincronizar novamente, a lixeira permaneceu vazia e as três listas anteriores permaneceram disponíveis.

Build web release 2010 publicado no mesmo canal temporário; regras Firestore publicadas no projeto. APK release 1.0.1 (2010) instalado e iniciado no Moto Edge 50 Fusion, com versão confirmada via ADB. Nenhuma lista anterior foi excluída durante esta validação final.

Evidências: `design/crud-firebase-sdk-validado.png` e `design/crud-exclusao-definitiva-validada.png`. A validação entre usuários em produção e a integração financeira continuam com os limites descritos acima; os testes automatizados de autorização ocorreram nos emuladores.

### Sincronização demorada após exclusões no Moto — build 2013

O relato foi confirmado no Moto por captura da tela e logs. No build 2010, uma execução do envio permaneceu ativa de 14:53:49 a 14:56:22: aproximadamente 153 segundos. O envio acabou concluindo. Consulta somente de leitura no Firestore da conta indicada confirmou cinco marcadores de exclusão de listas e dez listas restantes. Não foram feitas exclusões adicionais na conta pessoal durante esta investigação.

A fila enviava cada operação e cada registro sequencialmente. Foram implementados: compactação das operações capturadas (última atualização por ID, exclusões permanentes prevalecem e configurações mescladas por propriedade), exclusões em lotes atômicos de até 200 registros/400 escritas, e atualizações independentes em grupos de até oito transações. Cada escrita tem limite de espera de 45 segundos; falhas preservam a fila para repetição. O timeout é tratado como indisponibilidade temporária e encerra o indicador de envio ativo.

Uma segunda causa foi reproduzida por teste: a importação do histórico substituía os IDs de todos os seus itens, criando alterações novas em cada abertura. Importações que substituem o snapshot agora preservam esses IDs. A importação que acrescenta cópias continua regenerando IDs conforme a política anterior.

Validação final: 666 testes Flutter aprovados e análise estática sem problemas. Inclui exclusão atômica, falha sem perda do registro, 260 exclusões respeitando o limite de lote, compactação equivalente ao replay, concorrência limitada, escrita travada e estabilidade dos IDs do histórico.

APK release 1.0.1 (2013) instalado no Moto Edge 50 Fusion e versão confirmada via ADB. Ao reabrir a conta indicada, os logs registraram início da hidratação às 15:05:50.101 e sincronização concluída às 15:05:54.997, sem operações de entidades artificialmente geradas pela importação. A tela exibiu a nuvem com confirmação. Este tempo refere-se à reabertura após a fila anterior terminar; não é uma repetição das mesmas cinco exclusões nem um benchmark de fila grande.

Os dados remotos permaneceram com 10 listas, 14 registros no histórico, 267 produtos no catálogo, 122 itens na despensa e cinco marcadores de exclusão. A URL temporária foi atualizada para o build 2013 e exibiu `Sincronizado` com a conta de testes já autenticada. As regras publicadas anteriormente permanecem suficientes; nenhum ajuste no Data Connect foi necessário porque este fluxo utiliza Firestore.

Evidências: `design/moto-sync-antes.png`, `design/moto-sync-build2013.png` e `design/web-sync-build2013.png`.

### Orçamento com cartões do Finanças — build 2014

A criação de listas agora permite definir orçamento e selecionar vários cartões/saldos. A edição do orçamento também conserva e permite alterar os cartões vinculados, usando o endpoint de integração já existente do Minhas Finanças. IDs e tipos das fontes financeiras são preservados na lista; o valor total selecionado preenche um orçamento vazio, enquanto um limite informado manualmente é mantido.

Validação: 670 testes Flutter aprovados, incluindo criação com dois cartões, preservação dos vínculos e seleção pela integração; análise estática sem problemas. Web release 2014 publicado no canal temporário. APK release 2014 gerado. O teste direto no Moto ficou pendente porque o usuário confirmou que o celular está desconectado e pediu entrega pelo Google Drive.

Com autorização do usuário, os saldos de Pluxee momo e Alelo VA foram zerados por movimentos auditados no Data Connect do Finanças. A recarga existente do Pluxee de R$ 814 foi antecipada para 11/10/2026 pelo serviço de recargas, sem duplicação. Leitura posterior confirmou Pluxee R$ 814, Alelo R$ 0 e próxima recarga do Pluxee em 15/11/2026. A próxima recarga do Alelo em 25/10/2026 foi preservada.
