import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../discovery/presentation/screens/member_profile_screen.dart';
import '../../../discovery/presentation/widgets/authorized_photo_avatar.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../data/models/matchmaking_request_model.dart';
import '../providers/matchmaking_provider.dart';

/// Screen 13 — Matchmaking Requests Screen (`طلبات التعارف`)
/// تعرض طلبات التعارف الواردة والمرسلة والمقبولة مع إجراءات القبول والرفض والإلغاء وفتح المحادثة.
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
        backgroundColor: AppColors.primaryBlue,
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
          backgroundColor: AppColors.primaryBlue,
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
          backgroundColor: AppColors.primaryBlue,
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
        initialIndex: widget.initialTabIndex.clamp(0, 2),
        child: Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          appBar: AppBar(
            title: const Text('طلبات التعارف'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'تحديث الطلبات',
                onPressed: () =>
                    ref.read(matchmakingProvider.notifier).loadRequests(),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(49),
              child: Column(
                children: [
                  const TabBar(
                    labelColor: AppColors.primaryBlue,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primaryBlue,
                    labelStyle: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                    tabs: [
                      Tab(key: Key('tab_incoming_requests'), text: 'الواردة'),
                      Tab(key: Key('tab_sent_requests'), text: 'المرسلة'),
                      Tab(key: Key('tab_accepted_requests'), text: 'المقبولة'),
                    ],
                  ),
                  Container(height: 1, color: AppColors.borderLight),
                ],
              ),
            ),
          ),
          body: SafeArea(
            child: Builder(
              builder: (context) {
                if (state.isLoading &&
                    state.incoming.isEmpty &&
                    state.sent.isEmpty &&
                    state.accepted.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryBlue,
                    ),
                  );
                }

                return TabBarView(
                  children: [
                    // 1. Incoming Tab (الواردة)
                    _RequestsListTab(
                      items: state.incoming,
                      emptyMessage: 'لا توجد طلبات تعارف واردة حاليًا',
                      emptyIcon: Icons.move_to_inbox_rounded,
                      isMutating: state.isMutating,
                      onRefresh: () =>
                          ref.read(matchmakingProvider.notifier).loadRequests(),
                      onViewProfile: _openMemberProfile,
                      onAccept: _handleAccept,
                      onReject: _handleReject,
                      onCancel: _handleCancel,
                      onOpenChat: _openConversation,
                    ),

                    // 2. Sent Tab (المرسلة)
                    _RequestsListTab(
                      items: state.sent,
                      emptyMessage: 'لم تقم بإرسال طلبات تعارف بعد',
                      emptyIcon: Icons.outbox_rounded,
                      isMutating: state.isMutating,
                      onRefresh: () =>
                          ref.read(matchmakingProvider.notifier).loadRequests(),
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
                      emptyIcon: Icons.handshake_outlined,
                      isMutating: state.isMutating,
                      onRefresh: () =>
                          ref.read(matchmakingProvider.notifier).loadRequests(),
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
        ),
      ),
    );
  }
}

class _RequestsListTab extends StatelessWidget {
  final List<MatchmakingRequestItemModel> items;
  final String emptyMessage;
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
        color: AppColors.primaryBlue,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 110),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtleBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        emptyIcon,
                        size: 30,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryBlue,
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

    return Container(
      key: Key('matchmaking_request_card_${item.id}'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AuthorizedPhotoAvatar(
                photoId: member.primaryPhotoId,
                photoAuthorized: member.photoAuthorized,
                fallbackName: member.fullName,
                radius: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${member.fullName} • ${member.ageYears} سنة',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _StatusBadge(
                          status: item.status,
                          label: item.statusLabelAr,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${member.maritalStatusLabelAr} • ${member.region}، ${member.countryOfResidence}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: Key('request_view_profile_${item.id}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(110, 40),
                ),
                onPressed: onViewProfile,
                icon: const Icon(Icons.person_outline_rounded, size: 17),
                label: const Text('عرض الملف'),
              ),
              if (item.canAccept)
                ElevatedButton.icon(
                  key: Key('request_accept_btn_${item.id}'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(105, 40),
                    backgroundColor: AppColors.primaryBlue,
                  ),
                  onPressed: isMutating ? null : onAccept,
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: const Text('قبول'),
                ),
              if (item.canReject)
                OutlinedButton.icon(
                  key: Key('request_reject_btn_${item.id}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(95, 40),
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: isMutating ? null : onReject,
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: const Text('رفض'),
                ),
              if (item.canCancel)
                OutlinedButton.icon(
                  key: Key('request_cancel_btn_${item.id}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(115, 40),
                    foregroundColor: AppColors.error,
                  ),
                  onPressed: isMutating ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 17),
                  label: const Text('إلغاء الطلب'),
                ),
              if (item.status == 'accepted' && onOpenChat != null)
                ElevatedButton.icon(
                  key: Key('request_open_chat_btn_${item.id}'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(130, 40),
                    backgroundColor: AppColors.primaryBlue,
                  ),
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  label: const Text('فتح المحادثة'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final String label;

  const _StatusBadge({
    required this.status,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = switch (status) {
      'accepted' => const Color(0xFFE8F7EE),
      'rejected' || 'cancelled' => const Color(0xFFFDECEC),
      _ => AppColors.surfaceSubtleYellow,
    };
    final textColor = switch (status) {
      'accepted' => const Color(0xFF157F3B),
      'rejected' || 'cancelled' => AppColors.error,
      _ => AppColors.primaryBlueDark,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}
