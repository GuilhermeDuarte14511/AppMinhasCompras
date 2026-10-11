# Validação — 11/10/2026

- 10 testes de splash, carregamento e recursos Android passaram, incluindo desenho ao longo do tempo, movimento reduzido, layout compacto com fonte ampliada, descarte e callback de conclusão.
- Referência visual da nova abertura foi inspecionada e atualizada; testes executados novamente sem atualizar a referência passaram.
- `flutter analyze --no-pub`: sem problemas.
- APK release assinado gerado: versão 1.0.1, build 2006.
- Instalação como atualização no Motorola Edge 50 Fusion via Flutter concluída com sucesso; aplicativo iniciou usando Impeller/Vulkan.
- Verificação do pacote instalado confirmou versionCode 2006 e ausência de flag DEBUGGABLE.
- Logs confirmaram inicialização de Firebase, preferências e hidratação da nuvem. Não foram encontrados erros fatais de inicialização nos logs consultados.
- A fluidez e a aparência no aparelho ainda podem ser conferidas visualmente pelo usuário; a ferramenta de controle de interface desta sessão não oferece a tela do Android.

APK: `build/app/outputs/flutter-apk/MinhasCompras-Moto-Edge-50.apk`.
