import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/discovery_provider.dart';

/// Screen 13 (Batch 2B) — Report Member Dialog (`الإبلاغ عن عضو أو رسالة`)
/// نافذة الإبلاغ عن المخالفات وتقديم البلاغات الإدارية بتصميم نَصِيبُكَ الفاخر
class ReportMemberDialog extends ConsumerStatefulWidget {
  final int memberUserId;
  final String memberFullName;
  final int? conversationId;
  final int? messageId;

  const ReportMemberDialog({
    super.key,
    required this.memberUserId,
    required this.memberFullName,
    this.conversationId,
    this.messageId,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int memberUserId,
    required String memberFullName,
    int? conversationId,
    int? messageId,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ReportMemberDialog(
        memberUserId: memberUserId,
        memberFullName: memberFullName,
        conversationId: conversationId,
        messageId: messageId,
      ),
    );
  }

  @override
  ConsumerState<ReportMemberDialog> createState() => _ReportMemberDialogState();
}

class _ReportMemberDialogState extends ConsumerState<ReportMemberDialog> {
  final TextEditingController _detailsController = TextEditingController();
  String _selectedCategory = 'inappropriate_behavior';
  String? _dialogError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final details = _detailsController.text.trim();
    if (details.length < 5) {
      setState(() {
        _dialogError = 'يرجى كتابة تفاصيل كافية لمساعدة الإدارة في مراجعة البلاغ.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _dialogError = null;
    });

    try {
      final err = await ref.read(discoveryProvider.notifier).reportMember(
            memberUserId: widget.memberUserId,
            reasonCategory: _selectedCategory,
            details: details,
            conversationId: widget.conversationId,
            messageId: widget.messageId,
          );

      if (!mounted) return;

      if (err != null) {
        setState(() => _dialogError = err);
      } else {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: NaseebakColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: NaseebakColors.borderLight),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NaseebakColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.flag_rounded,
                color: NaseebakColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.messageId != null
                    ? 'الإبلاغ عن رسالة من ${widget.memberFullName}'
                    : 'الإبلاغ عن ${widget.memberFullName}',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: NaseebakColors.textDarkNavy,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'سبب البلاغ',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: NaseebakColors.textDarkNavy,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedCategory,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: NaseebakColors.backgroundBeige,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NaseebakColors.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NaseebakColors.borderLight),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'inappropriate_behavior',
                    child: Text('سلوك أو محتوى غير لائق'),
                  ),
                  DropdownMenuItem(
                    value: 'harassment',
                    child: Text('إزعاج أو إساءة لفظية'),
                  ),
                  DropdownMenuItem(
                    value: 'scam_attempt',
                    child: Text('محاولة احتيال أو طلب أموال'),
                  ),
                  DropdownMenuItem(
                    value: 'fake_profile',
                    child: Text('بيانات مضللة أو ملف غير حقيقي'),
                  ),
                  DropdownMenuItem(
                    value: 'other',
                    child: Text('سبب آخر'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'تفاصيل البلاغ',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: NaseebakColors.textDarkNavy,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('report_details_input'),
                controller: _detailsController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'يرجى توضيح سبب البلاغ بدقة لمراجعته من فريق الإشراف...',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: NaseebakColors.textMuted,
                  ),
                  filled: true,
                  fillColor: NaseebakColors.backgroundBeige,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NaseebakColors.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NaseebakColors.borderLight),
                  ),
                ),
              ),
              if (_dialogError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _dialogError!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: NaseebakColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: NaseebakColors.textMuted),
            ),
          ),
          ElevatedButton(
            key: const Key('submit_report_dialog_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NaseebakColors.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isSubmitting ? null : _handleSubmit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('إرسال البلاغ'),
          ),
        ],
      ),
    );
  }
}
