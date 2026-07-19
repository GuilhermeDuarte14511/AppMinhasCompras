# ADR 0001 — Protocolo de sincronização incremental e offline-first

- Status: aceito para implementação incremental
- Data: 19 de julho de 2026
- Decisores: equipe do Minhas Compras
- Escopo inicial: dados privados por usuário
- Escopo posterior: comandos de listas compartilhadas e fechamento de compra

## Contexto

O fluxo atual sincroniza listas pessoais, histórico, catálogo e configurações como
um snapshot integral:

1. o pull carrega coleções inteiras do Firestore;
2. quando existe conteúdo remoto, o snapshot substitui o conteúdo local;
3. qualquer alteração local marca um único indicador global como pendente;
4. o push lê coleções remotas, regrava todos os registros locais e exclui os
   documentos remotos ausentes no snapshot local;
5. retries são coordenados por timers e estado em memória dentro de
   `ShoppingListApp`.

Esse modelo não distingue quais registros foram alterados, não preserva uma
intenção de escrita após o encerramento do processo e não consegue detectar
edições concorrentes com segurança. Um dispositivo desatualizado pode apagar
dados criados por outro dispositivo. `updatedAt` usa o relógio do cliente e,
isoladamente, não é uma revisão confiável.

O domínio também possui necessidades diferentes:

- listas pessoais precisam funcionar offline e sincronizar entre dispositivos;
- listas compartilhadas possuem múltiplos autores e já dependem do Firestore;
- histórico de compras deve ser imutável e não pode ser duplicado por retry;
- catálogo combina atributos editáveis, contadores e histórico de preços;
- configurações têm baixo risco de conflito, mas ainda precisam de revisão;
- identidade e sessão pertencem ao Firebase Auth, não ao protocolo de dados.

Esta decisão evita uma reescrita integral. O protocolo novo será introduzido por
usuário e por tipo de registro, mantendo versões utilizáveis e uma rota segura
de rollback em cada etapa.

## Decisão

Adotaremos sincronização incremental offline-first, baseada em:

- armazenamento local transacional isolado por UID;
- registros remotos granulares com revisão monotônica;
- outbox persistente de operações idempotentes;
- tombstones explícitos para exclusões;
- compare-and-set por `baseRevision`;
- feed remoto de mudanças para pull incremental;
- conflitos persistidos e resolvidos de forma explícita;
- retry exponencial com jitter;
- uma máquina de estados derivada de fatos persistidos;
- migração controlada por versão de protocolo e feature flag.

O conteúdo exibido pela aplicação será sempre lido do banco local. Firestore é
a fonte durável compartilhada entre dispositivos, mas uma alteração local ainda
não confirmada continua sendo a intenção vigente daquele dispositivo e não pode
ser sobrescrita silenciosamente por um pull.

## Fontes de verdade

“Fonte de verdade” não significa que o servidor substitui cegamente o local. A
autoridade depende do tipo de dado e do estágio da operação.

| Tipo de dado | Fonte autoritativa | Cópia local | Política |
| --- | --- | --- | --- |
| Sessão e identidade | Firebase Auth | projeção da sessão | O UID resolvido abre o namespace local correspondente. |
| Lista pessoal e metadados | registro versionado no Firestore após ack | modelo de leitura e alterações pendentes | A UI lê localmente. Alteração sem ack permanece dirty. |
| Item de lista pessoal | documento granular versionado | modelo de leitura e alterações pendentes | Itens deixam de ser um array embutido no documento da lista. |
| Histórico de compra | evento imutável no Firestore | cache local | ID determinístico; append-only; correção gera novo evento, não sobrescrita casual. |
| Catálogo | registros versionados e eventos de preço | projeção local | Contadores usam incremento; histórico de preço é append-only. |
| Configurações | registro versionado no Firestore | cache local | Compare-and-set; conflito simples pode oferecer escolha entre versões. |
| Lista compartilhada | Firestore, validado por regras/backend | projeção/cache local | Mutações são comandos remotos; o espelho privado nunca é autoridade. |
| Outbox e conflitos | banco local do UID | não aplicável | Persistem até ack ou resolução explícita. |

Enquanto não houver sessão, dados do modo convidado usam um namespace próprio.
Eles só são migrados para uma conta após consentimento e por um caso de uso
específico.

## Modelo remoto

Cada registro sincronizável terá metadados equivalentes a:

```text
id             identificador estável
revision       inteiro monotônico, atribuído no commit remoto
schemaVersion  versão do payload
updatedAt      timestamp do servidor, apenas para ordenação e diagnóstico
updatedBy      { userId, deviceId }
operationId    última operação aplicada
deletedAt      timestamp do servidor quando for tombstone; ausente se ativo
payload        campos do domínio
```

O campo `updatedAt` não decide conflitos. O relógio do cliente poderá ser
registrado como `clientOccurredAt` para diagnóstico, mas a concorrência será
decidida por `revision` e `baseRevision`.

Estrutura-alvo inicial:

```text
users/{uid}
  lists/{listId}
    items/{itemId}
  purchases/{purchaseId}
  catalog/{productId}
    price_events/{priceEventId}
  settings/app
  sync_operations/{operationId}
  sync_changes/{changeId}
  sync_devices/{deviceId}
```

Tombstones permanecem no caminho original do registro para que consultas e
listeners observem a exclusão. Documentos de recibo em `sync_operations`
registram o resultado de uma operação já aplicada. Cada commit remoto também
grava um evento em `sync_changes`.

## Revisões e compare-and-set

Toda mutação leva:

```text
operationId
entityType
entityId
kind
baseRevision
payload
schemaVersion
deviceId
clientOccurredAt
correlationId
```

No commit remoto:

1. se já existir um recibo para `operationId`, o resultado anterior é devolvido;
2. o registro atual é lido em transação;
3. se `baseRevision` for igual à revisão remota, a operação é aplicada;
4. a revisão remota é incrementada em uma unidade;
5. registro, recibo e evento de mudança são gravados na mesma transação;
6. se as revisões divergirem, nenhum dado é alterado e um resultado de conflito
   contém a versão remota atual.

Criações usam `baseRevision = 0`. Uma criação repetida com o mesmo
`operationId` retorna o primeiro resultado. Um ID já existente, criado por outra
operação, produz conflito.

O cliente só limpa o dirty state se o ack corresponder ao mesmo `operationId` e
à mesma versão local enviada. Se ocorrer outra alteração durante o push, a nova
operação permanece na outbox.

## Outbox local

O armazenamento local passará de blobs em `SharedPreferences` para SQLite,
preferencialmente Drift, atrás de portas da camada de aplicação. A escolha é
necessária porque a alteração do modelo de leitura e a inserção da operação na
outbox precisam ocorrer na mesma transação local.

Cada entrada contém, no mínimo:

```text
operationId
userId
deviceId
aggregateType
aggregateId
entityType
entityId
kind
baseRevision
payload
schemaVersion
createdAt
attemptCount
nextAttemptAt
status
leaseUntil
lastFailureCode
correlationId
```

Estados persistidos da entrada:

- `pending`: pronta ou aguardando `nextAttemptAt`;
- `inFlight`: reservada por um worker com lease;
- `blockedByConflict`: depende de resolução do usuário ou política de domínio;
- `blockedByFailure`: erro permanente que exige ação;
- `acknowledged`: estado transitório até a projeção e o cursor serem atualizados.

Regras da outbox:

- modelo local e operação são gravados atomicamente;
- no primeiro incremento, haverá somente um worker global por usuário;
- operações do mesmo agregado respeitam FIFO;
- uma operação posterior nunca ultrapassa um conflito anterior do agregado;
- leases expirados voltam para `pending` após crash;
- ack, revisão local, projeção e remoção da entrada são uma transação local;
- compactação só será permitida quando uma regra específica provar equivalência
  semântica; não será aplicada genericamente a comandos de domínio;
- logout e encerramento do app não removem operações pendentes.

No futuro, agregados diferentes poderão ser processados em paralelo com limite
de concorrência. Isso não faz parte da primeira implementação.

## Pull incremental

Cada commit remoto gera um `sync_change` imutável contendo:

```text
changeId
operationId
entityType
entityId
revision
kind
committedAt
```

O cliente mantém, por UID, um cursor composto pelo último documento observado.
O pull:

1. consulta mudanças após o cursor em páginas;
2. carrega somente os registros referenciados;
3. aplica tombstones e versões novas em transação local;
4. preserva qualquer alteração local não confirmada;
5. cria conflito se a versão remota avançou além da `baseRevision` local;
6. avança o cursor somente depois do commit local;
7. repete até alcançar o fim da página atual.

Listeners podem antecipar o pull quando o app está ativo, mas não substituem o
cursor persistente. Duplicatas são aceitas e ignoradas por
`entityId + revision + operationId`.

Se o cursor for mais antigo que a retenção do feed, estiver inválido ou houver
uma lacuna detectada, o cliente executa bootstrap paginado. O bootstrap faz
merge por revisão; nunca apaga dados apenas porque um registro não apareceu em
uma página.

## Regras de merge e conflito

### Regra geral

- registros diferentes são mesclados independentemente;
- a mesma operação repetida é idempotente;
- versão remota igual à revisão base permite aplicar a operação;
- versão remota mais nova e operação local pendente produz conflito;
- versão remota mais nova sem operação local pendente atualiza a projeção local;
- ausência não significa exclusão;
- exclusão só existe como tombstone.

### Políticas por dado

| Dado/operação | Política |
| --- | --- |
| Criar lista ou item | ID estável e operação idempotente; colisão real gera conflito. |
| Editar lista ou item | Compare-and-set no registro inteiro na primeira versão do protocolo. |
| Editar registros diferentes offline | Merge automático, pois revisões são independentes. |
| Excluir sem edição concorrente | Grava tombstone com nova revisão. |
| Excluir versus editar | Não ressuscitar silenciosamente. Bloquear o agregado e oferecer manter excluído ou criar uma cópia com novo ID. |
| Reabrir lista | Comando de domínio explícito; não é edição genérica de `isClosed`. |
| Finalizar compra | Transação/comando próprio, com `purchaseId` determinístico derivado de lista e revisão de fechamento. |
| Histórico de compra | Append-only; mesmo ID retorna o evento existente. |
| Incrementar uso do catálogo | Operação com delta, não substituição do contador. |
| Registrar preço | Evento imutável com ID determinístico da origem; retry não duplica. |
| Nome/categoria do catálogo | Compare-and-set; divergência gera conflito simples. |
| Configurações | Compare-and-set do documento; a UI pode oferecer local/remoto. |
| Lista compartilhada | Backend/transação aplica comando conforme papel e revisão; não usar merge local de snapshot. |

Last-write-wins baseado em timestamp não será usado para dados de negócio. Uma
política automática poderá ser adicionada a um campo específico apenas após
documentar sua comutatividade e seus testes.

### Resolução visível

Conflitos não serão exibidos como exceções técnicas. A aplicação persiste:

- versão base;
- intenção local;
- versão remota;
- tipo de conflito;
- ações permitidas pelo domínio.

A apresentação oferece ações concretas, por exemplo:

- usar a versão deste aparelho;
- usar a versão da nuvem;
- manter a exclusão;
- recuperar como nova lista;
- revisar campos antes de confirmar.

“Usar a versão deste aparelho” cria uma nova operação baseada na revisão remota
atual. Nunca altera o servidor ignorando revisão. Até a resolução, outros
agregados continuam sincronizando.

## Idempotência

`operationId` é gerado uma vez quando a operação entra na outbox e nunca muda
em retries. A infraestrutura deve tolerar:

- resposta perdida após commit;
- processo encerrado durante ack local;
- listener recebendo a mesma revisão mais de uma vez;
- retry de fechamento de compra;
- importação repetida durante migração.

IDs de efeitos derivados também são determinísticos. Exemplos:

- compra finalizada: hash estável de `listId + closingRevision`;
- evento de preço: origem + identificador externo ou `operationId`;
- mudança remota: derivada de `operationId + entityId + revision`.

Notificações, métricas e widgets locais são efeitos posteriores ao commit e
também guardam o identificador processado quando puderem causar duplicidade.

## Retry, backoff e falhas

Erros são classificados na infraestrutura e convertidos em falhas da aplicação:

- transiente: indisponibilidade, timeout, conexão, `aborted`,
  `resource-exhausted`;
- autenticação: token expirado ou sessão ausente;
- conflito: revisão divergente;
- permissão/validação: regra, papel ou payload inválido;
- incompatibilidade: versão de protocolo ou schema não suportada;
- armazenamento: falha no banco local;
- desconhecido: preservado para diagnóstico, sem expor PII.

Para falhas transientes será usado exponential backoff com full jitter:

```text
limite = min(5 minutos, 1 segundo * 2^attemptCount)
atraso = aleatório entre 0 e limite
```

Regras adicionais:

- respeitar `Retry-After` quando disponível;
- conectividade restaurada e pedido manual antecipam a próxima tentativa;
- apenas uma tentativa por operação pode estar em voo;
- reiniciar o app preserva `attemptCount` e `nextAttemptAt`;
- falha de autenticação pausa o worker até `sessionChanged`;
- conflito não é repetido automaticamente;
- permissão, validação e incompatibilidade ficam bloqueadas;
- após oito falhas transientes consecutivas, o estado visível passa a `failed`,
  mas a operação não é descartada e pode ser retomada manualmente ou por uma
  mudança relevante de conectividade/sessão.

Processamento em background é best-effort e respeitará as limitações de Android,
iOS e Web. A correção não dependerá de o sistema permitir execução em segundo
plano.

## Estados e eventos

O estado apresentado é uma projeção de sessão, conectividade, outbox, conflitos
e worker. Não será a única fonte de verdade e não dependerá apenas de campos em
memória.

Estados:

```text
idle
hydrating
synced
dirty
syncing
offlineWithPendingChanges
conflict
failed
```

Significados:

- `idle`: sem sessão ou coordenador parado;
- `hydrating`: abrindo namespace, migrando ou executando bootstrap inicial;
- `synced`: sem operação pendente e cursor remoto atualizado;
- `dirty`: existem operações pendentes, ainda não processadas;
- `syncing`: worker processando push ou pull;
- `offlineWithPendingChanges`: offline com outbox não vazia;
- `conflict`: pelo menos uma operação está bloqueada por conflito;
- `failed`: existe falha permanente ou o limiar de retries visíveis foi atingido.

Eventos:

```text
sessionChanged
localChanged
remoteChanged
connectivityLost
connectivityRestored
syncRequested
syncStarted
syncSucceeded
syncFailed
conflictDetected
conflictResolved
storageOpened
storageFailed
```

Transições principais:

| Estado/evento | Próximo estado |
| --- | --- |
| `idle + sessionChanged(uid)` | `hydrating` |
| `hydrating + storageOpened`, sem pendências | `syncing` para pull e depois `synced` |
| `synced + localChanged` | `dirty` |
| `dirty + syncRequested`, online | `syncing` |
| `dirty + connectivityLost` | `offlineWithPendingChanges` |
| `offlineWithPendingChanges + connectivityRestored` | `syncing` |
| `syncing + localChanged` | continua `syncing`, com nova operação pendente |
| `syncing + syncSucceeded`, ainda com pendências | `dirty` ou novo `syncing` |
| `syncing + syncSucceeded`, sem pendências | `synced` |
| `syncing + conflictDetected` | `conflict` para o agregado; demais operações continuam |
| `conflict + conflictResolved` | `dirty` |
| qualquer estado + falha permanente | `failed` |
| qualquer estado + `sessionChanged(null)` | fecha o namespace de forma aguardada e vai para `idle` |

Quando existirem condições simultâneas, a apresentação usa a prioridade:
`failed`, `conflict`, `offlineWithPendingChanges`, `syncing`, `dirty`, `synced`.
O detalhe continuará mostrando contagens independentes para não esconder
pendências atrás de um único rótulo.

## Limites de Clean Architecture e DDD

A implementação será feature-first. Nomes indicativos:

```text
features/sync/
  domain/
    sync_operation
    revision
    sync_conflict
    sync_status
  application/
    sync_coordinator
    process_outbox
    pull_remote_changes
    resolve_sync_conflict
    ports/
  infrastructure/
    drift_sync_local_repository
    firestore_sync_gateway
    connectivity_adapter
  presentation/
    sync_status_controller
    conflict_resolution_page
```

Responsabilidades:

- domínio define revisão, operação, conflito, transições válidas e invariantes;
- aplicação coordena casos de uso e depende apenas de portas;
- infraestrutura implementa Drift, Firestore, conectividade e serialização;
- apresentação observa um estado imutável e envia intenções;
- o composition root cria as implementações;
- widgets não acessam Firebase, timers ou outbox;
- repositórios não decidem textos, navegação ou toasts.

O `PrivateSyncCoordinator` tratará dados privados. O
`SharedListSyncCoordinator` usará o mesmo envelope de operação quando útil, mas
respeitará o agregado, as permissões e os comandos próprios de colaboração.

## Invariantes

1. Nenhum pull sobrescreve uma intenção local sem ack ou resolução.
2. Nenhuma ausência em snapshot ou página causa exclusão.
3. Toda exclusão sincronizada possui tombstone.
4. Toda alteração local sincronizável e sua entrada de outbox são atômicas.
5. Uma operação mantém o mesmo `operationId` em todos os retries.
6. O dirty state só é limpo pelo ack da versão efetivamente enviada.
7. Há no máximo uma operação em voo por agregado.
8. Dados e outbox nunca cruzam namespaces de UID.
9. Troca de sessão fecha e aguarda o namespace anterior antes de abrir outro.
10. Fechamento de compra e criação do histórico formam uma unidade lógica
    idempotente.
11. Logs não contêm payload, e-mail, nome, convite ou UID completo.
12. Schema desconhecido não é descartado nem parcialmente interpretado.

## Retenção

- tombstones: no mínimo 90 dias;
- feed `sync_changes`: 90 dias;
- recibos de idempotência: 90 dias, nunca menos que a janela máxima de retry e
  restauração suportada;
- conflitos: até resolução, exclusão da conta ou política explícita de 180 dias
  com exportação anterior;
- dispositivos sem contato por 60 dias: marcados inativos e obrigados a fazer
  bootstrap ao retornar;
- backup pré-migração local: mantido por pelo menos 30 dias ou até duas versões
  estáveis do app, o que for maior.

A coleta de tombstones e mudanças só ocorre depois de considerar os dispositivos
ativos. Um cliente cujo cursor expirou nunca continua incrementalmente: ele faz
bootstrap paginado.

## Migração incremental

### Etapa 0 — contenção e telemetria

- remover do legado a exclusão remota baseada em ausência local;
- medir volume de registros, duração, falhas e duplicidades sem registrar PII;
- adicionar feature flags remotas e kill switch do worker;
- definir `deviceId` aleatório por instalação;
- criar testes de contrato e emulador antes de qualquer escrita v2.

### Etapa 1 — portas e armazenamento local

- introduzir portas de sync sem mudar a apresentação;
- criar banco SQLite/Drift por UID, incluindo outbox, conflitos e cursor;
- exportar backup JSON antes da primeira migração;
- importar blobs de `SharedPreferences` em uma transação;
- gravar checksum, contagens e marcador de migração;
- manter os blobs legados intactos durante a janela de rollback.

A importação é repetível: se o marcador e o checksum já existirem, ela não cria
duplicatas.

### Etapa 2 — schema remoto compatível

- adicionar `revision`, `schemaVersion`, `updatedBy` e `operationId`;
- registros legados recebem `revision = 1` durante backfill idempotente;
- migrar itens embutidos para subcoleção com IDs existentes;
- registrar um marcador por usuário e validar contagens;
- manter leitura do formato v1 enquanto a migração estiver incompleta.

Usuários têm `syncProtocolVersion`. Depois que um usuário começa a escrever em
v2, clientes antigos não podem voltar a publicar snapshots destrutivos. Rules ou
backend rejeitam a escrita v1 e o cliente antigo solicita atualização.

### Etapa 3 — shadow mode

- construir operações e merge v2 em paralelo, sem enviar mutações;
- comparar projeção v2 com o estado legado;
- registrar somente códigos, contagens e hashes não reversíveis;
- bloquear rollout enquanto houver divergências não explicadas.

### Etapa 4 — canário

- habilitar por coortes internas e depois pequenos percentuais;
- iniciar por configurações e listas pessoais;
- migrar itens, catálogo e histórico em etapas separadas;
- manter shared lists fora da primeira coorte;
- observar conflitos, latência, tamanho de outbox, retries e custo do Firestore.

### Etapa 5 — corte

- habilitar v2 por usuário;
- congelar escrita do sincronizador legado;
- manter leitura v1 apenas durante a janela de compatibilidade;
- remover snapshot integral somente após duas versões estáveis e critérios de
  aceite aprovados;
- coletar dados legados depois da retenção e de um backup verificado.

## Rollback

Rollback não significa voltar ao push destrutivo de snapshots.

O kill switch:

1. pausa o processamento remoto da outbox;
2. mantém alterações locais e novas operações persistidas;
3. interrompe pull incremental sem apagar cursor;
4. mantém a aplicação operando offline;
5. preserva schema v2, tombstones, recibos e feed remoto.

Para rollback de uma release:

- a versão anterior compatível deve conseguir abrir o banco sem descartar campos
  desconhecidos, ou a apresentação usa um adaptador somente de leitura;
- o banco migrado não é rebaixado;
- blobs e backup pré-migração permanecem disponíveis;
- rules/backend continuam aceitando o protocolo v2;
- um usuário já marcado como v2 nunca volta a escrever pelo protocolo v1;
- a retomada reutiliza os mesmos `operationId` e cursor.

Se a migração local falhar antes do marcador de conclusão, a transação é
revertida e o app continua com o armazenamento legado. Se falhar depois do corte
remoto, o app entra em modo seguro de leitura/exportação e solicita correção; não
recria um snapshot a partir de dados potencialmente incompletos.

## Observabilidade e segurança

Métricas mínimas:

- tamanho e idade máxima da outbox;
- tempo até ack;
- tentativas por operação;
- taxa de conflito por tipo;
- falhas por código classificado;
- duração e quantidade de registros do bootstrap;
- atraso do cursor;
- divergências detectadas no shadow mode.

Cada ciclo e operação usa `correlationId`. Logs contêm tipo, estágio, código,
duração e identificadores redigidos. Payloads, nomes, preços detalhados, e-mails,
UIDs completos e códigos de convite não são registrados.

Rules garantem isolamento por UID e campos imutáveis. Comandos que exigem
autorização entre usuários ou invariantes multi-documento, especialmente
compartilhamento e fechamento, serão executados por backend autenticado com App
Check. A implementação cliente não é considerada fronteira de segurança.

## Alternativas consideradas

### Manter snapshots integrais

Rejeitada. É simples, mas custo e risco crescem com o conjunto total de dados.
Não diferencia ausência de exclusão e não resolve concorrência entre aparelhos.

### Usar somente a persistência offline nativa do Firestore

Rejeitada como protocolo completo. Ela ajuda no transporte e cache, mas não
modela intenções de domínio, resolução visível, namespace local, idempotência de
efeitos nem migração a partir do armazenamento existente.

### Last-write-wins por `updatedAt`

Rejeitada. Relógios de clientes divergem e uma edição legítima pode ser perdida
sem aviso. Timestamps permanecem apenas para ordenação e diagnóstico.

### Servidor sempre vence

Rejeitada. Sobrescreveria alterações offline ainda não confirmadas e repetiria o
principal risco do fluxo atual.

### Cliente sempre vence

Rejeitada. Um cliente antigo poderia ressuscitar exclusões e apagar trabalho de
outros dispositivos.

### CRDT genérico

Adiada. CRDTs podem resolver alguns merges, mas adicionam custo operacional,
metadados e complexidade desproporcionais às invariantes atuais. Operações
comutativas específicas, como incrementos e eventos append-only, já recebem
políticas próprias e podem evoluir sem um framework CRDT global.

### Outbox em `SharedPreferences`

Rejeitada. Não fornece transação entre projeção e operação, consultas por
status/agregado, lease confiável nem migrações de schema adequadas.

### Sincronização online-only

Rejeitada. Operação offline é requisito do produto e da saída segura já
implementada.

## Consequências

### Positivas

- uma edição custa proporcionalmente aos registros modificados;
- dispositivos não apagam dados uns dos outros por ausência local;
- operações sobrevivem a reinício, logout e perda de resposta;
- conflitos passam a ser detectáveis, testáveis e explicáveis;
- coordenação sai dos widgets e ganha contratos de aplicação;
- fechamento e histórico podem ser realmente idempotentes;
- rollout e rollback são controláveis por usuário.

### Custos e riscos

- novo banco local, schema remoto e rotina de migração;
- armazenamento adicional para tombstones, feed e recibos;
- telas e textos para conflitos;
- backend necessário para invariantes multiusuário;
- clientes antigos precisam ser bloqueados após migração do usuário;
- retenção e bootstrap devem ser monitorados para evitar lacunas;
- mais testes de integração e emulador antes do rollout.

## Critérios de aceite

O protocolo só substitui o legado quando:

- uma alteração local e sua operação de outbox são comprovadamente atômicas;
- reinício durante push não perde nem duplica operação;
- resposta perdida após commit é recuperada pelo mesmo `operationId`;
- A cria um registro e B, desatualizado, não o apaga ao retomar;
- A e B editam registros diferentes offline e ambos sobrevivem;
- edição concorrente do mesmo registro gera conflito reproduzível;
- delete versus edit não ressuscita nem descarta silenciosamente;
- duas finalizações simultâneas produzem uma compra;
- queda de rede não marca operação como sincronizada;
- cursor expirado força bootstrap seguro;
- troca de conta não exibe nem processa dados de outro UID;
- kill switch preserva outbox, cursor e dados locais;
- migração e rollback são testados com interrupção em cada etapa;
- testes unitários cobrem merge, revisão, estados, backoff e idempotência;
- testes com Firebase Emulator cobrem transação, rules e concorrência;
- métricas do canário permanecem dentro dos limites definidos pela equipe.

## Próximos passos aprovados

1. modelar `Revision`, `SyncOperation`, `SyncConflict` e `SyncStatus` sem
   dependências de Flutter ou Firebase;
2. escrever testes da máquina de estados e da matriz de merge;
3. definir portas de outbox, projeção local e gateway remoto;
4. fazer um spike de Drift com banco por UID e migração idempotente dos blobs;
5. criar contrato do commit remoto e validá-lo no Firebase Emulator;
6. retirar a exclusão por ausência do sincronizador legado;
7. implementar shadow mode antes de habilitar qualquer escrita v2.
