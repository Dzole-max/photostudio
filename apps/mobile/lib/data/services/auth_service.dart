import 'dart:async';

import 'package:uuid/uuid.dart';

class AuthUser {
  const AuthUser({required this.id, required this.isAnonymous, this.email});

  final String id;
  final bool isAnonymous;
  final String? email;
}

enum SignInMethod { apple, google, email }

/// Authentication. Sign-in is only requested at checkout; before that the
/// app works with an anonymous session.
abstract interface class AuthService {
  AuthUser? get currentUser;

  Stream<AuthUser?> get changes;

  /// Makes sure an (anonymous) session exists.
  Future<AuthUser> ensureSession();

  /// Signs in and links the anonymous session's data to the account.
  /// For [SignInMethod.email] a magic link is sent to [email].
  Future<AuthUser?> signIn(SignInMethod method, {String? email});

  Future<void> signOut();
}

/// Local, in-memory auth used when no Supabase keys are configured.
class FakeAuthService implements AuthService {
  FakeAuthService();

  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get changes => _controller.stream;

  void _set(AuthUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Future<AuthUser> ensureSession() async {
    final existing = _user;
    if (existing != null) return existing;
    final user = AuthUser(id: const Uuid().v4(), isAnonymous: true);
    _set(user);
    return user;
  }

  @override
  Future<AuthUser?> signIn(SignInMethod method, {String? email}) async {
    final base = await ensureSession();
    final resolved = switch (method) {
      SignInMethod.email => email ?? 'you@example.com',
      SignInMethod.apple => 'apple.user@example.com',
      SignInMethod.google => 'google.user@example.com',
    };
    final user = AuthUser(id: base.id, isAnonymous: false, email: resolved);
    _set(user);
    return user;
  }

  @override
  Future<void> signOut() async => _set(null);
}
