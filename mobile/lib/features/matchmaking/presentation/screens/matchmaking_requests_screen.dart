import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../../discovery/presentation/screens/member_profile_screen.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../data/models/matchmaking_request_model.dart';
import '../providers/matchmaking_provider.dart';

/// Screen 04 (Batch 2A) — Matchmaking Requests Screen (`طلبات التعارف`)
/// تصميم Astra الفاخر لإدارة طلبات التعارف الواردة والمرسلة والمقبولة
/// مع دعم التبويبات الثلاثية والقبول والرفض والإلغاء وفتح المحادثة الفورية.
class MatchmakingRequestsScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const MatchmakingRequestsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<MatchmakingRequestsScreen> createState() =>
      _MatchmakingRequestsScreenState();
}

class _MatchmakingRequestsScreenState
    extends ConsumerState<MatchmakingRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(matchmakingProvider.notifier).loadRequests();
    });
  }

  Future<void> _handleAccept(MatchmakingRequestItemModel item) async {
    final res =
        await ref.read(matchmakingProvider.notifier).acceptRequest(item.id);
    if (!mounted) return;

    if (res.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(res.errorMessage!),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.primaryNavy,
        content: Text('تم قبول طلب التعارف وفتح المحادثة الخاصة بنجاح.'),
      ),
    );

    if (res.conversationId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            conversationId: res.conversationId!,
            initialMemberName: item.member.fullName,
          ),
        ),
      );
    }
  }

  Future<void> _handleReject(MatchmakingRequestItemModel item) async {
    final err =
        await ref.read(matchmakingProvider.notifier).rejectRequest(item.id);
    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text(err)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryNavy,
          content: Text('تم الاعتذار عن طلب التعارف.'),
        ),
      );
    }
  }

  Future<void> _handleCancel(MatchmakingRequestItemModel item) async {
    final err =
        await ref.read(matchmakingProvider.notifier).cancelRequest(item.id);
    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text(err)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryNavy,
          content: Text('تم إلغاء طلب التعارف المرسل.'),
        ),
      );
    }
  }

  void _openMemberProfile(int userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberProfileScreen(memberUserId: userId),
      ),
    );
  }

  void _openConversation(int conversationId, String memberName) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          initialMemberName: memberName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchmakingProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 3,
        initialIndex: widget.initialTabIndex,
        child: Scaffold(
          backgroundColor: AppColors.softBackground,
          body: Column(
            children: [
              // Premium Royal Navy Curved Header with Tabs
              NaseebakCurvedHeader(
                title: 'طلبات التعارف',
                subtitle: 'متابعة وإدارة طلبات التعارف الواردة والمرسلة',
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                    tooltip: 'تحديث الطلبات',
                    onPressed: state.isLoading
                        ? null
                        : () => ref
                            .read(matchmakingProvider.notifier)
                            .loadRequests(),
                  ),
                ],
                bottom: Container(
                  height: 44,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.primaryNavy,
                    unselectedLabelColor: Colors.white.withOpacity(0.85),
                    labelStyle: const TextStyle(
                      fontFamily: NaseebakTypography.fontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: NaseebakTypography.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(
                        key: Key('tab_incoming_requests'),
                        text: 'الواردة',
                      ),
                      Tab(
                        key: Key('tab_sent_requests'),
                        text: 'المرسلة',
                      ),
                      Tab(
                        key: Key('tab_accepted_requests'),
                        text: 'المقبولة',
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: Builder(
                  builder: (context) {
                    if (state.isLoading &&
                        state.incoming.isEmpty &&
                        state.sent.isEmpty &&
                        state.accepted.isEmpty) {
                      return ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: 3,
                        itemBuilder: (_, __) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: NaseebakLoadingSkeleton(
                            height: 120,
                            radius: 20,
                          ),
                        ),
                      );
                    }

                    if (state.errorMessage != null &&
                        state.incoming.isEmpty &&
                        state.sent.isEmpty &&
                        state.accepted.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: NaseebakCard(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 42,
                                  color: AppColors.error,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  state.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryNavy,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  onPressed: () => ref
                                      .read(matchmakingProvider.notifier)
                                      .loadRequests(),
                                  child: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return TabBarView(
                      children: [
                        // 1. Incoming Tab (الواردة)
                        _RequestsListTab(
                          items: state.incoming,
                          emptyMessage: 'لا توجد طلبات تعارف واردة حتى الآن',
                          emptyDescription:
                              'عندما يُرسل لك أحد الأعضاء طلب تعارف جديد، سيظهر هنا للقبول أو الرفض.',
                          emptyIcon: Icons.mark_email_unread_outlined,
                          isMutating: state.isMutating,
                          onRefresh: () => ref
                              .read(matchmakingProvider.notifier)
                              .loadRequests(),
                          onViewProfile: _openMemberProfile,
                          onAccept: _handleAccept,
                          onReject: _handleReject,
                          onCancel: _handleCancel,
                          onOpenChat: _openConversation,
                        ),

                        // 2. Sent Tab (المرسلة)
                        _RequestsListTab(
                          items: state.sent,
                          emptyMessage: 'لم تقم بإرسال أي طلبات تعارف بعد',
                          emptyDescription:
                              'يمكنك تصفح الأعضاء وإرسال طلبات التعارف للشخص المناسب لبدء التواصل.',
                          emptyIcon: Icons.outbox_rounded,
                          isMutating: state.isMutating,
                          onRefresh: () => ref
                              .read(matchmakingProvider.notifier)
                              .loadRequests(),
                          onViewProfile: _openMemberProfile,
                          onAccept: _handleAccept,
                          onReject: _handleReject,
                          onCancel: _handleCancel,
                          onOpenChat: _openConversation,
                        ),

                        // 3. Accepted Tab (المقبولة)
                        _RequestsListTab(
                          items: state.accepted,
                          emptyMessage: 'لا توجد طلبات تعارف مقبولة بعد',
                          emptyDescription:
                              'تظهر هنا الطلبات المقبولة بنجاح للبدء في المحادثات الخاصة الفورية.',
                          emptyIcon: Icons.handshake_outlined,
                          isMutating: state.isMutating,
                          onRefresh: () => ref
                              .read(matchmakingProvider.notifier)
                              .loadRequests(),
                          onViewProfile: _openMemberProfile,
                          onAccept: _handleAccept,
                          onReject: _handleReject,
                          onCancel: _handleCancel,
                          onOpenChat: _openConversation,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestsListTab extends StatelessWidget {
  final List<MatchmakingRequestItemModel> items;
  final String emptyMessage;
  final String emptyDescription;
  final IconData emptyIcon;
  final bool isMutating;
  final Future<void> Function() onRefresh;
  final void Function(int userId) onViewProfile;
  final void Function(MatchmakingRequestItemModel item) onAccept;
  final void Function(MatchmakingRequestItemModel item) onReject;
  final void Function(MatchmakingRequestItemModel item) onCancel;
  final void Function(int conversationId, String memberName) onOpenChat;

  const _RequestsListTab({
    required this.items,
    required this.emptyMessage,
    required this.emptyDescription,
    required this.emptyIcon,
    required this.isMutating,
    required this.onRefresh,
    required this.onViewProfile,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primaryNavy,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          children: [
            Center(
              child: NaseebakEmptyState(
                icon: emptyIcon,
                title: emptyMessage,
                description: emptyDescription,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryNavy,
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return _MatchmakingRequestCard(
            item: item,
            isMutating: isMutating,
            onViewProfile: () => onViewProfile(item.member.userId),
            onAccept: () => onAccept(item),
            onReject: () => onReject(item),
            onCancel: () => onCancel(item),
            onOpenChat: item.conversationId != null
                ? () => onOpenChat(item.conversationId!, item.member.fullName)
                : null,
          );
        },
      ),
    );
  }
}

class _MatchmakingRequestCard extends StatelessWidget {
  final MatchmakingRequestItemModel item;
  final bool isMutating;
  final VoidCallback onViewProfile;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCancel;
  final VoidCallback? onOpenChat;

  const _MatchmakingRequestCard({
    required this.item,
    required this.isMutating,
    required this.onViewProfile,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
    this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final member = item.member;

    return NaseebakCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onViewProfile,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                AuthorizedPhotoAvatar(
                  photoId: member.primaryPhotoId,
                  photoAuthorized: member.photoAuthorized,
                  fallbackName: member.fullName,
                  radius: 28,
                  showGoldBorder: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: NaseebakTypography.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${member.ageYears} سنة • ${member.region.isNotEmpty ? member.region : member.countryOfResidence}',
                        style: const TextStyle(
                          fontFamily: NaseebakTypography.fontFamily,
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item.status == 'accepted'
                        ? AppColors.creamHighlight
                        : AppColors.softBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: item.status == 'accepted'
                          ? AppColors.goldAccent
                          : AppColors.subtleBorder,
                    ),
                  ),
                  child: Text(
                    item.statusLabelAr,
                    style: TextStyle(
                      fontFamily: NaseebakTypography.fontFamily,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: item.status == 'accepted'
                          ? AppColors.primaryNavy
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          if (item.canAccept ||
              item.canReject ||
              item.canCancel ||
              onOpenChat != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.subtleBorder),
            const SizedBox(height: 12),
            Row(
              children: [
                if (item.canAccept)
                  Expanded(
                    child: ElevatedButton(
                      key: Key('request_accept_btn_${item.id}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: isMutating ? null : onAccept,
                      child: const Text(
                        'قبول الطلب',
                        style: TextStyle(
                          fontFamily: NaseebakTypography.fontFamily,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (item.canAccept && item.canReject)
                  const SizedBox(width: 10),
                if (item.canReject)
                  Expanded(
                    child: OutlinedButton(
                      key: Key('request_reject_btn_${item.id}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.subtleBorder),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: isMutating ? null : onReject,
                      child: const Text(
                        'رفض الطلب',
                        style: TextStyle(
                          fontFamily: NaseebakTypography.fontFamily,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (item.canCancel)
                  Expanded(
                    child: OutlinedButton.icon(
                      key: Key('request_cancel_btn_${item.id}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.subtleBorder),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: isMutating ? null : onCancel,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text(
                        'إلغاء الطلب',
                        style: TextStyle(
                          fontFamily: NaseebakTypography.fontFamily,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (onOpenChat != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: onOpenChat,
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 16,
                        color: AppColors.goldAccent,
                      ),
                      label: const Text(
                        'فتح المحادثة',
                        style: TextStyle(
                          fontFamily: NaseebakTypography.fontFamily,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
