abstract interface class AuthenticationGateway {
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signInWithGoogle();
}

class AuthenticationFailure implements Exception {
  const AuthenticationFailure({
    required this.code,
    required this.userMessage,
    this.cause,
  });

  final String code;
  final String userMessage;
  final Object? cause;

  @override
  String toString() => 'AuthenticationFailure($code)';
}
