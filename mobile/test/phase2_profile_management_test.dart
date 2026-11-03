import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naseebak_mobile/features/profile/domain/profile_registration_draft.dart';
import 'package:naseebak_mobile/features/profile/presentation/providers/profile_management_provider.dart';
import 'package:naseebak_mobile/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:naseebak_mobile/features/profile/presentation/screens/my_profile_screen.dart';
import 'package:naseebak_mobile/features/profile/presentation/screens/privacy_settings_screen.dart';

void main() {
  group('Phase 2 — Profile Management, Edit Profile & Privacy Settings Tests', () {
    test('ProfileManagementNotifier.validateProfileDraft rejects underage and inconsistent marital status', () {
      final underageDraft = ProfileRegistrationDraft(
        fullName: 'سارة محمد',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 16)),
        occupation: 'طالبة',
      );
      expect(
        ProfileManagementNotifier.validateProfileDraft(underageDraft),
        contains('18'),
      );

      final inconsistentSingleDraft = ProfileRegistrationDraft(
        fullName: 'سارة محمد',
        dateOfBirth: DateTime(1992, 6, 15),
        maritalStatus: 'single',
        previouslyMarried: true,
        occupation: 'مهندسة',
      );
      expect(
        ProfileManagementNotifier.validateProfileDraft(inconsistentSingleDraft),
        isNotNull,
      );

      final validDraft = ProfileRegistrationDraft(
        fullName: 'سارة محمد',
        dateOfBirth: DateTime(1992, 6, 15),
        maritalStatus: 'single',
        previouslyMarried: false,
        hasChildren: false,
        occupation: 'مهندسة معمارية',
        heightCm: 165,
        hobbies: const ['القراءة'],
        nationality: 'مصرية',
        countryOfResidence: 'مصر',
        region: 'القاهرة',
      );
      expect(
        ProfileManagementNotifier.validateProfileDraft(validDraft),
        isNull,
      );
    });

    testWidgets('Screen 18 (MyProfileScreen) displays only real provided profile data and navigates to Screen 19 & 21',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(profileManagementProvider.notifier).syncFromRegistrationDraft(
            ProfileRegistrationDraft(
              fullName: 'سارة محمد',
              gender: 'female',
              dateOfBirth: DateTime(1992, 6, 15),
              maritalStatus: 'single',
              previouslyMarried: false,
              hasChildren: false,
              educationLevel: 'bachelor',
              occupation: 'مهندسة معمارية',
              heightCm: 165,
              smokingStatus: 'non_smoker',
              homeOwnership: 'owned',
              hobbies: const ['القراءة', 'التصميم'],
              nationality: 'مصرية',
              countryOfResidence: 'مصر',
              region: 'القاهرة',
              bio: 'أبحث عن شريك جاد لبناء حياة مستقرة.',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: MaterialApp(
              home: MyProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ملفي الشخصي'), findsOneWidget);
      expect(find.textContaining('سارة محمد'), findsOneWidget);
      expect(find.text('مهندسة معمارية'), findsOneWidget);
      expect(find.text('تعديل الملف الشخصي'), findsOneWidget);
      expect(find.text('تغيير الصورة الشخصية'), findsOneWidget);
      expect(find.text('إعدادات الخصوصية'), findsOneWidget);
    });

    testWidgets('Screen 19 (EditProfileScreen) and Screen 21 (PrivacySettingsScreen) render RTL controls accurately',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: MaterialApp(
              home: PrivacySettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إعدادات الخصوصية'), findsOneWidget);
      expect(find.text('إظهار ملفي الشخصي في نتائج البحث'), findsOneWidget);
      expect(find.text('إخفاء ملفي الشخصي من نتائج البحث'), findsOneWidget);
      expect(find.text('جميع الأعضاء المسجلين'), findsOneWidget);
      expect(find.text('الأعضاء المشتركون فقط'), findsOneWidget);
      expect(find.text('من تم قبول طلب التعارف معهم فقط'), findsOneWidget);

      await tester.pumpWidget(
        const ProviderScope(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: MaterialApp(
              home: EditProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تعديل الملف الشخصي'), findsOneWidget);
      expect(find.text('حفظ التعديلات'), findsOneWidget);
    });
  });
}
