import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_routes.dart';
import 'core/constants/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_error_state.dart';
import 'core/widgets/app_loading.dart';
import 'core/widgets/connectivity_banner.dart';
import 'features/auth/view/screens/join_with_invite_screen.dart';
import 'features/auth/view/screens/login_screen.dart';
import 'features/auth/view/screens/sign_up_screen.dart';
import 'features/auth/view/screens/splash_screen.dart';
import 'features/organizations/view/screens/organizations_screen.dart';
import 'features/reports/view/screens/app_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _AppBootstrap()));
}

/// Thrown when a `--dart-define-from-file` override left
/// `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` empty or still holding the
/// `.env.json.example` placeholders. Without this check,
/// [Supabase.initialize] "succeeds" anyway (it doesn't validate the URL),
/// and every request then silently resolves against the app's own
/// dev-server origin instead of Supabase — surfacing later as a
/// confusing 404 on sign-in instead of a clear error at launch.
class MissingSupabaseConfigException implements Exception {
  const MissingSupabaseConfigException();

  @override
  String toString() =>
      'The Supabase settings passed with --dart-define-from-file are '
      'empty or still placeholders. Fill in the hydrotrack project\'s URL '
      'and publishable key in that file, or launch without the flag to use '
      'the built-in hydrotrack project.';
}

/// Connects to Supabase before showing the real app. If the connection
/// fails (no network, DNS hiccup), shows a retry screen instead of
/// crashing on launch.
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late Future<void> _connect;

  @override
  void initState() {
    super.initState();
    _connect = _connectToSupabase();
  }

  Future<void> _connectToSupabase() async {
    if (!SupabaseConfig.isConfigured) {
      throw const MissingSupabaseConfigException();
    }
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }

  void _retry() => setState(() => _connect = _connectToSupabase());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _connect,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: AppLoading()),
          );
        }
        if (snapshot.hasError) {
          final isMissingConfig =
              snapshot.error is MissingSupabaseConfigException;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: Scaffold(
              body: AppErrorState(
                message: isMissingConfig
                    ? '${snapshot.error}'
                    : "Couldn't connect to HydroTrack. Check your internet "
                          'connection and try again.',
                retryLabel: isMissingConfig ? 'Check again' : 'Try again',
                onRetry: _retry,
              ),
            ),
          );
        }
        return const HydroTrackApp();
      },
    );
  }
}

/// Root of the HydroTrack app.
class HydroTrackApp extends StatelessWidget {
  const HydroTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HydroTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.signUp: (context) => const SignUpScreen(),
        AppRoutes.joinWithInvite: (context) => const JoinWithInviteScreen(),
        AppRoutes.organizations: (context) => const OrganizationsScreen(),
        AppRoutes.home: (context) => const AppHomeScreen(),
      },
      builder: (context, child) => Column(
        children: [
          const ConnectivityBanner(),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}
