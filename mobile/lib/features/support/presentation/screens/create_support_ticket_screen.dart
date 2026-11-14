import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../data/models/support_ticket_model.dart';
import '../../data/repositories/support_repository.dart';
import '../providers/support_provider.dart';
import 'support_ticket_detail_screen.dart';

class CreateSupportTicketScreen extends ConsumerStatefulWidget {
  final String initialType;

  const CreateSupportTicketScreen({
    super.key,
    this.initialType = 'inquiry',
  });

  @override
  ConsumerState<CreateSupportTicketScreen> createState() =>
      _CreateSupportTicketScreenState();
}

class _CreateSupportTicketScreenState
    extends ConsumerState<CreateSupportTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  late String _selectedType;
  String _selectedCategory = 'general';

  @override
  void initState() {
    super.initState();
    _selectedType =
        widget.initialType == 'complaint' ? 'complaint' : 'inquiry';
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    try {
      final result = await ref.read(supportTicketsProvider.notifier).createTicket(
            type: _selectedType,
            category: _selectedCategory,
            subject: _subjectController.text.trim(),
            message: _messageController.text.trim(),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SupportTicketDetailScreen(
            ticketId: result.ticket.id,
            initialTicket: result.ticket,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SupportRepository.extractErrorMessage(
              e,
              'تعذر إرسال الطلب حاليًا، يرجى المحاولة مرة أخرى.',
            ),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(
      supportTicketsProvider.select((s) => s.isSubmitting),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.softBackground,
        body: Column(
          children: [
            NaseebakCurvedHeader(
              title: 'إرسال استفسار أو شكوى',
              subtitle: 'تصل رسالتك مباشرة إلى فريق إدارة نَصِيبُكَ',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        NaseebakCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'نوع الرسالة',
                                style: NaseebakTypography.formLabel,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTypeChoiceCard(
                                      key: const Key('type_inquiry_btn'),
                                      value: 'inquiry',
                                      title: 'استفسار',
                                      subtitle: 'سؤال أو توضيح',
                                      icon: Icons.help_outline_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildTypeChoiceCard(
                                      key: const Key('type_complaint_btn'),
                                      value: 'complaint',
                                      title: 'شكوى',
                                      subtitle: 'مشكلة أو تظلم',
                                      icon: Icons.report_problem_outlined,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'التصنيف',
                                style: NaseebakTypography.formLabel,
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                key: const Key('support_category_dropdown'),
                                value: _selectedCategory,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.softBackground,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppColors.subtleBorder,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppColors.subtleBorder,
                                    ),
                                  ),
                                ),
                                items: SupportTicketModel.categoryOptions
                                    .map(
                                      (entry) => DropdownMenuItem<String>(
                                        value: entry.key,
                                        child: Text(
                                          entry.value,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: isSubmitting
                                    ? null
                                    : (val) {
                                        if (val != null) {
                                          setState(() => _selectedCategory = val);
                                        }
                                      },
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'عنوان الاستفسار أو الشكوى',
                                style: NaseebakTypography.formLabel,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                key: const Key('support_subject_field'),
                                controller: _subjectController,
                                enabled: !isSubmitting,
                                maxLength: 150,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  hintText: 'مثال: استفسار حول حالة حسابي أو شكوى تقنية',
                                  filled: true,
                                  fillColor: AppColors.softBackground,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppColors.subtleBorder,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppColors.subtleBorder,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  final trimmed = (value ?? '').trim();
                                  if (trimmed.length < 4) {
                                    return 'يرجى كتابة عنوان واضح لا يقل عن 4 أحرف.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'تفاصيل الرسالة للإدارة',
                                style: NaseebakTypography.formLabel,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                key: const Key('support_message_field'),
                                controller: _messageController,
                                enabled: !isSubmitting,
                                minLines: 5,
                                maxLines: 8,
                                maxLength: 3000,
                                decoration: InputDecoration(
                                  hintText:
                                      'اشرح استفسارك أو شكواك بوضوح ليتمكن فريق الإدارة من مساعدتك سريعًا...',
                                  filled: true,
                                  fillColor: AppColors.softBackground,
                                  alignLabelWithHint: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppColors.subtleBorder,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppColors.subtleBorder,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  final trimmed = (value ?? '').trim();
                                  if (trimmed.length < 10) {
                                    return 'يرجى كتابة تفاصيل لا تقل عن 10 أحرف.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtleBlue,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primaryBlue.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                size: 20,
                                color: AppColors.primaryBlue,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'تظهر رسائلك وردود الإدارة بسرية تامة داخل لوحة التحكم الخاصة بإدارة نَصِيبُكَ، ويصلك إشعار فوري عند الرد.',
                                  style: NaseebakTypography.supportingText
                                      .copyWith(
                                    color: AppColors.primaryNavy,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        NaseebakPrimaryButton(
                          buttonKey: const Key('btn_submit_support_ticket'),
                          label: 'إرسال إلى الإدارة',
                          isLoading: isSubmitting,
                          icon: const Icon(Icons.send_rounded, size: 20),
                          onPressed: isSubmitting ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChoiceCard({
    required Key key,
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedType == value;
    final activeColor =
        value == 'complaint' ? AppColors.error : AppColors.primaryBlue;

    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _selectedType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.08)
              : AppColors.softBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.subtleBorder,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? activeColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NaseebakTypography.cardTitle.copyWith(
                      fontSize: 14.5,
                      color: isSelected ? activeColor : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NaseebakTypography.supportingText.copyWith(
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
