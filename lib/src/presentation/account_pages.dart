import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../application/sync_diagnostics.dart';
import '../data/finance_integration_dependencies.dart';
import '../data/remote/firebase_user_data_repository.dart';
import 'account/cloud_sync_status_panel.dart';
import 'finance_integration_page.dart';
import 'sync_diagnostics_page.dart';
import 'theme/editorial_workspace_theme.dart';
import 'utils/app_page_route.dart';
import 'utils/app_toast.dart';

class _StorageAvatar extends StatefulWidget {
  const _StorageAvatar({
    super.key,
    required this.photoUrl,
    required this.radius,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.fallback,
    this.onLoadError,
  });

  final String? photoUrl;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  final Widget fallback;
  final VoidCallback? onLoadError;

  @override
  State<_StorageAvatar> createState() => _StorageAvatarState();
}

class _StorageAvatarState extends State<_StorageAvatar> {
  Future<Uint8List?>? _bytesFuture;
  bool _useNetwork = false;
  bool _reportedError = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant _StorageAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _prepare();
    }
  }

  bool _isFirebaseStorageUrl(String url) {
    return url.startsWith('gs://') ||
        url.contains('firebasestorage.googleapis.com') ||
        url.contains('storage.googleapis.com');
  }

  String _stripQuery(String url) {
    final index = url.indexOf('?');
    if (index == -1) {
      return url;
    }
    return url.substring(0, index);
  }

  void _prepare() {
    final url = widget.photoUrl?.trim();
    _reportedError = false;
    if (url == null || url.isEmpty) {
      _useNetwork = false;
      _bytesFuture = null;
      return;
    }
    if (_isFirebaseStorageUrl(url)) {
      _useNetwork = false;
      final cleanUrl = _stripQuery(url);
      _bytesFuture = FirebaseStorage.instance
          .refFromURL(cleanUrl)
          .getData(8 * 1024 * 1024);
      return;
    }
    _useNetwork = true;
    _bytesFuture = null;
  }

  void _notifyErrorOnce() {
    if (_reportedError || widget.onLoadError == null) {
      return;
    }
    _reportedError = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onLoadError?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.photoUrl?.trim();
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor,
        foregroundColor: widget.foregroundColor,
        child: widget.fallback,
      );
    }

    if (_useNetwork) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor,
        foregroundColor: widget.foregroundColor,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (error, stackTrace) => _notifyErrorOnce(),
        child: widget.fallback,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircleAvatar(
            radius: widget.radius,
            backgroundColor: widget.backgroundColor,
            foregroundColor: widget.foregroundColor,
            child: widget.fallback,
          );
        }
        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null || bytes.isEmpty) {
          _notifyErrorOnce();
          return CircleAvatar(
            radius: widget.radius,
            backgroundColor: widget.backgroundColor,
            foregroundColor: widget.foregroundColor,
            child: widget.fallback,
          );
        }
        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.foregroundColor,
          backgroundImage: MemoryImage(bytes),
          child: widget.fallback,
        );
      },
    );
  }
}

class AppOptionsPage extends StatefulWidget {
  const AppOptionsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.autoImportOwnedSharedCatalogs,
    required this.onAutoImportOwnedSharedCatalogsChanged,
    this.syncDiagnostics,
    this.onSyncNow,
    this.onRefreshSyncDiagnostics,
    this.userDisplayName,
    this.userEmail,
    this.userPhotoUrl,
    this.onSignOut,
    this.onProfileUpdated,
    this.onReplayOnboarding,
    this.showCloudSyncStatus = false,
    this.hasInternetConnection = true,
    this.hasPendingCloudSync = false,
    this.isCloudSyncing = false,
    this.lastCloudSyncAt,
    this.totalSyncRecords = 0,
    this.pendingSyncRecords = 0,
    this.listRecords = 0,
    this.historyRecords = 0,
    this.catalogRecords = 0,
    this.pantryRecords = 0,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final bool autoImportOwnedSharedCatalogs;
  final ValueChanged<bool> onAutoImportOwnedSharedCatalogsChanged;
  final SyncDiagnosticsSnapshot? syncDiagnostics;
  final Future<void> Function()? onSyncNow;
  final Future<SyncDiagnosticsSnapshot?> Function()? onRefreshSyncDiagnostics;
  final String? userDisplayName;
  final String? userEmail;
  final String? userPhotoUrl;
  final Future<void> Function()? onSignOut;
  final Future<void> Function()? onProfileUpdated;
  final VoidCallback? onReplayOnboarding;
  final bool showCloudSyncStatus;
  final bool hasInternetConnection;
  final bool hasPendingCloudSync;
  final bool isCloudSyncing;
  final DateTime? lastCloudSyncAt;
  final int totalSyncRecords;
  final int pendingSyncRecords;
  final int listRecords;
  final int historyRecords;
  final int catalogRecords;
  final int pantryRecords;

  @override
  State<AppOptionsPage> createState() => _AppOptionsPageState();
}

class _AppOptionsPageState extends State<AppOptionsPage> {
  late ThemeMode _selectedThemeMode;
  late bool _autoImportOwnedSharedCatalogs;
  late String _resolvedName;
  late String? _resolvedEmail;
  String? _resolvedPhotoUrl;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _selectedThemeMode = widget.themeMode;
    _autoImportOwnedSharedCatalogs = widget.autoImportOwnedSharedCatalogs;
    _resolvedEmail = _cleanNullable(widget.userEmail);
    _resolvedName = _buildResolvedName(
      displayName: _cleanNullable(widget.userDisplayName),
      email: _resolvedEmail,
    );
    _resolvedPhotoUrl = _cleanNullable(widget.userPhotoUrl);
  }

  void _updateThemeMode(ThemeMode mode) {
    if (_selectedThemeMode == mode) {
      return;
    }
    setState(() {
      _selectedThemeMode = mode;
    });
    widget.onThemeModeChanged(mode);
  }

  void _updateAutoImportOwnedSharedCatalogs(bool enabled) {
    if (_autoImportOwnedSharedCatalogs == enabled) {
      return;
    }
    setState(() {
      _autoImportOwnedSharedCatalogs = enabled;
    });
    widget.onAutoImportOwnedSharedCatalogsChanged(enabled);
  }

  String? _cleanNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _buildResolvedName({String? displayName, String? email}) {
    final fallbackName = (email != null && email.contains('@'))
        ? email.split('@').first
        : 'Usuário';
    return (displayName != null && displayName.isNotEmpty)
        ? displayName
        : fallbackName;
  }

  Future<void> _openMyProfile() async {
    final result = await Navigator.push<_ProfileEditorResult>(
      context,
      buildAppPageRoute(
        builder: (_) => MyProfilePage(
          initialDisplayName: _resolvedName,
          initialEmail: _resolvedEmail,
          initialPhotoUrl: _resolvedPhotoUrl,
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _resolvedName = _buildResolvedName(
        displayName: _cleanNullable(result.displayName),
        email: _resolvedEmail,
      );
      _resolvedPhotoUrl = _cleanNullable(result.photoUrl);
    });
    final refresh = widget.onProfileUpdated;
    if (refresh != null) {
      await refresh();
    }
  }

  Future<void> _requestSignOut() async {
    final signOut = widget.onSignOut;
    if (signOut == null || _isSigningOut) {
      return;
    }
    setState(() {
      _isSigningOut = true;
    });
    try {
      await signOut();
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  Future<void> _openSyncDiagnostics() async {
    final snapshot = widget.syncDiagnostics;
    final onSyncNow = widget.onSyncNow;
    if (snapshot == null || onSyncNow == null) {
      return;
    }
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => SyncDiagnosticsPage(
          snapshot: snapshot,
          onSyncNow: onSyncNow,
          onRefreshSnapshot: widget.onRefreshSyncDiagnostics,
        ),
      ),
    );
  }

  Future<void> _openFinanceIntegration() {
    return Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => FinanceIntegrationPage(
          repository: createFinanceIntegrationRepository(),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Material(
            color: theme.colorScheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: .6),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileSummary(BuildContext context) {
    final theme = Theme.of(context);
    final words = _resolvedName
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final initials = words
        .take(2)
        .map((word) => word.characters.first)
        .join()
        .toUpperCase();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StorageAvatar(
            photoUrl: _resolvedPhotoUrl,
            radius: 24,
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.primary,
            fallback: Text(initials, style: theme.textTheme.titleSmall),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _resolvedName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_resolvedEmail != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _resolvedEmail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required String title,
    VoidCallback? onTap,
    String? subtitle,
    IconData icon = Icons.chevron_right,
    bool destructive = false,
    bool busy = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: .45),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          color: onTap == null
                              ? Theme.of(context).disabledColor
                              : destructive
                              ? scheme.error
                              : scheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (busy)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.error,
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 20,
                    color: destructive ? scheme.error : scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: editorialWorkspaceTheme(Theme.of(context)),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final themeModes = <ThemeMode>[
            ThemeMode.light,
            ThemeMode.dark,
            ThemeMode.system,
          ];
          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Text(
                'Opções',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'MercadoNewsreader',
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: .6),
                ),
              ),
            ),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      Text(
                        'Ajustes do app',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 30),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gerenciamento da sua conta, sincronização e preferências visuais.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _section(context, 'Conta', [
                        _profileSummary(context),
                        Divider(
                          height: 1,
                          color: scheme.outlineVariant.withValues(alpha: .4),
                        ),
                        _option(
                          context,
                          title: 'Meus dados',
                          onTap: _openMyProfile,
                        ),
                        if (widget.onSignOut != null)
                          _option(
                            context,
                            title: _isSigningOut ? 'Saindo...' : 'Deslogar',
                            onTap: _isSigningOut ? null : _requestSignOut,
                            icon: Icons.logout,
                            destructive: true,
                            busy: _isSigningOut,
                          ),
                      ]),
                      _section(context, 'Aparência', [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerLow,
                              border: Border.all(color: scheme.outlineVariant),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                for (final mode in themeModes)
                                  Expanded(
                                    child: Semantics(
                                      selected: mode == _selectedThemeMode,
                                      child: TextButton(
                                        onPressed: () => _updateThemeMode(mode),
                                        style: TextButton.styleFrom(
                                          minimumSize: const Size(48, 48),
                                          foregroundColor:
                                              mode == _selectedThemeMode
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant,
                                          backgroundColor:
                                              mode == _selectedThemeMode
                                              ? scheme.surface
                                              : Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              mode == ThemeMode.light
                                                  ? Icons.light_mode_outlined
                                                  : mode == ThemeMode.dark
                                                  ? Icons.dark_mode_outlined
                                                  : Icons
                                                        .brightness_auto_outlined,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                mode == ThemeMode.light
                                                    ? 'Claro'
                                                    : mode == ThemeMode.dark
                                                    ? 'Escuro'
                                                    : 'Sistema',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            _selectedThemeMode == ThemeMode.system
                                ? 'Acompanha o tema do dispositivo'
                                : _selectedThemeMode == ThemeMode.light
                                ? 'Tema claro ativado'
                                : 'Tema escuro ativado',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ]),
                      _section(context, 'Dados', [
                        if (widget.showCloudSyncStatus) ...[
                          const SizedBox(height: 12),
                          CloudSyncStatusPanel(
                            hasInternetConnection: widget.hasInternetConnection,
                            hasPendingCloudSync: widget.hasPendingCloudSync,
                            isCloudSyncing: widget.isCloudSyncing,
                            lastCloudSyncAt: widget.lastCloudSyncAt,
                            totalRecords: widget.totalSyncRecords,
                            pendingRecords: widget.pendingSyncRecords,
                            listRecords: widget.listRecords,
                            historyRecords: widget.historyRecords,
                            catalogRecords: widget.catalogRecords,
                            pantryRecords: widget.pantryRecords,
                            compact: true,
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Sincronização em nuvem indisponível no momento.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        if (widget.syncDiagnostics != null &&
                            widget.onSyncNow != null)
                          _option(
                            context,
                            title: 'Sincronização e diagnóstico',
                            subtitle:
                                'Status, listas compartilhadas e relatório de suporte',
                            onTap: _openSyncDiagnostics,
                          ),

                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: const Text(
                            'Atualizar meu catálogo como dono',
                            style: TextStyle(fontSize: 15),
                          ),
                          subtitle: Text(
                            'Importar produtos adicionados às suas listas compartilhadas.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                          value: _autoImportOwnedSharedCatalogs,
                          onChanged: _updateAutoImportOwnedSharedCatalogs,
                        ),

                        _option(
                          context,
                          title: 'Minhas Finanças',
                          subtitle:
                              'Integração de pagamentos e fechamento contábil.',
                          onTap: _openFinanceIntegration,
                        ),
                      ]),
                      _section(context, 'Ajuda', [
                        _option(
                          context,
                          title: 'Rever Onboarding',
                          icon: Icons.replay,
                          onTap: widget.onReplayOnboarding == null
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  widget.onReplayOnboarding?.call();
                                },
                        ),
                      ]),
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
}

class _ProfileEditorResult {
  const _ProfileEditorResult({
    required this.displayName,
    required this.photoUrl,
  });

  final String displayName;
  final String? photoUrl;
}

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({
    super.key,
    required this.initialDisplayName,
    required this.initialEmail,
    required this.initialPhotoUrl,
    this.firestoreInstance,
  });

  final String initialDisplayName;
  final String? initialEmail;
  final String? initialPhotoUrl;

  /// Instância pré-inicializada do Firestore (necessária na Web para evitar
  /// LateInitializationError com databaseId customizado).
  final FirebaseFirestore? firestoreInstance;

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final FirestoreUserDataRepository _profileRepository;
  late final TextEditingController _nameController;
  late final TextEditingController _photoUrlController;

  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _profileRepository = FirestoreUserDataRepository(
      firestore: widget.firestoreInstance,
    );
    final initialPhoto = _cleanNullable(widget.initialPhotoUrl);
    _photoUrl = initialPhoto;
    _nameController = TextEditingController(text: widget.initialDisplayName);
    _photoUrlController = TextEditingController(text: initialPhoto ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  String? _cleanNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _providerId(User user) {
    for (final info in user.providerData) {
      final providerId = info.providerId.trim();
      if (providerId.isEmpty || providerId == 'firebase') {
        continue;
      }
      return providerId;
    }
    return 'password';
  }

  bool _isFirebaseStorageUrl(String url) {
    return url.startsWith('gs://') ||
        url.contains('firebasestorage.googleapis.com') ||
        url.contains('storage.googleapis.com');
  }

  String _stripQuery(String url) {
    final index = url.indexOf('?');
    if (index == -1) {
      return url;
    }
    return url.substring(0, index);
  }

  Future<void> _deleteOldAvatar({
    required String previousUrl,
    required String uid,
    String? newFullPath,
  }) async {
    final trimmedUrl = previousUrl.trim();
    if (trimmedUrl.isEmpty || !_isFirebaseStorageUrl(trimmedUrl)) {
      return;
    }
    try {
      final previousRef = FirebaseStorage.instance.refFromURL(
        _stripQuery(trimmedUrl),
      );
      if (!previousRef.fullPath.startsWith('users/$uid/profile/')) {
        return;
      }
      if (newFullPath != null && previousRef.fullPath == newFullPath) {
        return;
      }
      await previousRef.delete();
    } catch (error) {
      developer.log(
        'Não foi possível remover a foto antiga.',
        name: 'profile_photo_cleanup',
        error: error,
      );
    }
  }

  void _showMessage(
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    AppToast.show(context, message: message, type: type, duration: duration);
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto || _isSaving) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage(
        'Sessão inválida. Faça login novamente.',
        type: AppToastType.error,
      );
      return;
    }

    try {
      final previousPhotoUrl = _cleanNullable(user.photoURL ?? _photoUrl);
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );

      if (image == null) {
        return;
      }

      setState(() => _isUploadingPhoto = true);

      final bytes = await image.readAsBytes();

      final lowerName = image.name.toLowerCase();
      final isPng = lowerName.endsWith('.png');
      final extension = isPng ? 'png' : 'jpg';
      final contentType = isPng ? 'image/png' : 'image/jpeg';

      final fileName =
          'avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('profile')
          .child(fileName);

      await ref.putData(bytes, SettableMetadata(contentType: contentType));

      final storagePath = 'gs://${ref.bucket}/${ref.fullPath}';

      await user.updatePhotoURL(storagePath);
      await user.reload();

      if (!mounted) return;

      setState(() {
        _photoUrl = storagePath;
        _photoUrlController.text = storagePath;
      });

      if (previousPhotoUrl != null &&
          _stripQuery(previousPhotoUrl) != _stripQuery(storagePath)) {
        await _deleteOldAvatar(
          previousUrl: previousPhotoUrl,
          uid: user.uid,
          newFullPath: ref.fullPath,
        );
      }

      _showMessage('Foto enviada com sucesso.', type: AppToastType.success);
    } on FirebaseException {
      if (!mounted) return;

      _showMessage(
        'Não foi possível enviar a foto. Verifique sua conexão e tente novamente.',
        type: AppToastType.error,
        duration: const Duration(seconds: 6),
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Não foi possível enviar a foto. Tente novamente.',
        type: AppToastType.error,
        duration: const Duration(seconds: 6),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _photoUrl = null;
      _photoUrlController.clear();
    });
  }

  Future<void> _saveProfile() async {
    if (_isSaving || _isUploadingPhoto) {
      return;
    }
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage(
        'Sessão inválida. Faça login novamente.',
        type: AppToastType.error,
      );
      return;
    }

    final name = _nameController.text.trim();
    final photoUrl = _cleanNullable(_photoUrlController.text);

    setState(() {
      _isSaving = true;
    });
    try {
      await user.updateDisplayName(name);
      await user.updatePhotoURL(photoUrl);
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Usuário não encontrado após atualizar perfil.',
        );
      }

      await _profileRepository.saveUserProfile(
        profile: FirestoreUserProfile(
          uid: refreshedUser.uid,
          displayName: refreshedUser.displayName ?? name,
          email: refreshedUser.email,
          photoUrl: refreshedUser.photoURL,
          provider: _providerId(refreshedUser),
        ),
      );

      if (!mounted) {
        return;
      }
      _showMessage(
        'Perfil atualizado com sucesso.',
        type: AppToastType.success,
      );
      Navigator.of(context).pop(
        _ProfileEditorResult(
          displayName: refreshedUser.displayName ?? name,
          photoUrl: refreshedUser.photoURL,
        ),
      );
    } on FirebaseAuthException {
      if (!mounted) {
        return;
      }
      _showMessage(
        'Não foi possível salvar o perfil. Verifique os dados e tente novamente.',
        type: AppToastType.error,
        duration: const Duration(seconds: 6),
      );
    } on FirebaseException {
      if (!mounted) {
        return;
      }
      _showMessage(
        'Não foi possível salvar o perfil. Verifique sua conexão e tente novamente.',
        type: AppToastType.error,
        duration: const Duration(seconds: 6),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(
        'Não foi possível salvar o perfil. Tente novamente.',
        type: AppToastType.error,
        duration: const Duration(seconds: 6),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _profileField(
    BuildContext context,
    String label,
    Widget field, {
    bool uppercase = true,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          uppercase ? label.toUpperCase() : label,
          style: TextStyle(
            fontFamily: 'MercadoPublicSans',
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w600,
            letterSpacing: uppercase ? .6 : 0,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(label: label, child: field),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: editorialWorkspaceTheme(Theme.of(context)),
      child: Builder(builder: _buildEditorialProfile),
    );
  }

  Widget _buildEditorialProfile(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final displayEmail = _cleanNullable(widget.initialEmail);
    final busy = _isSaving || _isUploadingPhoto;
    final trimmedName = _nameController.text.trim();
    final avatarLabel = trimmedName.isEmpty
        ? 'U'
        : trimmedName.substring(0, 1).toUpperCase();
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    InputDecoration fieldDecoration(String label, {String? hint}) =>
        InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: colors.surfaceContainerLowest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: colors.primary),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus dados'),
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: .5),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                children: [
                  Text(
                    'CONTA PESSOAL',
                    style: text.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ficha do titular',
                    style: text.titleLarge?.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Atualize suas informações cadastrais para identificação no caderno e sincronização de compras.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'FOTO DE PERFIL',
                    style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StorageAvatar(
                        key: ValueKey('profile_avatar_${_photoUrl ?? ''}'),
                        photoUrl: _photoUrl,
                        radius: 32,
                        backgroundColor: colors.surfaceContainerLow,
                        foregroundColor: colors.primary,
                        fallback: Text(
                          avatarLabel,
                          style: text.titleLarge?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                        onLoadError: () {
                          if (!mounted) return;
                          setState(() {
                            _photoUrl = null;
                            _photoUrlController.clear();
                          });
                          _showMessage(
                            'Não foi possível carregar a foto.',
                            type: AppToastType.warning,
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Avatar atual',
                              style: text.bodySmall?.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: busy ? null : _pickAndUploadPhoto,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                  ),
                                  icon: _isUploadingPhoto
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.photo_library_outlined,
                                          size: 16,
                                        ),
                                  label: Text(
                                    _isUploadingPhoto
                                        ? 'Enviando foto...'
                                        : 'Escolher foto',
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: busy || _photoUrl == null
                                      ? null
                                      : _removePhoto,
                                  style: TextButton.styleFrom(
                                    foregroundColor: colors.error,
                                    padding: EdgeInsets.zero,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                  ),
                                  label: const Text('Remover'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _profileField(
                    context,
                    'URL da foto (opcional)',
                    TextFormField(
                      key: const Key('profile_photo_url'),
                      controller: _photoUrlController,
                      enabled: !busy,
                      keyboardType: TextInputType.url,
                      style: text.bodyMedium?.copyWith(fontSize: 14),
                      decoration: fieldDecoration(
                        'URL da foto (opcional)',
                        hint: 'https://exemplo.com.br/sua-foto.jpg',
                      ),
                      onChanged: (value) =>
                          setState(() => _photoUrl = _cleanNullable(value)),
                    ),
                    uppercase: false,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use um link direto e estável para a foto.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: .5),
                  ),
                  const SizedBox(height: 20),
                  _profileField(
                    context,
                    'Nome',
                    TextFormField(
                      key: const Key('profile_name'),
                      controller: _nameController,
                      enabled: !busy,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      style: text.bodyMedium?.copyWith(fontSize: 14),
                      decoration: fieldDecoration('Nome'),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.length < 2) {
                          return 'Informe um nome válido.';
                        }
                        if (trimmed.length > 80) {
                          return 'Nome muito longo (máximo 80).';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  _profileField(
                    context,
                    'E-mail',
                    TextFormField(
                      key: const Key('profile_email'),
                      initialValue: displayEmail ?? 'Sem e-mail',
                      readOnly: true,
                      enableInteractiveSelection: true,
                      style: text.bodyMedium?.copyWith(fontSize: 14),
                      decoration: fieldDecoration('E-mail'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : _saveProfile,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      textStyle: const TextStyle(
                        fontFamily: 'MercadoPublicSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: _isSaving
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Salvando...'),
                            ],
                          )
                        : const Text('Salvar alterações'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
