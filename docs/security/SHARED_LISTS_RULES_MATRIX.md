# Matriz de segurança — listas compartilhadas

Esta matriz registra as garantias esperadas das regras de `shared_lists`,
`list_invites` e `invite_claims`. Os casos críticos são executados contra os
emuladores de Authentication e Firestore por:

```powershell
firebase emulators:exec --config firebase.rules-test.json `
  --project demo-lista-compras --only auth,firestore `
  "pwsh -NoProfile -File test/firestore/shared_lists_rules_emulator.ps1"
```

## Modelo de entrada por convite

1. O cliente lê diretamente `list_invites/{code}`. Consultas à coleção são
   proibidas, então esse `get` prova conhecimento de um código de 8 caracteres.
2. O cliente cria `invite_claims/{code}_{uid}` com `createdAt` definido por
   `serverTimestamp`.
3. A entrada atualiza somente `memberUids` e `updatedAt`. As regras exigem um
   claim do mesmo código, UID e lista, criado há no máximo cinco minutos.
4. O repositório remove o claim depois da entrada. A validade curta impede o uso
   tardio caso a limpeza falhe.

## Casos que devem ser permitidos

| Operação | Identidade | Pré-condição |
| --- | --- | --- |
| Consultar listas por `memberUids` | Membro | `array-contains` usa o próprio UID |
| Consultar listas por `ownerUid` | Dono | filtro usa o próprio UID |
| Ler uma lista por ID | Membro ou dono | identidade consta no documento |
| Ler convite por ID | Autenticado | conhece exatamente o código |
| Criar/renovar claim | Autenticado | código ativo aponta para a mesma lista |
| Entrar na lista | Não membro | claim válido; adiciona somente o próprio UID |
| Remover membro | Dono | operação apenas reduz `memberUids` |
| Alterar conteúdo da lista | Membro | não altera membros, convite ou origem |

## Casos que devem ser negados

| Operação | Motivo esperado |
| --- | --- |
| Listar `shared_lists` sem filtro de associação | Evita enumeração global |
| Consultar listas de outro UID | A consulta não prova associação do solicitante |
| Listar `list_invites` ou `invite_claims` | Evita descoberta de códigos e claims |
| Ler claim, inclusive o próprio | Claim é uma credencial de uso interno |
| Criar claim para outro UID | ID e payload devem conter `request.auth.uid` |
| Criar claim para código inexistente, revogado ou de outra lista | Convite ativo e vínculos são verificados pelas regras |
| Entrar sem claim ou com claim mais antigo que cinco minutos | Prova ausente ou expirada |
| Entrar adicionando UID de terceiro | O único novo membro deve ser o solicitante |
| Entrar alterando nome, orçamento, convite ou qualquer outro campo | O diff aceita apenas `memberUids` e `updatedAt` |
| Elevar a lista para mais de 30 membros | Limite do agregado |
| Membro alterar membros, convite ou origem | Campos administrativos são imutáveis para membros |
| Dono adicionar membro diretamente | Novos membros precisam do fluxo de convite |
| Remover o dono de `memberUids` | O dono deve permanecer membro do agregado |

## Riscos residuais

- Firestore Rules não oferece rate limit. Limitação no backend e App Check
  opcional ainda são recomendados contra tentativa automatizada de códigos.
- O código continua visível aos membros da lista, por ser necessário à interface
  atual. Uma etapa futura pode removê-lo de `shared_lists` e manter o convite
  somente em coleção protegida/backend.
- Claims cuja limpeza falhar permanecem armazenados, mas deixam de autorizar
  entrada após cinco minutos. Uma política TTL pode removê-los fisicamente.
- O teste usa a API REST dos emuladores para não adicionar dependências ao app.
