import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../data/models/support_ticket_model.dart';
import '../../data/repositories/support_repository.dart';
import '../providers/support_provider.dart';
import 'support_tickets_screen.dart';

class SupportTicketDetailScreen extends ConsumerStatefulWidget {
  final int ticketId;
  final SupportTicketModel? initialTicket;

  const SupportTicketDetailScreen({
    super.key,
    required this.ticketId,
    this.initialTicket,
  });

  @override
  ConsumerState<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState
    extends ConsumerState<SupportTicketDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة رد لا يقل عن حرفين.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await ref
          .read(supportTicketDetailProvider(widget.ticketId).notifier)
          .sendReply(text);
      _replyController.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال متابعتك إلى الإدارة بنجاح.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SupportRepository.extractErrorMessage(
              e,
              'تعذر إرسال الرد، يرجى المحاولة مرة أخرى.',
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
    final state = ref.watch(supportTicketDetailProvider(widget.ticketId));
    final ticket = state.ticket ?? widget.initialTicket;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.softBackground,
        body: Column(
          children: [
            NaseebakCurvedHeader(
              title: ticket?.ticketNumber.isNotEmpty == true
                  ? ticket!.ticketNumber
                  : 'تفاصيل الطلب',
              subtitle: ticket?.subject ?? 'محادثة الدعم والتواصل مع الإدارة',
              onBack: () => Navigator.of(context).pop(),
              actions: [
                IconButton(
                  tooltip: 'تحديث الردود',
                  onPressed: () => ref
                      .read(supportTicketDetailProvider(widget.ticketId).notifier)
                      .loadDetail(),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Expanded(
              child: _buildBody(state, ticket),
            ),
            if (ticket != null) _buildBottomComposer(state, ticket),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(SupportTicketDetailState state, SupportTicketModel? ticket) {
    if (state.isLoading && ticket == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          NaseebakLoadingSkeleton(height: 110, radius: 18),
          SizedBox(height: 12),
          NaseebakLoadingSkeleton(height: 150, radius: 18),
          SizedBox(height: 12),
          NaseebakLoadingSkeleton(height: 120, radius: 18),
        ],
      );
    }

    if (ticket == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 46,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? 'تعذر تحميل تفاصيل الطلب.',
                textAlign: TextAlign.center,
                style: NaseebakTypography.bodyText,
              ),
              const SizedBox(height: 16),
              NaseebakSecondaryButton(
                label: 'إعادة المحاولة',
                onPressed: () => ref
                    .read(supportTicketDetailProvider(widget.ticketId).notifier)
                    .loadDetail(),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accentGold,
      onRefresh: () => ref
          .read(supportTicketDetailProvider(widget.ticketId).notifier)
          .loadDetail(),
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: [
          _buildSummaryCard(ticket),
          const SizedBox(height: 14),
          _buildInitialMessageCard(ticket),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ),
          if (ticket.replies.isEmpty && !state.isLoading) ...[
            const SizedBox(height: 14),
            _buildAwaitingReplyBanner(ticket),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              'سجل الردود والمتابعة',
              style: NaseebakTypography.sectionHeading.copyWith(fontSize: 15.5),
            ),
            const SizedBox(height: 10),
            for (final reply in ticket.replies) ...[
              _buildReplyBubble(reply),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(SupportTicketModel ticket) {
    return NaseebakCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SupportTypeBadge(type: ticket.type, label: ticket.typeLabel),
              SupportStatusBadge(status: ticket.status, label: ticket.statusLabel),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtleBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ticket.categoryLabel,
                  style: NaseebakTypography.supportingText.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ticket.subject,
            style: NaseebakTypography.cardTitle.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'تاريخ الإرسال: ${formatSupportDateTime(ticket.createdAtDateTime)}',
                  style: NaseebakTypography.supportingText.copyWith(
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitialMessageCard(SupportTicketModel ticket) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtleBlue,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryBlue.withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'رسالتك الأساسية',
                  style: NaseebakTypography.formLabel.copyWith(
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ticket.message,
            style: NaseebakTypography.bodyText.copyWith(height: 1.65),
          ),
        ],
      ),
    );
  }

  Widget _buildAwaitingReplyBanner(SupportTicketModel ticket) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.creamHighlight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentGold.withOpacity(0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 20,
            color: AppColors.accentGoldDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ticket.isClosed
                  ? 'تم إغلاق هذا الطلب من الإدارة.'
                  : 'تم استلام طلبك بنجاح وهو الآن قيد المراجعة لدى إدارة نَصِيبُكَ. سيصلك إشعار فور الرد عليك.',
              style: NaseebakTypography.supportingText.copyWith(
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBubble(SupportTicketReplyModel reply) {
    final isAdmin = reply.isFromAdmin;

    return Container(
      key: ValueKey('support_reply_${reply.id}'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isAdmin ? AppColors.cardWhite : const Color(0xFFF3F7FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAdmin
              ? AppColors.accentGold.withOpacity(0.65)
              : AppColors.subtleBorder,
          width: isAdmin ? 1.4 : 1,
        ),
        boxShadow: isAdmin
            ? [
                const BoxShadow(
                  color: Color(0x14E8B44D),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAdmin
                    ? Icons.verified_user_rounded
                    : Icons.account_circle_outlined,
                size: 18,
                color: isAdmin
                    ? AppColors.accentGoldDark
                    : AppColors.primaryBlue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reply.senderName,
                  style: NaseebakTypography.formLabel.copyWith(
                    color: isAdmin
                        ? AppColors.primaryNavy
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                formatSupportDateTime(reply.createdAtDateTime),
                style: NaseebakTypography.supportingText.copyWith(
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reply.body,
            style: NaseebakTypography.bodyText.copyWith(height: 1.65),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomComposer(
    SupportTicketDetailState state,
    SupportTicketModel ticket,
  ) {
    if (ticket.isClosed) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: AppColors.cardWhite,
            border: Border(top: BorderSide(color: AppColors.subtleBorder)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تم إغلاق هذا الطلب ولا يمكن إضافة ردود جديدة عليه.',
                  style: NaseebakTypography.supportingText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          border: Border(top: BorderSide(color: AppColors.subtleBorder)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('support_reply_field'),
                controller: _replyController,
                enabled: !state.isSendingReply,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                decoration: InputDecoration(
                  hintText: 'اكتب متابعة أو توضيحًا للإدارة...',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.softBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: AppColors.subtleBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: AppColors.subtleBorder),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 46,
              width: 46,
              child: ElevatedButton(
                key: const Key('btn_send_support_reply'),
                onPressed: state.isSendingReply ? null : _sendReply,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: state.isSendingReply
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
