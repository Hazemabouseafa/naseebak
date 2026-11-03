import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naseebak_mobile/core/theme/app_theme.dart';
import 'package:naseebak_mobile/features/auth/presentation/screens/suspended_account_screen.dart';
import 'package:naseebak_mobile/features/profile/domain/profile_registration_draft.dart';
import 'package:naseebak_mobile/features/profile/presentation/screens/profile_registration_coordinator_screen.dart';
import 'package:naseebak_mobile/main.dart';

void main() {
  group('Phase 1 — Naseebak Branding, Google Sign-In & Profile Validation Tests', () {
    test('ProfileRegistrationDraft calculates exact age and Arabic zodiac sign', () {
      final draft = ProfileRegistrationDraft(
        fullName: 'سارة محمد',
        dateOfBirth: DateTime(1987, 6, 15),
      );

      expect(draft.calculatedZodiacSignAr, equals('الجوزاء'));
      expect(draft.calculatedAgeYears, greaterThanOrEqualTo(38));
    });

    testWidgets('WelcomeScreen renders Naseebak Arabic RTL identity & Google Sign-In CTA',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NaseebakApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('نصيبك'), findsOneWidget);
      expect(find.text('المتابعة باستخدام Google'), findsOneWidget);
      expect(find.text('مخصص حصرياً للبالغين من 18 عاماً فأكثر'), findsOneWidget);

      // Navigate to Google Sign-In Screen (Screen 02)
      await tester.tap(find.byKey(const Key('welcome_continue_google_btn')));
      await tester.pumpAndSettle();

      expect(find.text('المتابعة بحساب Google الخاص بك'), findsOneWidget);
    });

    testWidgets(
      'SuspendedAccountScreen and 4-Step ProfileRegistrationCoordinatorScreen render accurately in RTL',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Directionality(
                textDirection: TextDirection.rtl,
                child: SuspendedAccountScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SuspendedAccountScreen), findsOneWidget);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Directionality(
                textDirection: TextDirection.rtl,
                child: ProfileRegistrationCoordinatorScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProfileRegistrationCoordinatorScreen), findsOneWidget);
      },
    );
  });
}
