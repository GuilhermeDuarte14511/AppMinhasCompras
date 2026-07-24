import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils/text_utils.dart';
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
  return isFullScreen ? 0 : 18;
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
    builder: (context) => const BarcodeScannerSheet(),
  );
}

class BarcodeScannerPage extends StatelessWidget {
  const BarcodeScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: BarcodeScannerSheet.fullScreen()),
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
    if (error == _startError) {
      return;
    }
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
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Abrindo câmera...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onInverseSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied when kIsWeb =>
        'A câmera está bloqueada. Libere a permissão deste site no Safari e '
            'toque em Tentar novamente.',
      MobileScannerErrorCode.permissionDenied =>
        'A câmera está bloqueada. Abra Ajustes > Minhas Compras > Câmera, '
            'libere o acesso e volte ao aplicativo.',
      MobileScannerErrorCode.unsupported =>
        'Nenhuma câmera compatível foi encontrada neste aparelho.',
      _ =>
        'Não foi possível abrir a câmera. Feche outros aplicativos que usam '
            'a câmera e tente novamente.',
    };
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_rounded,
                color: colorScheme.onInverseSurface,
                size: 36,
              ),
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: SelectableText(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onInverseSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => unawaited(_restartScanner()),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final scannerRadius = barcodeScannerViewportRadius(
      isFullScreen: widget.fullScreen,
    );
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
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(999),
              ),
              child: IconButton(
                tooltip: 'Trocar câmera',
                onPressed: () => unawaited(_switchCamera()),
                icon: const Icon(
                  Icons.cameraswitch_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        if (_startError != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Câmera indisponível agora. Tente novamente ou digite manualmente.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
    final scannerFrame = scannerRadius == 0
        ? scanner
        : ClipRRect(
            borderRadius: BorderRadius.circular(scannerRadius),
            child: scanner,
          );

    return SizedBox(
      height: widget.fullScreen
          ? MediaQuery.sizeOf(context).height
          : min(MediaQuery.sizeOf(context).height * 0.85, 620),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              'Aponte para o código de barras',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              barcodeScannerRecoveryHint(isWeb: kIsWeb),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: scannerFrame,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_restartScanner()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reabrir câmera'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.keyboard_rounded),
                    label: const Text('Digitar manualmente'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
