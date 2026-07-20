# Plano de ação — estabilização e evolução do Minhas Compras

Data de referência: 19 de julho de 2026

## Objetivo

Transformar o projeto atual em uma base segura, previsível e evolutiva, preservando
as funcionalidades já entregues. A ordem deste plano é determinada por risco:

1. impedir vazamento e perda de dados;
2. garantir sincronização confiável;
3. organizar o código em módulos testáveis;
4. elevar qualidade, publicação, UX e desempenho;
5. somente então ampliar o produto.

Este não é um plano de reescrita. Cada fase deve produzir uma versão utilizável,
com migrações compatíveis e possibilidade de rollback.

## Andamento da implementação

Atualizado em 20 de julho de 2026:

- [x] removido o token Cosmos hardcoded e mantidos os provedores Open Facts
  como fallback sem segredo no cliente;
- [x] fechada a enumeração global de listas compartilhadas;
- [x] protegido o ingresso por convite com claim efêmero vinculado ao código,
  lista e UID autenticado;
- [x] redigidos códigos de convite, UIDs e identificadores dos logs do fluxo
  compartilhado;
- [x] implementado logout seguro com sincronização anterior, cancelamento e
  confirmação explícita de descarte offline;
- [x] serializado o push concorrente para que uma alteração ocorrida durante a
  sincronização gere uma nova gravação antes da saída;
- [x] matriz de segurança validada nos emuladores Auth e Firestore;
- [x] análise estática e suíte Flutter completas aprovadas;
- [x] ADR do protocolo incremental aprovado, com revisões, tombstones,
  conflitos, idempotência e rollback;
- [x] fundação de outbox criada na camada de aplicação, com operação imutável,
  fila serial, full jitter e ACK por operação + revisão;
- [x] journal de compatibilidade persistido por UID para impedir que o snapshot
  atual perca o dirty state ao reiniciar o app;
- [x] CI criada para lint/testes das Functions, análise/testes Flutter, build
  Web release e matriz de Firestore Rules;
- [x] proxy Cosmos implementado em Cloud Functions com autenticação, segredo no
  servidor, timeout, cache, limites transacionais por UID e cota global diária
  de 150, com contrato testado ponta a ponta;
- [x] opt-in explícito para Auth, Firestore e Functions Emulator, sem fallback
  silencioso para produção;
- [x] cadastrado o token Cosmos atual no Secret Manager; a rotação foi adiada
  por decisão explícita do responsável e permanece como risco aceito;
- [x] vinculada e publicada a Function no projeto Firebase;
- [x] revisão completa do cupom fiscal entregue com seleção, edição, confiança
  do matching, vínculo a itens planejados, reconciliação de totais, confirmação
  transacional e desfazer;
- [ ] registrar opcionalmente os provedores App Check como defesa adicional;
- [ ] publicar as novas Firestore Rules somente após revisão do ambiente e
  definição de rollback.
- [ ] migrar o journal temporário de `SharedPreferences` para outbox
  transacional em Drift junto da primeira feature granular;
- [ ] substituir progressivamente o snapshot integral por operações por
  registro, começando por listas pessoais e itens.

## Princípios obrigatórios

### Regra de dependência

Cada feature seguirá esta direção:

```text
presentation -> application -> domain
                         ^
                         |
                 infrastructure
```

- `domain` não importa Flutter, Firebase, plugins, DTOs ou persistência.
- `application` contém casos de uso, portas e coordenação.
- `infrastructure` implementa repositórios, Firebase, armazenamento e APIs.
- `presentation` renderiza estado e envia intenções; não executa regras de negócio.
- A composição de dependências acontece em um único composition root.

### DDD pragmático

Usar DDD onde há regras e invariantes reais, sem criar abstrações cerimoniais.

Contextos sugeridos:

- Identidade e sessão
- Listas pessoais
- Listas compartilhadas
- Catálogo e preços
- Compras e histórico
- Importação fiscal
- Lembretes e backup

Agregados iniciais:

- `ShoppingList`: controla itens, orçamento, fechamento e lembrete.
- `SharedShoppingList`: controla membros, permissões, convite e fechamento.
- `ProductCatalog`: controla identidade do produto e histórico de preços.
- `CompletedPurchase`: snapshot imutável de uma compra concluída.

Value Objects prioritários:

- `ShoppingListId`, `ShoppingItemId`, `UserId`
- `Money`
- `Quantity`
- `Barcode`
- `InviteCode`
- `Revision`

Invariantes devem ser protegidas dentro do domínio, por exemplo:

- quantidade nunca menor que 1;
- dinheiro nunca negativo;
- lista fechada não pode ser editada sem reabertura explícita;
- fechamento ocorre uma única vez por revisão;
- somente o proprietário administra membros e convites;
- uma exclusão remota depende de tombstone explícito, nunca de ausência local.

### Clean Code

- Funções com um propósito e fluxo curto.
- Classes com uma única razão para mudar.
- Nomes de domínio, evitando termos genéricos como `manager`, `helper` e `utils`.
- Estados imutáveis.
- Efeitos assíncronos sempre aguardados, enfileirados ou explicitamente marcados.
- Nenhum `catch` vazio para erros que alterem dados.
- Erros técnicos convertidos em falhas de aplicação compreensíveis.
- `const` em widgets e objetos imutáveis sempre que possível.
- Listas longas construídas de forma lazy.

### Estratégia de estado

Não migrar todo o app de uma vez.

1. Extrair regras e efeitos do `ChangeNotifier` atual para casos de uso e
   coordenadores testáveis.
2. Manter adaptadores temporários para as telas atuais.
3. Migrar feature por feature para Riverpod com:
   - `Notifier` para estado síncrono;
   - `AsyncNotifier` para carregamento e comandos assíncronos;
   - Freezed para estados imutáveis e unions;
   - providers substituíveis em testes.
4. Não usar `StateProvider` para estado de negócio.

Os casos de uso retornam um tipo consistente como `Either<AppFailure, T>`.
Erros esperados não devem depender de exceções ou strings.

---

## P0 — contenção imediata

Prazo sugerido: 1 a 3 dias úteis.

Nenhuma nova funcionalidade deve ser iniciada antes da conclusão deste bloco.

### 1. Conter o token Cosmos exposto

Ações:

- manter o token atual por decisão explícita do responsável, registrando que o
  histórico Git impede tratá-lo como confidencial;
- cadastrar o valor somente no Secret Manager e no arquivo local ignorado;
- remover qualquer fallback hardcoded;
- verificar o histórico Git e registrar o risco aceito;
- criar endpoint intermediário em Cloud Functions ou backend;
- exigir autenticação, cache e rate limiting global e por usuário;
- registrar apenas status, duração e origem da falha, nunca credenciais.

Critérios de aceite:

- nenhum valor de segredo presente na árvore de trabalho ou em novos builds;
- exposição histórica registrada como risco aceito;
- APK, Web e código cliente não contêm o token;
- a busca continua funcionando pelo backend;
- abuso e excesso de chamadas possuem limite e métrica.

### 2. Fechar a exposição das listas compartilhadas

Ações:

- remover leitura global de `/shared_lists`;
- permitir consultas somente quando o UID autenticado pertence a `memberUids`;
- remover `inviteCode` do documento enumerável da lista;
- mover o ingresso por convite para uma Cloud Function;
- validar convite ativo, expiração, lista, limite de membros e usuário solicitante;
- garantir que o ingresso adicione somente o próprio UID;
- redigir códigos, UIDs e e-mails nos logs.

Matriz mínima de testes das rules:

- anônimo;
- autenticado estranho;
- membro;
- proprietário;
- convite válido;
- convite inválido, revogado e expirado;
- tentativa de adicionar terceiro;
- tentativa de alterar proprietário, orçamento ou campos extras durante o ingresso;
- remoção de membro;
- exclusão da lista.

Critérios de aceite:

- um estranho não consegue listar ou ler listas;
- um membro só lê listas das quais participa;
- um código válido adiciona exatamente o solicitante;
- regras passam no Firebase Emulator;
- nenhum convite completo aparece em logs.

### 3. Impedir perda de dados ao sair

Ações:

- substituir “Sair” direto por `SignOutUseCase`;
- se não houver pendências, sair normalmente;
- se houver pendências online, executar “Sincronizar e sair”;
- se estiver offline, apresentar:
  - “Continuar no app”;
  - “Sair sem sincronizar”, com consequência explícita;
- só limpar armazenamento depois de concluir ou confirmar o descarte;
- nunca cancelar silenciosamente uma escrita pendente.

Critérios de aceite:

- teste cobrindo saída sem pendências;
- teste cobrindo saída com sincronização em andamento;
- teste cobrindo saída offline;
- nenhuma alteração local é descartada sem confirmação.

---

## P1 — reconstruir a sincronização

Prazo sugerido: 2 a 3 sprints.

Este é o bloco mais importante e deve ser tratado como uma feature de domínio,
não como callbacks dentro de widgets.

### 4. Definir o protocolo de sincronização

Criar um ADR antes de alterar a implementação, contendo:

- fonte de verdade por tipo de dado;
- revisão por registro;
- regras de merge;
- comportamento offline;
- tombstones;
- idempotência;
- retry e backoff;
- conflitos visíveis ao usuário;
- política de retenção.

Estados sugeridos:

```text
idle
dirty
syncing
offlineWithPendingChanges
conflict
failed
synced
```

Eventos sugeridos:

```text
localChanged
remoteChanged
connectivityRestored
syncRequested
syncSucceeded
syncFailed
sessionChanged
```

### 5. Migrar de snapshot integral para operações granulares

Ações:

- itens pessoais passam para subcoleções;
- cada registro possui `updatedAt`, `revision` e `updatedBy`;
- alterações locais entram em uma outbox persistente;
- exclusões geram tombstone explícito;
- listeners remotos aplicam deltas;
- a outbox é processada serialmente;
- uma alteração ocorrida durante um push mantém o estado dirty;
- retries usam backoff exponencial com jitter;
- operações são idempotentes.

Não fazer:

- apagar registros remotos porque não existem no snapshot local;
- regravar catálogo, histórico e todas as listas após uma edição;
- limpar dirty state sem comparar a revisão enviada;
- iniciar push e pull concorrentes sem coordenação.

Critérios de aceite:

- celular A cria uma lista e celular B não a apaga ao retomar;
- A e B editam registros diferentes offline e ambos sobrevivem;
- duas edições rápidas no mesmo dispositivo chegam ao servidor;
- queda de rede durante push não marca a sincronização como concluída;
- retry não duplica histórico ou itens;
- custo de uma alteração é proporcional aos registros modificados.

### 6. Isolar dados locais por usuário

Ações:

- substituir chaves globais por namespace de UID;
- abrir o armazenamento somente após resolver a sessão;
- fechar e aguardar a sessão anterior antes de abrir a seguinte;
- manter área separada para modo convidado;
- considerar Drift/SQLite para dados relacionais e outbox;
- documentar migração de `SharedPreferences` para o novo armazenamento;
- manter backup automático antes da primeira migração.

Critérios de aceite:

- trocar de conta não exibe dados da conta anterior;
- uma conta nova não recebe dados residuais;
- interrupção durante logout/login não mistura namespaces;
- migração preserva listas, catálogo e histórico existentes.

### 7. Tornar fechamento e compartilhamento atômicos

Ações:

- criar `FinalizePurchaseUseCase`;
- usar transação remota para validar aberta → fechada;
- usar ID determinístico do fechamento;
- gravar histórico e estado fechado como uma unidade lógica;
- usar outbox/saga quando a operação envolver dados locais e remotos;
- fazer criação de lista compartilhada idempotente;
- suportar batches em chunks;
- limpar criações parciais com compensação.

Critérios de aceite:

- duas finalizações simultâneas geram um histórico;
- falha no meio não deixa local fechado e remoto aberto sem estado pendente;
- retry conclui a mesma operação sem duplicar dados.

---

## P1 — consolidar Clean Architecture

Prazo sugerido: executado junto da nova sincronização, feature por feature.

### 8. Adotar estrutura feature-first

Estrutura-alvo:

```text
lib/src/
  core/
    error/
    result/
    identifiers/
    money/
    logging/
  features/
    identity/
      domain/
      application/
      infrastructure/
      presentation/
    personal_lists/
      domain/
      application/
      infrastructure/
      presentation/
    shared_lists/
      domain/
      application/
      infrastructure/
      presentation/
    catalog/
    purchases/
    receipt_import/
    reminders/
    backup/
  app/
    bootstrap/
    routing/
    theme/
```

Ordem de extração:

1. sincronização privada;
2. sincronização compartilhada;
3. sessão/autenticação;
4. fechamento de compra;
5. catálogo/preços;
6. backup;
7. lembretes;
8. telas restantes.

### 9. Dividir responsabilidades atuais

Extrair de `ShoppingListApp`:

- `AuthSessionController`;
- `PrivateSyncCoordinator`;
- `SharedListSyncCoordinator`;
- `ConnectivityMonitor`;
- `OnboardingController`;
- `ThemeController`.

Extrair de `ShoppingListsStore`:

- `CreateShoppingList`;
- `AddShoppingItem`;
- `UpdateShoppingItem`;
- `RemoveShoppingItem`;
- `CloseShoppingList`;
- `ReopenShoppingList`;
- `BuildReplenishmentSuggestions`;
- `ImportBackup`;
- `ExportBackup`.

Critérios de aceite:

- widgets não acessam Firebase diretamente;
- páginas não controlam retry, debounce ou transação;
- domínio não importa Flutter;
- cada caso de uso possui teste unitário;
- composição de implementações fica centralizada;
- nenhum arquivo novo concentra múltiplas features.

---

## P1 — qualidade e segurança contínuas

Prazo sugerido: iniciar no primeiro sprint e manter permanentemente.

### 10. Criar a pirâmide de testes

Testes unitários:

- invariantes dos agregados e Value Objects;
- casos de uso;
- merge e resolução de conflito;
- máquina de estados de sincronização;
- parser e matching fiscal;
- cálculo de orçamento, saldos e preço.

Testes de infraestrutura:

- repositórios com Firebase Emulator;
- rules de Firestore e Storage;
- migração do armazenamento local;
- outbox e retry;
- serialização compatível com versões anteriores.

Testes de widget:

- 320 × 568, 375 × 667, tablet e largura web;
- `TextScaler` 1.0, 1.3 e 2.0;
- claro, escuro e tema do sistema;
- `SemanticsTester`;
- reduced motion;
- loading, vazio, erro, offline e conflito.

Testes de integração:

- criar conta e entrar;
- modo convidado → conta;
- criar lista offline → reconectar;
- dois dispositivos editando;
- compartilhar e entrar por convite;
- finalizar compra;
- exportar/importar backup;
- excluir conta.

Metas:

- 90% ou mais nas regras críticas de domínio e sincronização;
- 80% ou mais no conjunto do código testável;
- 100% dos cenários críticos de rules;
- cobertura não substitui testes de comportamento.

### 11. Adicionar CI

Pipeline mínimo em cada pull request:

```text
dart format --output=none --set-exit-if-changed
dart analyze
flutter test
testes das Firebase rules
flutter build web --release
flutter build appbundle --release
varredura de segredos
```

Complementos:

- cache de dependências;
- artefatos de falha;
- relatório de cobertura;
- golden tests seletivos;
- Dependabot/Renovate;
- branch protection;
- checklist de migração e rollback.

### 12. Padronizar erros e observabilidade

Ações:

- criar `AppFailure` como sealed hierarchy;
- mapear Firebase, rede, validação, permissão, conflito e armazenamento;
- usar estado persistente/selecionável para erros importantes;
- reservar toast para confirmações transitórias;
- adicionar Crashlytics ou Sentry;
- redigir PII, tokens e convites;
- incluir correlation ID nas operações de sync;
- permitir relatório de suporte anonimizado por padrão.

---

## P1 — prontidão para publicação

Prazo sugerido: 1 sprint após estabilizar sincronização.

### 13. Android

- definir package/application ID definitivo;
- criar keystore de produção fora do Git;
- configurar assinatura por ambiente;
- validar ProGuard/R8;
- revisar permissões e políticas de exact alarm;
- corrigir foreground e máscara monocromática do ícone;
- configurar flavors `dev`, `staging` e `production`.

### 14. iOS

- adicionar descrições de câmera e galeria;
- configurar Google Sign-In corretamente;
- adicionar opção equivalente de login, normalmente Sign in with Apple;
- configurar bundle ID e entitlements definitivos;
- validar scanner, OCR e notificações em dispositivo real;
- revisar orientação e layout em iPhone SE/iPad.

### 15. Privacidade e conta

- tela “Privacidade e dados”;
- política de privacidade acessível no app;
- termos aplicáveis;
- exportação de dados;
- exclusão de conta e dados;
- remoção de Firestore, Storage e subcoleções;
- link web para solicitação de exclusão;
- retenção e consequência claramente descritas;
- controle de privacidade para notificações e widgets.

### 16. Web/PWA

- substituir nome e descrição padrão do Flutter;
- revisar `Cache-Control` de scripts estáveis e service worker;
- testar atualização entre releases;
- validar responsividade e navegação por teclado;
- limitar largura do conteúdo;
- usar fontes empacotadas para preservar o modo offline.

Critérios de aceite da fase:

- build assinado de produção;
- login funcional em cada plataforma suportada;
- scanner e OCR funcionais no iOS;
- exclusão de conta testada;
- atualização PWA entrega a versão nova;
- checklist de Play Store e App Store concluído.

---

## P2 — UX, acessibilidade e desempenho

Prazo sugerido: 1 a 2 sprints.

### 17. Responsividade

- onboarding rolável;
- CTAs empilhados quando necessário;
- metadados e filtros em `Wrap`;
- ações secundárias em menus contextuais;
- `SliverList.builder`/`ListView.builder` em listas extensas;
- container de largura máxima em web/tablet;
- `NavigationRail` ou split view em telas largas.

### 18. Acessibilidade

- rótulos semânticos contextuais para checkbox e stepper;
- tooltip em toda ação apenas com ícone;
- live region em OCR, lookup e sync;
- contraste mínimo de 4,5:1 para texto normal;
- foco e ordem de teclado no Web;
- reduced motion respeitado por rotas, modais e animações;
- não usar apenas cor para indicar estado.

### 19. Clareza da linguagem

- escolher uma taxonomia entre “Pego”, “No carrinho” e “Comprado”;
- renomear “Concluir” no modo mercado se ele apenas salvar;
- usar “Sair” de forma consistente;
- substituir “Onboarding” por “Tour inicial”;
- explicar OCR pelo benefício antes do termo técnico;
- erros apresentam ação de recuperação;
- exclusões oferecem desfazer quando possível.

### 20. Desempenho percebido

- remover atraso fixo de 2,5 segundos;
- exibir skeleton apenas durante trabalho real;
- empacotar Rubik e Nunito Sans no app;
- evitar refresh forçado de token a cada rebuild;
- paralelizar lookups compatíveis com timeout total;
- medir rebuilds e jank no DevTools;
- definir orçamento de tempo para startup, scanner e abertura de lista.

Critérios de aceite:

- nenhuma exceção de overflow na matriz de telas;
- fluxo principal utilizável com leitor de tela;
- reduced motion sem transições forçadas;
- listas extensas mantêm rolagem fluida;
- abertura não possui atraso artificial.

---

## P3 — funcionalidades de produto

Somente iniciar após P0 e P1.

### 21. Revisão editável do cupom fiscal

Prioridade: alta.

Status: implementado em 20 de julho de 2026.

- [x] selecionar itens antes da importação;
- [x] editar nome, quantidade e preço;
- [x] mostrar confiança do matching;
- [x] relacionar cada linha a um item planejado;
- [x] comparar soma dos itens com total do cupom e destacar divergências;
- [x] confirmar a compra atualizando histórico e catálogo em uma operação;
- [x] desfazer importação local e compartilhada.

### 22. Central de colaboração

Prioridade: alta.

- nome, foto e e-mail mascarado dos membros;
- papéis `owner`, `editor` e `viewer`;
- sair da lista;
- transferir propriedade;
- convite por QR/share sheet;
- expiração de convite;
- trilha de atividade com undo.

### 23. Insights de compras

Prioridade: alta.

- gasto por mês e categoria;
- planejado versus realizado;
- variação mensal;
- produtos que mais subiram ou baixaram;
- economia em relação à média;
- alertas baseados em dados suficientes.

### 24. Preços por estabelecimento

Prioridade: média/alta.

- registrar mercado no fechamento;
- histórico de preço por produto e loja;
- comparar custo estimado da cesta;
- evitar alegações de preço atual quando o dado for histórico;
- deixar a origem e data do preço visíveis.

### 25. Modo convidado offline

Prioridade: média/alta.

- usar listas localmente sem conta;
- explicar que login habilita backup, sync e colaboração;
- migrar dados do convidado mediante consentimento;
- permitir continuar offline após falha de autenticação.

### 26. Organização por mercado e reposição

Prioridade: média.

- ordenar categorias por corredor;
- salvar ordem por estabelecimento;
- estoque doméstico opcional;
- consumo estimado;
- sugestão de reposição explicável e ajustável.

---

## Ordem recomendada de execução

```text
P0.1 Token
  -> P0.2 Rules e convite
  -> P0.3 Saída segura
  -> P1.4 Protocolo de sync
  -> P1.5 Sync granular
  -> P1.6 Isolamento por UID
  -> P1.7 Fechamento atômico
  -> P1.8/9 Clean Architecture
  -> P1.10/11 Testes e CI
  -> P1.12 Observabilidade
  -> P1.13-16 Publicação
  -> P2 UX e desempenho
  -> P3 Funcionalidades
```

## Recorte sugerido dos primeiros cinco pull requests

### PR 1 — contenção de segredo

- remover token hardcoded;
- desativar Cosmos direto no cliente;
- criar teste que impede segredo conhecido;
- documentar armazenamento seguro e o risco aceito da não rotação.

### PR 2 — rules seguras

- restringir leitura de listas;
- bloquear ingresso permissivo;
- redigir logs;
- adicionar matriz de testes no Emulator.

### PR 3 — saída segura

- criar `SignOutUseCase`;
- introduzir confirmação de pendência;
- aguardar sync/limpeza;
- adicionar testes de saída online e offline.

### PR 4 — especificação e esqueleto do sync

- ADR do protocolo;
- `SyncState`, `SyncEvent` e `SyncCoordinator`;
- outbox em memória para testes;
- testes da máquina de estados;
- adaptador temporário para a store atual.

### PR 5 — persistência por UID e outbox durável

- storage namespaced;
- migração segura;
- outbox persistente;
- testes de troca de conta e interrupção.

## Definition of Done global

Uma tarefa só está concluída quando:

- comportamento e critérios de aceite estão cobertos por testes;
- analyzer e formatter passam;
- não há segredo ou PII em logs;
- erros possuem tratamento e recuperação;
- loading, vazio, offline e falha foram considerados;
- acessibilidade e text scaling foram verificados quando houver UI;
- migração e rollback foram documentados quando houver dados persistentes;
- README e documentação refletem o estado atual;
- mudança foi validada em pelo menos uma plataforma real afetada.

## Resultado esperado

Ao final de P1, o aplicativo deve:

- não expor listas ou convites;
- não perder dados em uso offline ou multi-dispositivo;
- não misturar contas;
- sincronizar alterações granularmente e de forma idempotente;
- ter regras críticas protegidas por testes;
- possuir módulos de domínio e aplicação independentes de Flutter/Firebase;
- estar apto a receber melhorias de UX e novas funcionalidades sem ampliar o
  acoplamento atual.
