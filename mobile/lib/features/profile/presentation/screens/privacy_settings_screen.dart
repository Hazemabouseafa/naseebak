import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/profile_management_provider.dart';

/// 21. Privacy Settings Screen (إعدادات الخصوصية)
/// تتيح للعضو التحكم الفوري في:
/// 1. ظهور الملف الشخصي في نتائج البحث (إظهار / إخفاء)
/// 2. خصوصية الصورة الشخصية:
///    - جميع الأعضاء المسجلين (public)
///    - الأعضاء المشتركون فقط (subscribers_only)
///    - من تم قبول طلب التعارف معهم فقط (accepted_matches_only)
/// تُحفظ الإعدادات في PostgreSQL وتُطبّق فوراً على الخادم في كل طلب لاحق.
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
          backgroundColor: AppColors.primaryBlue,
          content: Text('تم حفظ وتطبيق إعدادات الخصوصية فوراً.'),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileManagementProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'رجوع',
        ),
        title: const Text('إعدادات الخصوصية'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Profile Visibility Section
                    const Text(
                      'ظهور الملف الشخصي في البحث',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'تحكم في إمكانية وصول الأعضاء الآخرين إلى ملفك الشخصي أثناء البحث والاستكشاف.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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

                    const SizedBox(height: 26),

                    // 2. Photo Visibility Section
                    const Text(
                      'خصوصية الصورة الشخصية',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'تُحفظ صورتك في مساحة خاصة محمية على خادم نَصِيبُكَ، ولا يتم عرضها إلا للفئة التي تحددها هنا:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: AppColors.primaryBlue,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'تُطبّق هذه الإعدادات فوراً على خادم نَصِيبُكَ، ويُمنع الأعضاء المحظورون أو الموقوفون من الوصول إلى ملفك أو صورك بشكل قاطع.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
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
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: const BoxDecoration(
                color: AppColors.backgroundPrimary,
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: ElevatedButton.icon(
                key: const Key('save_privacy_settings_btn'),
                onPressed: state.isSaving ? null : _savePrivacy,
                icon: state.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 19),
                label: Text(
                  state.isSaving
                      ? 'جارٍ حفظ إعدادات الخصوصية...'
                      : 'حفظ إعدادات الخصوصية',
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
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.surfaceSubtleBlue
              : AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 22,
              color:
                  isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? AppColors.darkBlue
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            Radio<T>(
              value: value,
              groupValue: groupValue,
              activeColor: AppColors.primaryBlue,
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
