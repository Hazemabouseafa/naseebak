import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../messaging/data/services/realtime_messaging_service.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';

/// Screen 14 — Delete Account Screen (`حذف الحساب`)
/// شاشة حذف الحساب الشاملة وفق متطلبات Google Play وسياسات الخصوصية بتصميم نَصِيبُكَ الفاخر
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final TextEditingController _confirmationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _selectedReason = 'found_partner';
  bool _acknowledgedPlayStore = false;
  bool _isProcessing = false;

  @override
  void dispose() {
    _confirmationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _confirmationController.text.trim() == 'حذف' &&
        _acknowledgedPlayStore &&
        !_isProcessing;
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: NaseebakColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: NaseebakColors.errorBorder),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: NaseebakColors.error, size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تأكيد حذف الحساب نهائيًا؟',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: NaseebakColors.textDarkNavy,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'هذا الإجراء نهائي ولا رجعة فيه. سيتم مسح بيانات ملفك وصورك ومحادثاتك بالكامل من نَصِيبُكَ. هل أنت متأكد تمامًا؟',
            style: TextStyle(
              fontSize: 13,
              color: NaseebakColors.textWarmGray,
              height: 1.7,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: NaseebakColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('نعم، احذف حسابي'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      // Disconnect services and sign out
      await ref.read(notificationProvider.notifier).cleanupOnLogout();
      ref.read(realtimeMessagingServiceProvider).disconnect();
      await ref.read(authControllerProvider.notifier).signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: NaseebakColors.primaryNavy,
          content: Text('تم استلام طلب حذف الحساب وجاري معالجة إزالة البيانات.'),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NaseebakColors.backgroundBeige,
        body: Column(
          children: [
            NaseebakCurvedHeader(
              title: 'حذف الحساب',
              subtitle: 'طلب إزالة الحساب والبيانات المرتبطة نهائيًا',
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Critical Consequences Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NaseebakColors.cardBackground,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: NaseebakColors.errorBorder),
                        boxShadow: [
                          BoxShadow(
                            color: NaseebakColors.error.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.warning_rounded,
                                color: NaseebakColors.error,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'تنبيهات هامة قبل المتابعة',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: NaseebakColors.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildConsequenceBullet(
                            'سيتم حذف ملفك التعريفي وصورك وكافة تفضيلاتك نهائيًا.',
                          ),
                          _buildConsequenceBullet(
                            'سيتم إنهاء كافة المحادثات الخاصة وحذف سجل الرسائل.',
                          ),
                          _buildConsequenceBullet(
                            'لن تتمكن من استرجاع هذا الحساب أو سجلاتك بعد التأكيد.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Google Play Subscription Distinction Notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NaseebakColors.accentGoldMuted.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: NaseebakColors.accentGold.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: NaseebakColors.accentGoldDark,
                                size: 22,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تنبيه اشتراكات Google Play',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: NaseebakColors.primaryNavyDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'وفق سياسات متجر Google Play، حذف الحساب في تطبيق نَصِيبُكَ لا يلغي تلقائيًا الاشتراك المالي المجدول في حساب Google الخاص بك. يجب عليك إلغاء الاشتراك يدويًا عبر متجر Google Play لتجنب التجديد الدوري.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: NaseebakColors.textWarmGray,
                              height: 1.65,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Material(
                            color: Colors.transparent,
                            child: CheckboxListTile(
                              key: const Key('play_store_acknowledge_checkbox'),
                              value: _acknowledgedPlayStore,
                              contentPadding: EdgeInsets.zero,
                              activeColor: NaseebakColors.accentGoldDark,
                              title: const Text(
                                'أدرك أنه يجب إلغاء أي اشتراك نشط عبر متجر Google Play بشكل منفصل.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: NaseebakColors.textDarkNavy,
                                ),
                              ),
                              onChanged: (val) {
                                setState(() => _acknowledgedPlayStore = val ?? false);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reason Selector
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NaseebakColors.cardBackground,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: NaseebakColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'سبب طلب الحذف',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: NaseebakColors.textDarkNavy,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedReason,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: NaseebakColors.backgroundBeige,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: NaseebakColors.borderLight,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: NaseebakColors.borderLight,
                                ),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'found_partner',
                                child: Text('وفقني الله ووجدت شريك حياتي'),
                              ),
                              DropdownMenuItem(
                                value: 'privacy_concerns',
                                child: Text('أسباب تتعلق بالخصوصية'),
                              ),
                              DropdownMenuItem(
                                value: 'not_using_app',
                                child: Text('لم أعد أستخدم التطبيق'),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Text('سبب آخر'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedReason = val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'ملاحظات إضافية (اختياري)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: NaseebakColors.textDarkNavy,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'يسعدنا سماع رأيك لتحسين نَصِيبُكَ...',
                              filled: true,
                              fillColor: NaseebakColors.backgroundBeige,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: NaseebakColors.borderLight,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: NaseebakColors.borderLight,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirmation Field
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NaseebakColors.cardBackground,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: NaseebakColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'لتأكيد الحذف، اكتب كلمة "حذف" في الحقل أدناه:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: NaseebakColors.textDarkNavy,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            key: const Key('delete_account_confirmation_input'),
                            controller: _confirmationController,
                            onChanged: (_) => setState(() {}),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: NaseebakColors.error,
                            ),
                            decoration: InputDecoration(
                              hintText: 'اكتب "حذف" هنا للتأكيد',
                              filled: true,
                              fillColor: NaseebakColors.backgroundBeige,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: NaseebakColors.borderLight,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: NaseebakColors.borderLight,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Delete Button
                    ElevatedButton(
                      key: const Key('confirm_delete_account_btn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NaseebakColors.error,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            NaseebakColors.error.withOpacity(0.35),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _canSubmit ? _handleDeleteAccount : null,
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'تأكيد حذف الحساب نهائيًا',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsequenceBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(
              Icons.circle,
              size: 6,
              color: NaseebakColors.error,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: NaseebakColors.textWarmGray,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
