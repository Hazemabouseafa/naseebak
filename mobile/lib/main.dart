import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/google_sign_in_screen.dart';
import 'features/auth/presentation/screens/suspended_account_screen.dart';
import 'features/auth/presentation/screens/welcome_screen.dart';
import 'features/discovery/presentation/screens/home_discovery_placeholder_screen.dart';
import 'features/profile/presentation/screens/profile_registration_coordinator_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: NaseebakApp(),
    ),
  );
}

class NaseebakApp extends ConsumerWidget {
  const NaseebakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: '${AppStrings.appNameAr} — ${AppStrings.appNameEn}',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: switch (authState.destination) {
        AuthDestination.welcome => const WelcomeScreen(),
        AuthDestination.googleSignIn => const GoogleSignInScreen(),
        AuthDestination.completeProfile =>
          const ProfileRegistrationCoordinatorScreen(),
        AuthDestination.home => const HomeDiscoveryPlaceholderScreen(),
        AuthDestination.suspended => const SuspendedAccountScreen(),
      },
    );
  }
}
