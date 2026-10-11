import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils/text_utils.dart';
import '../../theme/editorial_workspace_theme.dart';
import '../../utils/app_modal.dart';
import '../../utils/barcode_scanner_web_compat.dart';

bool shouldStopBarcodeScannerForLifecycle(AppLifecycleState state) {
  return state == AppLifecycleState.inactive;
}

bool shouldUseFullScreenBarcodeScanner({
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) {
  return isWeb || targetPlatform == TargetPlatform.iOS;
}

double barcodeScannerViewportRadius({required bool isFullScreen}) {
  return isFullScreen ? 0 : 8;
}

Duration barcodeScannerRestartDelay({
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) {
  if (isWeb || targetPlatform == TargetPlatform.iOS) {
    return const Duration(milliseconds: 350);
  }
  return Duration.zero;
}

bool shouldRecreateBarcodeScannerOnRestart({
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) {
  return isWeb || targetPlatform == TargetPlatform.iOS;
}

String barcodeScannerRecoveryHint({required bool isWeb}) {
  if (isWeb) {
    return 'Se a tela ficar preta no iPhone, toque em Reabrir câmera. Se estiver usando o app pela Tela de Início, abra-o em uma aba normal do Safari.';
  }

  return 'Escaneamento opcional. Se a tela ficar preta, tente trocar a câmera ou digite manualmente.';
}

String barcodeScannerErrorMessage(
  MobileScannerErrorCode errorCode, {
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) {
  return switch (errorCode) {
    MobileScannerErrorCode.permissionDenied when isWeb =>
      'A câmera está bloqueada. Libere a permissão de câmera deste site no '
          'navegador e toque em Tentar novamente.',
    MobileScannerErrorCode.permissionDenied
        when targetPlatform == TargetPlatform.iOS =>
      'A câmera está bloqueada. Abra Ajustes > Minhas Compras > Câmera, '
          'libere o acesso e volte ao aplicativo.',
    MobileScannerErrorCode.permissionDenied =>
      'A câmera está bloqueada. Abra Configurações > Aplicativos > '
          'Minhas Compras > Permissões > Câmera, libere o acesso e volte '
          'ao aplicativo.',
    MobileScannerErrorCode.unsupported =>
      'Nenhuma câmera compatível foi encontrada neste aparelho.',
    _ =>
      'Não foi possível abrir a câmera. Feche outros aplicativos que usam '
          'a câmera e tente novamente.',
  };
}

Future<String?> showBarcodeScannerSheet(BuildContext context) {
  if (shouldUseFullScreenBarcodeScanner(
    isWeb: kIsWeb,
    targetPlatform: defaultTargetPlatform,
  )) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      PageRouteBuilder<String>(
        fullscreenDialog: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) {
          return const BarcodeScannerPage();
        },
      ),
    );
  }

  return showAppModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: editorialWorkspaceTheme(
      Theme.of(context),
    ).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (context) => const BarcodeScannerSheet(),
  );
}

class BarcodeScannerPage extends StatelessWidget {
  const BarcodeScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: editorialWorkspaceTheme(Theme.of(context)),
      child: const Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(child: BarcodeScannerSheet.fullScreen()),
      ),
    );
  }
}

class BarcodeScannerSheet extends StatefulWidget {
  const BarcodeScannerSheet({super.key}) : fullScreen = false;

  const BarcodeScannerSheet.fullScreen({super.key}) : fullScreen = true;

  final bool fullScreen;

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet>
    with WidgetsBindingObserver {
  late MobileScannerController _controller;
  StreamSubscription<BarcodeCapture>? _subscription;
  bool _handled = false;
  Object? _startError;
  bool _isStarting = false;
  bool _isRestarting = false;
  CameraFacing _lastRequestedFacing = CameraFacing.back;
  int _scannerGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = _createController();
    _listenToController();
    _subscribeToBarcodes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startScanner());
    });
  }

  MobileScannerController _createController() {
    return MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      lensType: CameraLensType.normal,
    );
  }

  void _listenToController() {
    _controller.addListener(_handleControllerState);
  }

  void _handleControllerState() {
    if (!mounted) {
      return;
    }
    final error = _controller.value.error;
    setState(() {
      _startError = error;
    });
  }

  void _subscribeToBarcodes() {
    if (_subscription != null) {
      return;
    }
    _subscription = _controller.barcodes.listen(
      _onDetect,
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _startError = error;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_handleControllerState);
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_disposeController(_controller));
    super.dispose();
  }

  Future<void> _disposeController(MobileScannerController controller) async {
    try {
      await controller.stop();
    } finally {
      await controller.dispose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || !_controller.value.hasCameraPermission) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        _subscribeToBarcodes();
        unawaited(_startScanner());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (shouldStopBarcodeScannerForLifecycle(state)) {
          unawaited(_subscription?.cancel());
          _subscription = null;
          unawaited(_controller.stop());
        }
    }
  }

  Future<void> _startScanner() async {
    await _startScannerWithDirection();
  }

  Future<void> _startScannerWithDirection({
    CameraFacing? cameraDirection,
  }) async {
    if (_isStarting || _controller.value.isRunning) {
      return;
    }
    _isStarting = true;
    try {
      final requestedFacing = cameraDirection ?? _lastRequestedFacing;
      await _controller.start(cameraDirection: requestedFacing);
      await prepareBarcodeScannerWebVideo();
      _lastRequestedFacing = requestedFacing;
      if (mounted &&
          _controller.value.error == null &&
          _controller.value.isRunning &&
          _startError != null) {
        setState(() {
          _startError = null;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _startError = error;
      });
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _restartScanner({CameraFacing? cameraDirection}) async {
    if (_isStarting || _isRestarting) {
      return;
    }

    _isRestarting = true;
    try {
      await _controller.stop();
      final targetPlatform = defaultTargetPlatform;
      final delay = barcodeScannerRestartDelay(
        isWeb: kIsWeb,
        targetPlatform: targetPlatform,
      );
      final recreateSession = shouldRecreateBarcodeScannerOnRestart(
        isWeb: kIsWeb,
        targetPlatform: targetPlatform,
      );
      final previousController = _controller;
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      if (recreateSession) {
        previousController.removeListener(_handleControllerState);
        await _subscription?.cancel();
        _subscription = null;
        await _disposeController(previousController);
        if (!mounted) {
          return;
        }
        _controller = _createController();
        _listenToController();
        _subscribeToBarcodes();
        setState(() {
          _scannerGeneration++;
          _startError = null;
        });
        await WidgetsBinding.instance.endOfFrame;
      }
      await _startScannerWithDirection(cameraDirection: cameraDirection);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _startError = error;
      });
    } finally {
      _isRestarting = false;
    }
  }

  CameraFacing _nextRequestedFacing() {
    return switch (_lastRequestedFacing) {
      CameraFacing.front => CameraFacing.back,
      CameraFacing.back => CameraFacing.front,
      CameraFacing.external || CameraFacing.unknown => CameraFacing.back,
    };
  }

  Future<void> _switchCamera() async {
    if (kIsWeb) {
      final nextFacing = _nextRequestedFacing();
      _lastRequestedFacing = nextFacing;
      await _restartScanner(cameraDirection: nextFacing);
      return;
    }

    try {
      await _controller.switchCamera();
      if (mounted && _startError != null) {
        setState(() {
          _startError = null;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _startError = error;
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      final clean = sanitizeBarcode(raw);
      if (clean == null || clean.isEmpty) {
        continue;
      }
      _handled = true;
      unawaited(_controller.stop());
      Navigator.pop(context, clean);
      return;
    }
  }

  Widget _buildScannerPlaceholder(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Abrindo câmera...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFF3F1EB),
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildScannerError(
    BuildContext context,
    MobileScannerException error,
  ) {
    final message = barcodeScannerErrorMessage(
      error.errorCode,
      isWeb: kIsWeb,
      targetPlatform: defaultTargetPlatform,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF1F211D)),
        const IgnorePointer(
          child: CustomPaint(painter: _BarcodeErrorReticlePainter()),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.videocam_off_rounded,
                  color: const Color(0xFFF3F1EB),
                  size: 26,
                ),
                const SizedBox(height: 10),
                Text(
                  'Câmera indisponível agora',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFA9D0B4),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Semantics(
                  liveRegion: true,
                  child: SelectableText(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFF3F1EB),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF3F1EB),
                    side: const BorderSide(color: Color(0xFF727972)),
                    minimumSize: const Size(0, 48),
                    textStyle: Theme.of(context).textTheme.labelSmall,
                  ),
                  onPressed: () => unawaited(_restartScanner()),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: editorialWorkspaceTheme(Theme.of(context)),
      child: Builder(builder: _buildEditorialScanner),
    );
  }

  Widget _buildEditorialScanner(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final state = _controller.value;
    final active =
        state.isRunning && state.hasCameraPermission && _startError == null;
    final failed = _startError != null;
    final status = active
        ? 'Acesso à câmera concedido e em funcionamento para leitura de códigos'
        : failed
        ? 'Câmera indisponível agora. Tente novamente ou digite manualmente.'
        : 'Aguardando acesso à câmera para leitura de códigos';
    final scanner = Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          key: ValueKey<int>(_scannerGeneration),
          controller: _controller,
          fit: BoxFit.cover,
          tapToFocus: true,
          placeholderBuilder: _buildScannerPlaceholder,
          errorBuilder: _buildScannerError,
        ),
        if (active)
          const IgnorePointer(
            child: CustomPaint(painter: _BarcodeReticlePainter()),
          ),
        if (active)
          Align(
            alignment: const Alignment(0, 0.48),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xCC30312D),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Câmera ativa',
                  style: TextStyle(color: Color(0xFFF3F1EB), fontSize: 11),
                ),
              ),
            ),
          ),
        if (!failed)
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: IconButton(
                tooltip: 'Trocar câmera',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xB330312D),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => unawaited(_switchCamera()),
                icon: const Icon(Icons.cameraswitch_outlined),
              ),
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        final available = max(
          0.0,
          min(constraints.maxHeight, MediaQuery.sizeOf(context).height) -
              keyboard,
        );
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: SizedBox(
            height: widget.fullScreen
                ? available
                : min(available, failed ? 560 : 620),
            child: ColoredBox(
              color: colors.surface,
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Fechar',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                'Leitor de código',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        children: [
                          Text(
                            failed
                                ? 'Aponte para o código de barras'
                                : 'Aponte a câmera para o código de barras do item',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              barcodeScannerViewportRadius(
                                isFullScreen: widget.fullScreen,
                              ),
                            ),
                            child: AspectRatio(
                              aspectRatio: 4 / 3,
                              child: scanner,
                            ),
                          ),
                          if (!failed) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Centralize o código de barras na área demarcada',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Semantics(
                              liveRegion: true,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerLowest,
                                  border: Border.all(
                                    color: colors.outlineVariant,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      active
                                          ? Icons.check_circle_outline
                                          : failed
                                          ? Icons.videocam_off_outlined
                                          : Icons.camera_alt_outlined,
                                      size: 20,
                                      color: failed
                                          ? colors.error
                                          : colors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        status,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (kIsWeb) ...[
                            const SizedBox(height: 12),
                            Text(
                              barcodeScannerRecoveryHint(isWeb: kIsWeb),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      16 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (failed)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () => unawaited(_restartScanner()),
                            icon: const Icon(Icons.videocam_outlined, size: 20),
                            label: const Text('Reabrir câmera'),
                          )
                        else
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () => unawaited(_restartScanner()),
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text('Reabrir câmera'),
                          ),
                        const SizedBox(height: 8),
                        if (failed)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.keyboard_outlined, size: 20),
                            label: const Text('Digitar manualmente'),
                          )
                        else
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.keyboard_outlined, size: 20),
                            label: const Text('Digitar manualmente'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BarcodeErrorReticlePainter extends CustomPainter {
  const _BarcodeErrorReticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final area = (Offset.zero & size).deflate(16);
    final paint = Paint()
      ..color = const Color(0xFF929990)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final corner in [
      (area.topLeft, 1.0, 1.0),
      (area.topRight, -1.0, 1.0),
      (area.bottomLeft, 1.0, -1.0),
      (area.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.$1.dx, corner.$1.dy + 20 * corner.$3)
          ..lineTo(corner.$1.dx, corner.$1.dy)
          ..lineTo(corner.$1.dx + 20 * corner.$2, corner.$1.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarcodeErrorReticlePainter oldDelegate) => false;
}

class _BarcodeReticlePainter extends CustomPainter {
  const _BarcodeReticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTWH(
      size.width * .11,
      size.height * .16,
      size.width * .78,
      size.height * .68,
    );
    final border = Paint()
      ..color = const Color(0x33FBF9F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(area, border);
    final corners = Paint()
      ..color = const Color(0xFFC4ECCF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const length = 16.0;
    for (final entry in [
      (area.topLeft, 1.0, 1.0),
      (area.topRight, -1.0, 1.0),
      (area.bottomLeft, 1.0, -1.0),
      (area.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(entry.$1.dx, entry.$1.dy + length * entry.$3)
          ..lineTo(entry.$1.dx, entry.$1.dy)
          ..lineTo(entry.$1.dx + length * entry.$2, entry.$1.dy),
        corners,
      );
    }
    canvas.drawLine(
      Offset(area.left + 4, area.top + 4),
      Offset(area.right - 4, area.top + 4),
      corners,
    );
  }

  @override
  bool shouldRepaint(_BarcodeReticlePainter oldDelegate) => false;
}
