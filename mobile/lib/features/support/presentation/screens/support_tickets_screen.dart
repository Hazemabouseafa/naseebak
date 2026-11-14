import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../data/models/support_ticket_model.dart';
import '../providers/support_provider.dart';
import 'create_support_ticket_screen.dart';
import 'support_ticket_detail_screen.dart';

class SupportTicketsScreen extends ConsumerStatefulWidget {
  final bool skipInitialLoad;

  const SupportTicketsScreen({
    super.key,
    this.skipInitialLoad = false,
  });

  @override
  ConsumerState<SupportTicketsScreen> createState() =>
      _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (!widget.skipInitialLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(supportTicketsProvider.notifier).fetchTickets(refresh: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 160) {
      ref.read(supportTicketsProvider.notifier).loadMore();
    }
  }

  Future<void> _openCreateTicket() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CreateSupportTicketScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportTicketsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.softBackground,
        body: Column(
          children: [
            NaseebakCurvedHeader(
              title: 'الاستفسارات والشكاوى',
              subtitle: 'تواصل مباشر مع إدارة نَصِيبُكَ ومتابعة الردود',
              onBack: () => Navigator.of(context).pop(),
              actions: [
                IconButton(
                  tooltip: 'تحديث',
                  onPressed: () => ref
                      .read(supportTicketsProvider.notifier)
                      .fetchTickets(refresh: true),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ],
            ),
            _buildFilterBar(state),
            Expanded(child: _buildBody(state)),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: const BoxDecoration(
              color: AppColors.cardWhite,
              border: Border(top: BorderSide(color: AppColors.subtleBorder)),
            ),
            child: NaseebakPrimaryButton(
              buttonKey: const Key('btn_new_support_ticket'),
              label: 'إرسال استفسار أو شكوى جديد',
              icon: const Icon(Icons.edit_note_rounded, size: 22),
              onPressed: _openCreateTicket,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(SupportTicketsState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterPill(
              key: const Key('filter_support_all'),
              label: 'الكل',
              selected: state.selectedTypeFilter == null,
              onTap: () => ref
                  .read(supportTicketsProvider.notifier)
                  .fetchTickets(typeFilter: null, updateTypeFilter: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterPill(
              key: const Key('filter_support_inquiry'),
              label: 'الاستفسارات',
              selected: state.selectedTypeFilter == 'inquiry',
              onTap: () => ref
                  .read(supportTicketsProvider.notifier)
                  .fetchTickets(typeFilter: 'inquiry', updateTypeFilter: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterPill(
              key: const Key('filter_support_complaint'),
              label: 'الشكاوى',
              selected: state.selectedTypeFilter == 'complaint',
              onTap: () => ref
                  .read(supportTicketsProvider.notifier)
                  .fetchTickets(
                    typeFilter: 'complaint',
                    updateTypeFilter: true,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryNavy : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryNavy : AppColors.subtleBorder,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: NaseebakTypography.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(SupportTicketsState state) {
    if (state.isLoading && state.tickets.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          NaseebakLoadingSkeleton(height: 118, radius: 18),
          SizedBox(height: 12),
          NaseebakLoadingSkeleton(height: 118, radius: 18),
          SizedBox(height: 12),
          NaseebakLoadingSkeleton(height: 118, radius: 18),
        ],
      );
    }

    if (state.errorMessage != null && state.tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 46,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: NaseebakTypography.bodyText,
              ),
              const SizedBox(height: 16),
              NaseebakSecondaryButton(
                label: 'إعادة المحاولة',
                onPressed: () => ref
                    .read(supportTicketsProvider.notifier)
                    .fetchTickets(refresh: true),
              ),
            ],
          ),
        ),
      );
    }

    if (state.tickets.isEmpty) {
      return RefreshIndicator(
        color: AppColors.accentGold,
        onRefresh: () => ref
            .read(supportTicketsProvider.notifier)
            .fetchTickets(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          children: [
            NaseebakEmptyState(
              icon: Icons.support_agent_rounded,
              title: 'لا توجد استفسارات أو شكاوى بعد',
              subtitle:
                  'إذا كان لديك أي استفسار أو شكوى يمكنك إرسالها مباشرة لفريق إدارة نَصِيبُكَ ومتابعة الرد هنا.',
              actionButton: NaseebakSecondaryButton(
                label: 'إرسال أول رسالة للإدارة',
                icon: const Icon(Icons.add_comment_outlined, size: 18),
                onPressed: _openCreateTicket,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accentGold,
      onRefresh: () =>
          ref.read(supportTicketsProvider.notifier).fetchTickets(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        itemCount: state.tickets.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= state.tickets.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentGold,
                ),
              ),
            );
          }

          return _buildTicketCard(state.tickets[index]);
        },
      ),
    );
  }

  Widget _buildTicketCard(SupportTicketModel ticket) {
    return NaseebakCard(
      key: ValueKey('support_ticket_card_${ticket.id}'),
      padding: const EdgeInsets.all(15),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SupportTicketDetailScreen(
              ticketId: ticket.id,
              initialTicket: ticket,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtleBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ticket.ticketNumber,
                  style: const TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
              SupportTypeBadge(type: ticket.type, label: ticket.typeLabel),
              SupportStatusBadge(
                status: ticket.status,
                label: ticket.statusLabel,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ticket.subject,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: NaseebakTypography.cardTitle.copyWith(fontSize: 15.5),
          ),
          const SizedBox(height: 5),
          Text(
            ticket.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: NaseebakTypography.supportingText.copyWith(
              height: 1.45,
              fontSize: 13,
            ),
          ),
          if (ticket.adminReply != null &&
              ticket.adminReply!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF047857).withOpacity(0.22),
                ),
              ),
              child: Text(
                'رد الإدارة: ${ticket.adminReply!.trim()}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: NaseebakTypography.fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF065F46),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${ticket.categoryLabel} • ${formatSupportDateTime(ticket.lastActivityDateTime ?? ticket.createdAtDateTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NaseebakTypography.supportingText.copyWith(
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 14,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 4),
              Text(
                '${ticket.repliesCount}',
                style: const TextStyle(
                  fontFamily: NaseebakTypography.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SupportTypeBadge extends StatelessWidget {
  final String type;
  final String label;

  const SupportTypeBadge({
    super.key,
    required this.type,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isComplaint = type == 'complaint';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isComplaint
            ? const Color(0xFFFEF2F2)
            : AppColors.surfaceSubtleBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: NaseebakTypography.fontFamily,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isComplaint ? AppColors.error : AppColors.primaryBlue,
        ),
      ),
    );
  }
}

class SupportStatusBadge extends StatelessWidget {
  final String status;
  final String label;

  const SupportStatusBadge({
    super.key,
    required this.status,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: SupportTicketModel.statusBgColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: NaseebakTypography.fontFamily,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: SupportTicketModel.statusTextColor(status),
        ),
      ),
    );
  }
}

String formatSupportDateTime(DateTime? dt) {
  if (dt == null) return 'الآن';
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d  $hh:$mm';
}
