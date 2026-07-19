# Backend seguro da Cosmos

## Garantias implementadas

A callable `lookupCosmosProduct`, na região `southamerica-east1`:

- exige Firebase Authentication;
- aceita App Check como proteção adicional, sem torná-lo obrigatório;
- lê `COSMOS_API_TOKEN` somente do Secret Manager;
- valida GTIN e seu dígito verificador antes de consumir cota;
- limita cada UID a 30 consultas por minuto;
- limita o token compartilhado a 25 chamadas externas por dia UTC por padrão;
- usa cache positivo por 24 horas e cache de `not-found` por 6 horas;
- aplica timeout de seis segundos no upstream;
- não devolve token nem corpo de erro da Cosmos ao cliente;
- limita escala a dez instâncias.

O cliente envia somente `{"gtin": "..."}` e aceita o DTO estrito:

```json
{
  "product": {
    "gtin": "7894900011517",
    "name": "Café Premium",
    "categoryKey": "beverages",
    "unitPrice": 19.9
  }
}
```

Uma fixture única em `test/fixtures/cosmos_lookup_response.json` valida o mesmo
contrato nas suítes Dart e TypeScript. O composition root sempre instala o
adaptador Cosmos antes dos provedores Open Facts de fallback.

## Preparação do ambiente

1. Opcionalmente, registre Android, iOS/macOS e Web em
   **Firebase Console > App Check** como defesa adicional.
2. Ative políticas TTL para o campo `expiresAt` dos collection groups
   `internal_rate_limits` e `internal_cosmos_cache`, evitando retenção
   indefinida de contadores e entradas expiradas.

A cota global usa o parâmetro inteiro `COSMOS_DAILY_QUOTA`, com padrão 25 e
intervalo permitido de 1 a 10.000. Só aumente o valor depois de confirmar o
plano contratado na Cosmos.

Tokens de debug dão acesso a dispositivos não atestados. Nunca os versione nem
os compartilhe fora do armazenamento seguro da equipe.

## Deploy

```powershell
firebase functions:secrets:set COSMOS_API_TOKEN `
  --project minhascompras-3abbe

firebase deploy --only functions:lookupCosmosProduct `
  --project minhascompras-3abbe
```

O primeiro comando abre um prompt seguro: cole nele o token atual. Não coloque
o valor no repositório, no Flutter ou em parâmetros de compilação.

Para o emulador local:

```powershell
Copy-Item functions/.secret.local.example functions/.secret.local
notepad functions/.secret.local

firebase emulators:start --only auth,firestore,functions `
  --project minhascompras-3abbe

flutter run -d chrome `
  --dart-define=USE_FIREBASE_EMULATORS=true
```

O arquivo `.secret.local` está ignorado pelo Git. O opt-in conecta Auth,
Firestore e Functions aos emuladores antes de construir os repositórios. Se um
token real for usado localmente, o upstream da Cosmos continua sendo externo e
a consulta consome sua cota.

Para Web, uma chave de site reCAPTCHA pode ser informada como proteção opcional:

```powershell
flutter build web --release `
  --dart-define=FIREBASE_WEB_APP_CHECK_SITE_KEY=SUA_CHAVE_PUBLICA
```

## Verificação

```powershell
Set-Location functions
npm ci
npm run check
Set-Location ..
```

Após o deploy, valide:

1. usuário autenticado recebe produto ou `null`;
2. usuário anônimo recebe `unauthenticated`;
3. GTIN inválido recebe `invalid-argument` sem consumir cota;
4. a consulta acima da cota global recebe `resource-exhausted`;
5. hits de cache positivos e negativos não consomem cota;
6. a 31ª consulta da janela por UID é bloqueada quando a cota global configurada
   permite chegar a esse volume;
7. logs não contêm token, GTIN completo, UID, e-mail ou corpo do upstream.

## Rollback

Se a Function apresentar falha, os provedores Open Facts continuam funcionais.
Faça rollback da Function para a versão estável no console. Nunca mova o segredo
para o cliente como contingência.

## Risco aceito do token atual

A decisão atual é reutilizar o token que já existia no projeto. O Secret Manager
impede que novos builds exponham o valor, mas não remove cópias anteriores ou o
histórico Git. A rotação continua disponível como ação futura, sem bloquear o
backend implementado.
