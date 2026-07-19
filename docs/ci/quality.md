# CI de qualidade

O workflow `.github/workflows/quality.yml` executa três verificações
independentes em pushes para `main`, pull requests e acionamentos manuais:

- lint tipado, compilação e testes das Cloud Functions;
- análise estática, testes Flutter e build Web release;
- matriz de segurança das regras do Firestore nos emuladores de Auth e
  Firestore.

## Reproduzir localmente

Qualidade Flutter:

```powershell
flutter pub get
flutter analyze --fatal-infos
flutter test --reporter expanded
flutter build web --release
```

Cloud Functions:

```powershell
Set-Location functions
npm ci
npm run check
Set-Location ..
```

Regras de segurança:

```powershell
$env:GCLOUD_PROJECT = 'demo-lista-compras-ci'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
firebase emulators:exec `
  --config firebase.rules-test.json `
  --only auth,firestore `
  --project $env:GCLOUD_PROJECT `
  'pwsh -NoLogo -NoProfile -File ./test/firestore/shared_lists_rules_emulator.ps1'
```

O ambiente de CI usa Flutter 3.44.6, Java 21, Node.js 22 e Firebase CLI
15.23.0. O identificador Firebase começa com `demo-`, portanto os emuladores
recusam acesso acidental a recursos de produção. O workflow não utiliza
segredos e não executa deploy.

O gate de formatação Dart ainda não faz parte do workflow porque o baseline
atual possui arquivos fora do padrão. Ele deve ser ativado depois que esses
arquivos forem normalizados, usando:

```powershell
dart format --output=none --set-exit-if-changed lib test
```
