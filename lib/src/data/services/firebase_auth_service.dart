import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  static const String _googleServerClientIdFromDefine = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  bool _googleInitialized = false;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final displayName = name.trim();
    if (displayName.isEmpty) {
      return;
    }
    await credential.user?.updateDisplayName(displayName);
    await credential.user?.reload();
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    final normalizedEmail = email.trim();
    return _sendPasswordResetEmailInternal(normalizedEmail);
  }

  Future<void> _sendPasswordResetEmailInternal(String normalizedEmail) async {
    await _auth.setLanguageCode('pt-BR');
    await _auth.sendPasswordResetEmail(email: normalizedEmail);
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      await _auth.signInWithPopup(provider);
      return;
    }

    try {
      if (!_googleInitialized) {
        final serverClientId = _googleServerClientIdFromDefine.trim();
        await _googleSignIn.initialize(
          serverClientId: serverClientId.isEmpty ? null : serverClientId,
        );
        _googleInitialized = true;
      }

      if (!_googleSignIn.supportsAuthenticate()) {
        await _auth.signInWithProvider(GoogleAuthProvider());
        return;
      }

      final user = await _googleSignIn.authenticate();
      final authentication = user.authentication;
      final idToken = authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        // Fallback to Firebase provider flow when tokens are unavailable.
        await _auth.signInWithProvider(GoogleAuthProvider());
        return;
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return;
      }
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message:
            'Falha no login Google (${error.code.name}). Verifique SHA-1/SHA-256 no Firebase e atualize o google-services.json.',
      );
    } catch (error) {
      throw FirebaseAuthException(
        code: 'google-sign-in-unexpected',
        message: 'Erro inesperado no login Google: $error',
      );
    }
  }

  String friendlyError(FirebaseAuthException error) {
    switch (error.code) {
      case 'google-sign-in-canceled':
        return 'Login Google cancelado.';
      case 'google-sign-in-failed':
      case 'missing-google-id-token':
        return 'Falha no login Google. Confira SHA-1/SHA-256 no Firebase e atualize o google-services.json.';
      case 'google-sign-in-unexpected':
        return 'Erro inesperado no login Google. Verifique configuração Firebase do app Android.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'email-already-in-use':
        return 'Esse e-mail já está em uso.';
      case 'weak-password':
        return 'Senha fraca. Use pelo menos 6 caracteres.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'network-request-failed':
        return 'Sem internet no momento.';
      case 'account-exists-with-different-credential':
        return 'Este e-mail já está vinculado a outro método de login.';
      case 'operation-not-allowed':
        return 'Método de login não habilitado no Firebase.';
      case 'user-disabled':
        return 'Conta desativada. Fale com o suporte.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente em instantes.';
      default:
        return 'Falha de autenticação (${error.code}).';
    }
  }
}
