import 'dart:developer' as developer;
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/remote/firebase_user_data_repository.dart';
import 'launch.dart';
import 'theme/app_tokens.dart';
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
    this.cacheKey,
  });

  final String? photoUrl;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  final Widget fallback;
  final VoidCallback? onLoadError;
  final int? cacheKey;

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
    if (oldWidget.photoUrl != widget.photoUrl ||
        oldWidget.cacheKey != widget.cacheKey) {
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
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String? userDisplayName;
  final String? userEmail;
  final String? userPhotoUrl;
  final VoidCallback? onSignOut;
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

  @override
  State<AppOptionsPage> createState() => _AppOptionsPageState();
}

class _AppOptionsPageState extends State<AppOptionsPage> {
  late ThemeMode _selectedThemeMode;
  late String _resolvedName;
  late String? _resolvedEmail;
  String? _resolvedPhotoUrl;
  int _photoCacheKey = 0;

  @override
  void initState() {
    super.initState();
    _selectedThemeMode = widget.themeMode;
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
      _photoCacheKey = DateTime.now().millisecondsSinceEpoch;
    });
    final refresh = widget.onProfileUpdated;
    if (refresh != null) {
      await refresh();
    }
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final avatarLabel = _resolvedName.isEmpty
        ? 'U'
        : _resolvedName[0].toUpperCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Opções')),
      body: AppGradientScene(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _AccountContentPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajustes do app',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gerencie conta, aparência, sincronização e ajuda em um só lugar.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildSectionHeader(
                context,
                title: 'Conta',
                subtitle: 'Perfil e sessão',
              ),
              _AccountContentPanel(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _StorageAvatar(
                            key: ValueKey(
                              'options_avatar_${_resolvedPhotoUrl ?? ''}_$_photoCacheKey',
                            ),
                            photoUrl: _resolvedPhotoUrl,
                            radius: 22,
                            backgroundColor: colorScheme.primaryContainer,
                            foregroundColor: colorScheme.onPrimaryContainer,
                            fallback: Text(
                              avatarLabel,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onLoadError: () {
                              if (!mounted) {
                                return;
                              }
                              setState(() {
                                _resolvedPhotoUrl = null;
                              });
                            },
                            cacheKey: _photoCacheKey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _resolvedName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  (_resolvedEmail != null &&
                                          _resolvedEmail!.isNotEmpty)
                                      ? _resolvedEmail!
                                      : 'Conta conectada',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openMyProfile,
                          icon: const Icon(Icons.manage_accounts_rounded),
                          label: const Text('Meus dados'),
                        ),
                      ),
                      if (widget.onSignOut != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onSignOut?.call();
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Deslogar'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildSectionHeader(
                context,
                title: 'Aparência',
                subtitle: 'Tema e preferências visuais',
              ),
              _AccountContentPanel(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tema do App',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Escolha entre modo claro e modo escuro.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded),
                            label: Text('Claro'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded),
                            label: Text('Escuro'),
                          ),
                        ],
                        selected: <ThemeMode>{_selectedThemeMode},
                        onSelectionChanged: (selected) {
                          if (selected.isEmpty) {
                            return;
                          }
                          _updateThemeMode(selected.first);
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedThemeMode == ThemeMode.dark
                            ? 'Modo escuro ativo com contraste reforçado.'
                            : 'Modo claro ativo (visual original).',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildSectionHeader(
                context,
                title: 'Dados',
                subtitle: 'Sincronização e armazenamento',
              ),
              if (widget.showCloudSyncStatus)
                _CloudSyncStatusCard(
                  hasInternetConnection: widget.hasInternetConnection,
                  hasPendingCloudSync: widget.hasPendingCloudSync,
                  isCloudSyncing: widget.isCloudSyncing,
                  lastCloudSyncAt: widget.lastCloudSyncAt,
                  totalRecords: widget.totalSyncRecords,
                  pendingRecords: widget.pendingSyncRecords,
                  listRecords: widget.listRecords,
                  historyRecords: widget.historyRecords,
                  catalogRecords: widget.catalogRecords,
                  compact: false,
                )
              else
                _AccountContentPanel(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Sincronização em nuvem indisponível no momento.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              _buildSectionHeader(
                context,
                title: 'Ajuda',
                subtitle: 'Dicas e suporte',
              ),
              _AccountContentPanel(
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded),
                  title: const Text('Rever Onboarding'),
                  subtitle: const Text(
                    'Veja novamente o tour inicial com as principais dicas.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onReplayOnboarding == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.onReplayOnboarding?.call();
                        },
                ),
              ),
            ],
          ),
        ),
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
        'Falha ao remover foto antiga: $error',
        name: 'profile_photo_cleanup',
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
    } on FirebaseException catch (error) {
      if (!mounted) return;

      final details = (error.message ?? '').trim();
      final suffix = details.isEmpty ? '' : ' - $details';

      _showMessage(
        'Falha ao enviar foto (${error.code})$suffix',
        type: AppToastType.error,
        duration: const Duration(seconds: 6),
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Falha ao enviar foto: $error',
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
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      final details = (error.message ?? '').trim();
      final suffix = details.isEmpty ? '' : ' - $details';
      _showMessage(
        'Falha ao salvar perfil (${error.code})$suffix',
        type: AppToastType.error,
        duration: const Duration(seconds: 6),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      final details = (error.message ?? '').trim();
      final suffix = details.isEmpty ? '' : ' - $details';
      _showMessage(
        'Falha ao salvar dados no banco (${error.code})$suffix',
        type: AppToastType.error,
        duration: const Duration(seconds: 6),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(
        'Falha ao salvar perfil: $error',
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final displayEmail = _cleanNullable(widget.initialEmail);
    final trimmedName = _nameController.text.trim();
    final avatarLabel = trimmedName.isEmpty
        ? 'U'
        : trimmedName.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Meus dados')),
      body: AppGradientScene(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _AccountContentPanel(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Perfil e identidade',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Atualize nome, foto e informações exibidas na sua conta.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _StorageAvatar(
                              key: ValueKey(
                                'profile_avatar_${_photoUrl ?? ''}',
                              ),
                              photoUrl: _photoUrl,
                              radius: 38,
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimaryContainer,
                              fallback: Text(
                                avatarLabel,
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              onLoadError: () {
                                if (!mounted) {
                                  return;
                                }
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Foto de perfil',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Escolha uma nova foto da galeria ou cole uma URL.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isSaving
                                    ? null
                                    : _pickAndUploadPhoto,
                                icon: _isUploadingPhoto
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.photo_library_rounded),
                                label: Text(
                                  _isUploadingPhoto
                                      ? 'Enviando foto...'
                                      : 'Escolher foto',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: (_isSaving || _photoUrl == null)
                                  ? null
                                  : _removePhoto,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Remover'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _AccountInlineInfoBanner(
                          icon: Icons.info_outline_rounded,
                          message:
                              'Se usar uma URL, prefira um link direto e estável para evitar falha no carregamento da foto.',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _photoUrlController,
                          enabled: !_isSaving,
                          decoration: const InputDecoration(
                            labelText: 'URL da foto (opcional)',
                            prefixIcon: Icon(Icons.link_rounded),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _photoUrl = _cleanNullable(value);
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          enabled: !_isSaving,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nome',
                            prefixIcon: Icon(Icons.person_rounded),
                          ),
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
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: displayEmail ?? 'Sem e-mail',
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              _isSaving ? 'Salvando...' : 'Salvar meus dados',
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
    );
  }
}

class _CloudSyncStatusCard extends StatelessWidget {
  const _CloudSyncStatusCard({
    required this.hasInternetConnection,
    required this.hasPendingCloudSync,
    required this.isCloudSyncing,
    required this.lastCloudSyncAt,
    required this.totalRecords,
    required this.pendingRecords,
    required this.listRecords,
    required this.historyRecords,
    required this.catalogRecords,
    required this.compact,
  });

  final bool hasInternetConnection;
  final bool hasPendingCloudSync;
  final bool isCloudSyncing;
  final DateTime? lastCloudSyncAt;
  final int totalRecords;
  final int pendingRecords;
  final int listRecords;
  final int historyRecords;
  final int catalogRecords;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final safeTotal = max(0, totalRecords);
    final safePending = min(max(0, pendingRecords), safeTotal);
    final safeSynced = max(0, safeTotal - safePending);
    final progress = safeTotal == 0 ? 1.0 : safeSynced / safeTotal;
    final status = _resolveStatus(context, pending: safePending);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundGradient = LinearGradient(
      colors: [
        status.color.withValues(alpha: 0.2),
        status.secondaryColor.withValues(alpha: 0.16),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final lastSyncLabel = lastCloudSyncAt == null
        ? 'Nunca sincronizado'
        : 'Última sinc.: ${DateFormat('dd/MM HH:mm').format(lastCloudSyncAt!.toLocal())}';

    return Semantics(
      container: true,
      label:
          'Status da sincronização: ${status.title}. ${status.description}. $safeSynced de $safeTotal registros sincronizados.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: backgroundGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: status.color.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 16,
            compact ? 12 : 14,
            compact ? 14 : 16,
            compact ? 12 : 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: compact ? 42 : 46,
                    height: compact ? 42 : 46,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: compact ? 3.0 : 3.4,
                          backgroundColor: colorScheme.surface.withValues(
                            alpha: 0.45,
                          ),
                          color: status.color,
                        ),
                        Icon(
                          status.icon,
                          color: status.color,
                          size: compact ? 20 : 22,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status.title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (status.showLoading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: status.color,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                status.description,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SyncMetricPill(label: 'Total', value: '$safeTotal'),
                  _SyncMetricPill(label: 'Sincronizados', value: '$safeSynced'),
                  _SyncMetricPill(label: 'Faltando', value: '$safePending'),
                ],
              ),
              const SizedBox(height: 10),
              if (compact)
                Text(
                  '$lastSyncLabel • Listas: $listRecords • histórico: $historyRecords • catálogo: $catalogRecords',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Listas: $listRecords',
                            style: textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'histórico: $historyRecords',
                            style: textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'catálogo: $catalogRecords',
                            style: textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                lastSyncLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (status.showLoading) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    color: status.color,
                    backgroundColor: colorScheme.surface.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _CloudSyncPresentation _resolveStatus(
    BuildContext context, {
    required int pending,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isCloudSyncing) {
      return _CloudSyncPresentation(
        icon: Icons.cloud_upload_rounded,
        color: colorScheme.primary,
        secondaryColor: colorScheme.tertiary,
        title: 'Sincronizando online',
        description: pending > 0
            ? 'Enviando dados para nuvem. Faltam $pending registros.'
            : 'Enviando dados para nuvem.',
        showLoading: true,
      );
    }

    if (!hasInternetConnection) {
      return _CloudSyncPresentation(
        icon: Icons.cloud_off_rounded,
        color: colorScheme.error,
        secondaryColor: colorScheme.errorContainer,
        title: 'Modo offline',
        description: pending > 0
            ? 'Sem internet. $pending registros aguardam conexão.'
            : 'Sem internet. Alterações continuam salvas no aparelho.',
        showLoading: false,
      );
    }

    if (hasPendingCloudSync || pending > 0) {
      return _CloudSyncPresentation(
        icon: Icons.sync_rounded,
        color: colorScheme.primary,
        secondaryColor: colorScheme.secondary,
        title: 'Alterações pendentes',
        description: '$pending registros aguardando sincronização.',
        showLoading: true,
      );
    }

    if (lastCloudSyncAt != null) {
      final formatted = DateFormat(
        'dd/MM HH:mm',
      ).format(lastCloudSyncAt!.toLocal());
      return _CloudSyncPresentation(
        icon: Icons.cloud_done_rounded,
        color: colorScheme.tertiary,
        secondaryColor: colorScheme.primary,
        title: 'Tudo sincronizado',
        description: 'Dados online atualizados em $formatted.',
        showLoading: false,
      );
    }

    return _CloudSyncPresentation(
      icon: Icons.cloud_queue_rounded,
      color: colorScheme.primary,
      secondaryColor: colorScheme.secondary,
      title: 'Pronto para sincronizar',
      description: 'Suas listas serão sincronizadas automaticamente online.',
      showLoading: false,
    );
  }
}

class _CloudSyncPresentation {
  const _CloudSyncPresentation({
    required this.icon,
    required this.color,
    required this.secondaryColor,
    required this.title,
    required this.description,
    required this.showLoading,
  });

  final IconData icon;
  final Color color;
  final Color secondaryColor;
  final String title;
  final String description;
  final bool showLoading;
}

class _SyncMetricPill extends StatelessWidget {
  const _SyncMetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodySmall,
            children: [
              TextSpan(text: '$label: '),
              TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountContentPanel extends StatelessWidget {
  const _AccountContentPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _AccountInlineInfoBanner extends StatelessWidget {
  const _AccountInlineInfoBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.26),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
