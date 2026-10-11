import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/finance_integration.dart';
import '../core/utils/format_utils.dart';
import 'payment_source_picker_sheet.dart';
import 'theme/editorial_workspace_theme.dart';

class FinanceIntegrationPage extends StatefulWidget {
  const FinanceIntegrationPage({super.key, required this.repository});

  final FinanceIntegrationRepository repository;

  @override
  State<FinanceIntegrationPage> createState() => _FinanceIntegrationPageState();
}

class _FinanceIntegrationPageState extends State<FinanceIntegrationPage> {
  final _codeController = TextEditingController();
  bool _loading = true;
  bool _connected = false;
  FinanceWorkspace? _workspace;
  int _pendingCount = 0;
  String? _error;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final connected = await widget.repository.isConnected();
      if (!mounted) return;
      setState(() => _connected = connected);
      final workspace = connected
          ? await widget.repository.loadWorkspace()
          : null;
      final pending = connected
          ? await widget.repository.pendingPurchaseCount()
          : 0;
      if (!mounted) return;
      setState(() {
        _connected = connected;
        _workspace = workspace;
        _pendingCount = pending;
      });
    } on FinanceIntegrationException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.code == 'NOT_CONNECTED') {
          _connected = false;
          _workspace = null;
          _pendingCount = 0;
        }
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar a integração financeira.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    if (_loading) return;
    final code = _codeController.text.trim();
    if (code.replaceAll('-', '').length != 12) {
      setState(() => _error = 'Informe o código de 12 caracteres.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _feedback = null;
    });
    try {
      await widget.repository.connect(code);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _codeController.clear();
      setState(() {
        _connected = true;
        _feedback = 'Aplicativos conectados com segurança.';
      });
      final workspace = await widget.repository.loadWorkspace();
      final pending = await widget.repository.pendingPurchaseCount();
      if (!mounted) return;
      setState(() {
        _connected = true;
        _workspace = workspace;
        _pendingCount = pending;
        _feedback = 'Aplicativos conectados com segurança.';
      });
      _codeController.clear();
    } on FinanceIntegrationException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          if (error.code == 'NOT_CONNECTED') {
            _connected = false;
            _workspace = null;
            _feedback = null;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _connected
              ? 'Não foi possível carregar os dados financeiros. Atualize para tentar novamente.'
              : 'Não foi possível conectar os aplicativos.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disconnect() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _feedback = null;
    });
    try {
      await widget.repository.disconnect();
      if (!mounted) return;
      setState(() {
        _connected = false;
        _workspace = null;
        _pendingCount = 0;
        _feedback = 'Conexão removida deste dispositivo.';
      });
    } on FinanceIntegrationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível desconectar. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retryPending() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _feedback = null;
    });
    try {
      final synced = await widget.repository.retryPendingPurchases();
      final pending = await widget.repository.pendingPurchaseCount();
      final workspace = await widget.repository.loadWorkspace();
      if (!mounted) return;
      setState(() {
        _pendingCount = pending;
        _workspace = workspace;
        _feedback = synced == 1
            ? '1 lançamento sincronizado.'
            : '$synced lançamentos sincronizados.';
      });
    } on FinanceIntegrationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível sincronizar. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createPaymentSource(BuildContext sheetContext) async {
    final source = await showCreatePaymentSourceSheet(
      sheetContext,
      repository: widget.repository,
    );
    if (!mounted || source == null) return;
    setState(() {
      _feedback = '${source.kind.label} criado no Minhas Finanças.';
      _error = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: editorialWorkspaceTheme(Theme.of(context)),
      child: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          return Scaffold(
            appBar: AppBar(
              title: _connected
                  ? const Text('Minhas Finanças')
                  : const Align(
                      alignment: Alignment.centerRight,
                      child: Text('Minhas Finanças'),
                    ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(height: 1, color: colors.outlineVariant),
              ),
            ),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    padding: _connected
                        ? const EdgeInsets.fromLTRB(16, 20, 16, 24)
                        : const EdgeInsets.fromLTRB(20, 32, 20, 24),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      if (_connected) ...[
                        Text(
                          'Integração externa',
                          style: _sectionStyle(context),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sincronização de saldos e limites com o aplicativo Minhas Finanças.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (_loading) ...[
                        const LinearProgressIndicator(minHeight: 2),
                        const SizedBox(height: 16),
                      ],
                      if (_feedback != null) ...[
                        _StatusMessage(
                          icon: Icons.check_circle_outline,
                          message: _feedback!,
                          isError: false,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_error != null) ...[
                        _StatusMessage(
                          icon: Icons.error_outline,
                          message: _error!,
                          isError: true,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_connected)
                        _buildConnected(context)
                      else
                        _buildConnect(context),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnect(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: colors.primary,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              'Conectar ao Minhas Finanças',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 28,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'No app de Finanças, abra Configurações > Minhas Compras e gere um código temporário.',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 32),
        Text(
          'CÓDIGO DE CONEXÃO',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Código de conexão',
          child: TextField(
            key: const Key('finance_connection_code'),
            controller: _codeController,
            enabled: !_loading,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              letterSpacing: 2,
            ),
            inputFormatters: [_ConnectionCodeFormatter()],
            decoration: InputDecoration(
              hintText: 'ABCD-EFGH-IJKL',
              hintStyle: theme.textTheme.bodySmall?.copyWith(
                fontSize: 14,
                letterSpacing: 2,
              ),
              filled: true,
              fillColor: colors.surfaceContainerLowest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.primary, width: 2),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: (_) => _loading ? null : _connect(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: theme.brightness == Brightness.dark
                ? colors.primary
                : const Color(0xFF365943),
            foregroundColor: theme.brightness == Brightness.dark
                ? colors.surface
                : Colors.white,
            textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _loading ? null : _connect,
          child: const Text('Conectar'),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'O código expira em 10 minutos. A credencial permanente fica protegida no armazenamento seguro do aparelho.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _loading ? null : _load,
            child: const Text('Atualizar conexão'),
          ),
      ],
    );
  }

  Widget _buildConnected(BuildContext context) {
    final workspace = _workspace;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sources =
        workspace?.availablePaymentSources ?? const <FinancePaymentSource>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .06),
            border: Border.all(color: colors.primary.withValues(alpha: .25)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline, size: 20, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conectado',
                      style: _sectionStyle(
                        context,
                      ).copyWith(color: colors.primary),
                    ),
                    if (workspace != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        workspace.householdName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Seus meios ficam disponíveis ao adicionar saldo ou fechar uma compra.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_pendingCount > 0) ...[
          const SizedBox(height: 20),
          Divider(height: 1, color: colors.outlineVariant),
          const SizedBox(height: 12),
          Text(
            _pendingCount == 1
                ? '1 lançamento pendente'
                : '$_pendingCount lançamentos pendentes',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A compra está salva e será enviada sem duplicar.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _loading ? null : _retryPending,
            icon: const Icon(Icons.sync, size: 18),
            label: const Text('Tentar novamente'),
          ),
        ],
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text('Meios de pagamento', style: _sectionStyle(context)),
            if (workspace != null)
              Text(
                '${sources.length} disponíveis',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: colors.outlineVariant),
        if (workspace == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Meios indisponíveis no momento. Atualize para tentar novamente.',
              style: theme.textTheme.bodySmall,
            ),
          )
        else if (sources.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Nenhum cartão, conta ou benefício ativo encontrado no Finanças.',
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          ...sources.map((source) => _FinancePaymentSourceTile(source: source)),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _loading ? null : () => _createPaymentSource(context),
          child: const Text('Novo meio no Finanças'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: _loading ? null : _load,
          child: const Text('Atualizar meios'),
        ),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: colors.error,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: _loading ? null : _disconnect,
          child: const Text('Desconectar deste aparelho'),
        ),
      ],
    );
  }
}

TextStyle _sectionStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall!.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: .6,
      color: Theme.of(context).colorScheme.onSurface,
    );

class _FinancePaymentSourceTile extends StatelessWidget {
  const _FinancePaymentSourceTile({required this.source});
  final FinancePaymentSource source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodySmall;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${source.name}${_digitsLabel(source.lastDigits)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(source.kind.label, style: body),
          const SizedBox(height: 8),
          Text(
            'Disponível: ${formatCurrency(source.availableCents / 100)}',
            style: body?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (source.kind == FinancePaymentSourceKind.credit) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (source.limitCents != null)
                  Text(
                    'Limite: ${formatCurrency(source.limitCents! / 100)}',
                    style: body,
                  ),
                if (source.usedCents != null)
                  Text(
                    'Fatura atual: ${formatCurrency(source.usedCents! / 100)}',
                    style: body,
                  ),
              ],
            ),
            if (source.closingDay != null || source.dueDay != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (source.closingDay != null)
                    'Fecha dia ${source.closingDay}',
                  if (source.dueDay != null) 'vence dia ${source.dueDay}',
                ].join(' • '),
                style: body,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

String _digitsLabel(String? digits) =>
    digits == null || digits.isEmpty ? '' : ' •••• $digits';

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.message,
    required this.isError,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(message)),
        ],
      ),
    );
  }
}

/// Formats the temporary pairing code while retaining the caret during edits.
class _ConnectionCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text
        .replaceAll(RegExp('[^a-zA-Z0-9]'), '')
        .toUpperCase();
    final code = raw.length > 12 ? raw.substring(0, 12) : raw;
    final groups = <String>[];
    for (var index = 0; index < code.length; index += 4) {
      groups.add(code.substring(index, (index + 4).clamp(0, code.length)));
    }
    final formatted = groups.join('-');
    final offset = newValue.selection.extentOffset.clamp(
      0,
      newValue.text.length,
    );
    final before = newValue.text
        .substring(0, offset)
        .replaceAll(RegExp('[^a-zA-Z0-9]'), '')
        .length
        .clamp(0, code.length);
    final caret = before == 0 ? 0 : before + ((before - 1) ~/ 4);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: caret.clamp(0, formatted.length),
      ),
    );
  }
}
