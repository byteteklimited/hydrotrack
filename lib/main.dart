import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_routes.dart';
import 'core/constants/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/brand_palette.dart';
import 'core/widgets/app_error_state.dart';
import 'core/widgets/app_loading.dart';
import 'features/account/view/screens/settings_screen.dart';
import 'features/admin/view/screens/admin_console_screen.dart';
import 'features/auth/view/screens/forgot_password_screen.dart';
import 'features/auth/view/screens/join_with_invite_screen.dart';
import 'features/auth/view/screens/login_screen.dart';
import 'features/auth/view/screens/reset_pin_screen.dart';
import 'features/auth/view/screens/set_new_password_screen.dart';
import 'features/auth/view/screens/sign_up_screen.dart';
import 'features/auth/view/screens/splash_screen.dart';
import 'features/auth/view/widgets/password_recovery_listener.dart';
import 'features/offline/view/screens/sync_status_screen.dart';
import 'features/offline/view/widgets/offline_banner.dart';
import 'features/organizations/data/providers/organization_providers.dart';
import 'features/organizations/view/screens/organizations_screen.dart';
import 'features/reports/view/screens/app_home_screen.dart';
import 'features/subscriptions/view/screens/subscription_screen.dart';
import 'features/subscriptions/view/widgets/subscription_banner.dart';

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
          return const _StatusApp(body: AppLoading());
        }
        if (snapshot.hasError) {
          final isMissingConfig =
              snapshot.error is MissingSupabaseConfigException;
          return _StatusApp(
            body: AppErrorState(
              message: isMissingConfig
                  ? '${snapshot.error}'
                  : "Couldn't connect to HydroTrack. Check your internet "
                        'connection and try again.',
              retryLabel: isMissingConfig ? 'Check again' : 'Try again',
              onRetry: _retry,
            ),
          );
        }
        return const HydroTrackApp();
      },
    );
  }
}

/// The one-screen app shown while connecting or after a failed connection.
/// Ignores the browser's URL (e.g. `#/home` after a reload): this app has
/// no routes, so it would only warn about it.
class _StatusApp extends StatelessWidget {
  const _StatusApp({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(builder: (_) => Scaffold(body: body)),
      ],
    );
  }
}

/// Lets the app-wide banner (which sits above the navigator) open screens.
final _navigatorKey = GlobalKey<NavigatorState>();

/// Root of the HydroTrack app. Inside an organization the whole app wears
/// its brand (colors, and its name in the browser tab); outside one —
/// splash, sign-in, the organization picker — HydroTrack's own.
class HydroTrackApp extends ConsumerWidget {
  const HydroTrackApp({super.key});

  /// Built once per palette, not on every rebuild.
  static final _themes = <BrandPalette, ThemeData>{};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(currentOrganizationProvider);
    final palette = organization?.palette ?? BrandPalette.hydrotrack;
    return MaterialApp(
      title: organization?.name ?? 'HydroTrack',
      debugShowCheckedModeBanner: false,
      theme: _themes.putIfAbsent(palette, () => AppTheme.forBrand(palette)),
      // Always start at the splash screen, whatever the browser's URL says
      // (a reload on `#/home` would otherwise open Home before the session
      // and organization are restored).
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.splash),
          builder: (_) => const SplashScreen(),
        ),
      ],
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.signUp: (context) => const SignUpScreen(),
        AppRoutes.joinWithInvite: (context) => const JoinWithInviteScreen(),
        AppRoutes.organizations: (context) => const OrganizationsScreen(),
        AppRoutes.home: (context) => const AppHomeScreen(),
        AppRoutes.resetPin: (context) => const ResetPinScreen(),
        AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
        AppRoutes.setNewPassword: (context) => const SetNewPasswordScreen(),
        AppRoutes.admin: (context) => const AdminConsoleScreen(),
        AppRoutes.settings: (context) => const SettingsScreen(),
      },
      navigatorKey: _navigatorKey,
      builder: (context, child) => Column(
        children: [
          OfflineBanner(
            onOpenRecords: () => _navigatorKey.currentState?.push(
              MaterialPageRoute<void>(builder: (_) => const SyncStatusScreen()),
            ),
          ),
          SubscriptionBanner(
            onOpenSubscription: () => _navigatorKey.currentState?.push(
              MaterialPageRoute<void>(
                builder: (_) => const SubscriptionScreen(),
              ),
            ),
          ),
          Expanded(
            child: PasswordRecoveryListener(
              navigatorKey: _navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
