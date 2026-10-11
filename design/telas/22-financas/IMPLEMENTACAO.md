# Implementação — Minhas Finanças

Referência: `index.html` e `preview.png` da tela 22 do Stitch.

## Interface

- Superfície marfim, título Newsreader, texto Public Sans, verde folha e separadores discretos.
- Estado de conexão em bloco compacto; meios de pagamento em linhas, sem cartões decorativos.
- Nome real da casa, quantidade real de meios disponíveis, últimos dígitos, tipo e saldo.
- Crédito mantém limite, fatura atual, fechamento e vencimento quando fornecidos pelo serviço. Metadados ausentes não viram zero nem texto `null`.
- Largura máxima de 600 px, rolagem única, controles de 48 dp e adaptação ao tema escuro e texto ampliado.

## Funcionalidades preservadas

- Pareamento com código de 12 caracteres, formatação existente, validação e armazenamento seguro pelo repositório existente.
- Carregamento, estados de erro e feedback, atualização dos meios e desconexão local direta.
- Lançamentos pendentes e nova tentativa de envio sem duplicação.
- Crédito, débito, VA e VR conforme os meios disponíveis no serviço.
- Ação “Novo meio no Finanças” abre o formulário existente e recebe o tema editorial; não foi substituída por link externo.
- Nenhum saldo ilustrativo, nome de banco, opção nova ou indicador fictício de sincronização foi acrescentado. O nome real da casa e os dados de fatura foram mantidos embora o HTML não os exiba.

## Verificação

8 testes em `test/presentation/finance_redesign_test.dart`, além dos 2 testes existentes em `finance_integration_page_test.dart`: **10 aprovados**.

- Capturas de 390 × 884 px dos estados conectado e desconectado, inspecionadas visualmente.
- Pareamento válido e validação do código antes de acessar o serviço.
- Campos opcionais de crédito ausentes sem valores fabricados.
- Nova tentativa de lançamentos, atualização e desconexão pelos métodos existentes.
- Recuperação de erro de carregamento.
- Abertura e envio do formulário existente de criação de meio de pagamento com contexto editorial.
- Tema escuro, 320 × 568 px, texto em escala 1,5; ações alcançáveis e pareamento com teclado aberto.

Testes usam um repositório controlado. Conexão com o aplicativo financeiro e armazenamento seguro reais continuam sujeitos à integração existente em aparelho.
