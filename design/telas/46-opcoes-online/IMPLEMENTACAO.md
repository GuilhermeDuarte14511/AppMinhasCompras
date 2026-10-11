# 46 — Opções online

## Implementação

`AppOptionsPage`, em `lib/src/presentation/account_pages.dart`, mantém a mesma API e os mesmos fluxos de perfil, saída da conta, preferência de tema, importação do catálogo compartilhado, integração financeira, diagnóstico e onboarding. O painel de nuvem foi extraído para `account/cloud_sync_status_panel.dart`, compartilhado com a referência 47.

O layout acompanha a composição do HTML salvo: título central, abertura editorial, grupos Conta, Aparência, Dados e Ajuda, superfícies claras com divisórias e raios discretos. A página rola, tem largura limitada em telas amplas e suporta modo escuro e texto ampliado. O resumo de perfil usa nome, e-mail, fotografia e iniciais reais; não apresenta Helena Ramos ou valores ilustrativos.

## Diferenças avaliadas e integradas

- **Sistema:** o app já aceita `ThemeMode.system` e persiste o callback existente, mas a opção só aparecia quando recebida como configuração inicial. Agora pode ser selecionada a qualquer momento, permitindo acompanhar o tema do dispositivo. Não exige novo campo, backend, Data Connect ou rules.
- **Catálogo:** o texto do Stitch promete aplicar edições globalmente. A flag atual importa produtos adicionados às listas compartilhadas do usuário como dono. A descrição funcional correta foi preservada, sem ampliar silenciosamente as permissões de edição.
- **Finanças:** o badge “Conectado” foi omitido porque `AppOptionsPage` não recebe o estado dessa integração. O usuário continua acessando a página financeira real.
- **Sincronização:** hora, contadores e coleções vêm dos parâmetros reais do app. A marca “Estável” e a duração relativa ilustrativa foram omitidas. A ausência de confirmação anterior não se transforma em afirmação de sincronização concluída.

## Verificação

- Cinco novos testes em `test/presentation/options_online_redesign_test.dart`: referência visual 390 × 884 com fontes locais; identificação real; Sistema selecionável e callback; catálogo e texto funcional correto; timestamp real e ausência de badge financeiro; fallback de nome; tela escura 320 × 568 com escala 1,5 e controles de pelo menos 48 dp.
- Os seis testes anteriores de opções continuam cobrindo troca de tema, importação, saída sem solicitações duplicadas, estados reais de nuvem, replay do onboarding e responsividade. Ajustados somente para a nova rolagem e apresentação separada do timestamp.
- Onze testes das duas suítes aprovados. O golden antigo foi atualizado porque a composição de opções agora inclui o resumo real da conta e os novos grupos; o comparador visual continua estrito.

Validação integrada de 46 e 47: 65 testes aprovados, incluindo perfil, diagnóstico, fluxos principais do app e política de sincronização. `flutter analyze --no-pub` sem problemas. O teste de navegação para diagnóstico aguarda a conclusão da rolagem antes de tocar na opção.
