import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils/text_utils.dart';
import '../../utils/app_modal.dart';

bool shouldStopBarcodeScannerForLifecycle(AppLifecycleState state) {
  return state == AppLifecycleState.inactive;
}

Future<String?> showBarcodeScannerSheet(BuildContext context) {
  return showAppModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const BarcodeScannerSheet(),
  );
}

class BarcodeScannerSheet extends StatefulWidget {
  const BarcodeScannerSheet({super.key});

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  StreamSubscription<BarcodeCapture>? _subscription;
  bool _handled = false;
  Object? _startError;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startScanner());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_controller.stop());
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || !_controller.value.hasCameraPermission) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_startScanner());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (shouldStopBarcodeScannerForLifecycle(state)) {
          unawaited(_controller.stop());
        }
    }
  }

  Future<void> _startScanner() async {
    if (_isStarting || _controller.value.isRunning) {
      return;
    }
    _isStarting = true;
    try {
      await _controller.start();
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
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
      await _startScanner();
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
              Text(
                'Não foi possível abrir a câmera. Verifique a permissão do navegador ou digite o código manualmente.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onInverseSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => unawaited(_startScanner()),
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
    return SizedBox(
      height: min(MediaQuery.sizeOf(context).height * 0.85, 620),
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
              'Escaneamento opcional. Se a tela ficar preta, tente trocar a câmera ou digite manualmente.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      fit: BoxFit.cover,
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
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
                    onPressed: () => unawaited(_startScanner()),
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
