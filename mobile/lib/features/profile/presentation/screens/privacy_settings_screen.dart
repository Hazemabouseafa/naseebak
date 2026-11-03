import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/profile_management_provider.dart';

/// Screen 10 (Batch 2B) — Privacy Settings Screen (`إعدادات الخصوصية`)
/// تتيح للعضو التحكم الفوري في ظهور ملفه وصورته بتصميم نَصِيبُكَ الفاخر (Astra Design System)
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  late bool _isVisible;
  late String _photoPrivacy;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileManagementProvider).profile;
    _isVisible = profile?.isVisible ?? true;
    _photoPrivacy = profile?.photoPrivacy ?? 'public';
  }

  Future<void> _savePrivacy() async {
    final success = await ref
        .read(profileManagementProvider.notifier)
        .updatePrivacySettings(
          isVisible: _isVisible,
          photoPrivacy: _photoPrivacy,
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: NaseebakColors.primaryNavy,
          content: Text('تم حفظ وتطبيق إعدادات الخصوصية فوراً.'),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileManagementProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NaseebakColors.backgroundBeige,
        body: Column(
          children: [
            NaseebakCurvedHeader(
              title: 'إعدادات الخصوصية',
              subtitle: 'التحكم التام في ظهور ملفك الشخصي وصورك في نَصِيبُكَ',
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'رجوع',
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Profile Visibility Section
                    const Text(
                      'ظهور الملف الشخصي في البحث',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: NaseebakColors.textDarkNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'تحكم في إمكانية وصول الأعضاء الآخرين إلى ملفك الشخصي أثناء البحث والاستكشاف.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: NaseebakColors.textWarmGray,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _PrivacyRadioCard<bool>(
                      key: const Key('privacy_profile_visible_option'),
                      title: 'إظهار ملفي الشخصي في نتائج البحث',
                      subtitle:
                          'يظهر ملفك للأعضاء المؤهلين حسب معايير البحث مع احترام ضوابط الحظر.',
                      value: true,
                      groupValue: _isVisible,
                      icon: Icons.visibility_outlined,
                      onChanged: (val) => setState(() => _isVisible = val),
                    ),
                    const SizedBox(height: 10),
                    _PrivacyRadioCard<bool>(
                      key: const Key('privacy_profile_hidden_option'),
                      title: 'إخفاء ملفي الشخصي من نتائج البحث',
                      subtitle:
                          'لن يظهر ملفك في البحث العام أو الاكتشاف، مع بقاء محادثاتك الحالية متاحة لك.',
                      value: false,
                      groupValue: _isVisible,
                      icon: Icons.visibility_off_outlined,
                      onChanged: (val) => setState(() => _isVisible = val),
                    ),

                    const SizedBox(height: 24),

                    // 2. Photo Visibility Section
                    const Text(
                      'خصوصية الصورة الشخصية',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: NaseebakColors.textDarkNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'تُحفظ صورتك في مساحة خاصة محمية على خادم نَصِيبُكَ، ولا يتم عرضها إلا للفئة التي تحددها هنا:',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: NaseebakColors.textWarmGray,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _PrivacyRadioCard<String>(
                      key: const Key('photo_privacy_public_option'),
                      title: 'جميع الأعضاء المسجلين',
                      subtitle:
                          'تظهر صورتك الشخصية للأعضاء المسجلين النشطين داخل التطبيق.',
                      value: 'public',
                      groupValue: _photoPrivacy,
                      icon: Icons.people_outline_rounded,
                      onChanged: (val) => setState(() => _photoPrivacy = val),
                    ),
                    const SizedBox(height: 10),
                    _PrivacyRadioCard<String>(
                      key: const Key('photo_privacy_subscribers_option'),
                      title: 'الأعضاء المشتركون فقط',
                      subtitle:
                          'لا تظهر صورتك إلا للأعضاء الذين لديهم اشتراك شهري نشط وموثّق.',
                      value: 'subscribers_only',
                      groupValue: _photoPrivacy,
                      icon: Icons.workspace_premium_outlined,
                      onChanged: (val) => setState(() => _photoPrivacy = val),
                    ),
                    const SizedBox(height: 10),
                    _PrivacyRadioCard<String>(
                      key: const Key('photo_privacy_accepted_matches_option'),
                      title: 'من تم قبول طلب التعارف معهم فقط',
                      subtitle:
                          'تظل صورتك محجوبة عن الجميع حتى توافق بنفسك على طلب التعارف.',
                      value: 'accepted_matches_only',
                      groupValue: _photoPrivacy,
                      icon: Icons.favorite_border_rounded,
                      onChanged: (val) => setState(() => _photoPrivacy = val),
                    ),

                    const SizedBox(height: 20),

                    // Server-side enforcement notice
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: NaseebakColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: NaseebakColors.borderLight),
                        boxShadow: const [
                          BoxShadow(
                            color: NaseebakColors.shadowColor,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: NaseebakColors.accentGoldMuted.withOpacity(0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_user_outlined,
                              color: NaseebakColors.primaryNavy,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'تُطبّق هذه الإعدادات فوراً على خادم نَصِيبُكَ، ويُمنع الأعضاء المحظورون أو الموقوفون من الوصول إلى ملفك أو صورك بشكل قاطع.',
                              style: TextStyle(
                                fontSize: 12,
                                color: NaseebakColors.textWarmGray,
                                height: 1.65,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Save Button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: NaseebakColors.cardBackground,
                border: const Border(top: BorderSide(color: NaseebakColors.borderLight)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                key: const Key('save_privacy_settings_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NaseebakColors.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: state.isSaving ? null : _savePrivacy,
                icon: state.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: NaseebakColors.accentGold,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  state.isSaving
                      ? 'جارٍ حفظ إعدادات الخصوصية...'
                      : 'حفظ إعدادات الخصوصية',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyRadioCard<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final T value;
  final T groupValue;
  final IconData icon;
  final ValueChanged<T> onChanged;

  const _PrivacyRadioCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? NaseebakColors.accentGoldMuted.withOpacity(0.2)
              : NaseebakColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? NaseebakColors.accentGoldDark
                : NaseebakColors.borderLight,
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? NaseebakColors.accentGold.withOpacity(0.06)
                  : NaseebakColors.shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? NaseebakColors.accentGoldMuted.withOpacity(0.35)
                    : NaseebakColors.backgroundBeige,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? NaseebakColors.primaryNavy
                    : NaseebakColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? NaseebakColors.textDarkNavy
                          : NaseebakColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: NaseebakColors.textWarmGray,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            Radio<T>(
              value: value,
              groupValue: groupValue,
              activeColor: NaseebakColors.accentGoldDark,
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ],
        ),
      ),
    );
  }
}
