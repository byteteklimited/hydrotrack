import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../data/providers/auth_providers.dart';

/// When someone opens a password reset link (which signs them in for
/// that purpose), shows "Set a new password" on top of wherever the app
/// was going.
class PasswordRecoveryListener extends ConsumerStatefulWidget {
  const PasswordRecoveryListener({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<PasswordRecoveryListener> createState() =>
      _PasswordRecoveryListenerState();
}

class _PasswordRecoveryListenerState
    extends ConsumerState<PasswordRecoveryListener> {
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref
        .read(authRepositoryProvider)
        .passwordRecoveries
        .listen(
          (_) => widget.navigatorKey.currentState?.pushNamed(
            AppRoutes.setNewPassword,
          ),
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
