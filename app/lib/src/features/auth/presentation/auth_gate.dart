import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../router.dart';
import '../../../services/push_notification_service.dart';
import '../../../theme/app_theme.dart';
import '../../settings/data/user_bootstrap_service.dart';
import '../../settings/providers/user_settings_providers.dart';
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
    final themeMode = ref.watch(appThemeModeProvider);

    return authState.when(
      loading: () => _buildMaterial(
        const Scaffold(body: Center(child: CircularProgressIndicator())),
        themeMode,
      ),
      error: (error, stackTrace) => _buildMaterial(
        Scaffold(body: Center(child: Text('Auth error: $error'))),
        themeMode,
      ),
      data: (user) {
        if (user == null) {
          _initializedUid = null;
          return _buildMaterial(_SignInScreen(onSignIn: _signInAnonymously), themeMode);
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
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          routerConfig: router,
        );
      },
    );
  }

  MaterialApp _buildMaterial(Widget home, ThemeMode themeMode) {
    return MaterialApp(
      title: 'Smart Food Expiry Tracker',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
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
