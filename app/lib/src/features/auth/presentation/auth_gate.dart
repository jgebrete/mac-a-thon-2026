import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../router.dart';
import '../../../services/push_notification_service.dart';
import '../../settings/data/user_bootstrap_service.dart';
import '../providers/auth_providers.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _initializedUid;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => _buildMaterial(
        const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stackTrace) => _buildMaterial(
        Scaffold(body: Center(child: Text('Auth error: $error'))),
      ),
      data: (user) {
        if (user == null) {
          _initializedUid = null;
          return _buildMaterial(_SignInScreen(onSignIn: _signInAnonymously));
        }

        if (_initializedUid != user.uid) {
          _initializedUid = user.uid;
          Future<void>.microtask(() async {
            await ref.read(userBootstrapServiceProvider).ensureUserDoc(user.uid);
            await ref
                .read(pushNotificationServiceProvider)
                .initializeAndSyncToken(user.uid);
          });
        }

        final router = ref.watch(goRouterProvider);
        return MaterialApp.router(
          title: 'Smart Food Expiry Tracker',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
          ),
          routerConfig: router,
        );
      },
    );
  }

  MaterialApp _buildMaterial(Widget home) {
    return MaterialApp(
      title: 'Smart Food Expiry Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
      ),
      home: home,
    );
  }

  Future<void> _signInAnonymously() async {
    await ref.read(firebaseAuthProvider).signInAnonymously();
  }
}

class _SignInScreen extends StatelessWidget {
  const _SignInScreen({required this.onSignIn});

  final Future<void> Function() onSignIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: onSignIn,
          child: const Text('Start With Anonymous Login'),
        ),
      ),
    );
  }
}
