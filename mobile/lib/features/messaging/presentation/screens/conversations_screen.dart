import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../discovery/presentation/widgets/authorized_photo_avatar.dart';
import '../../data/models/conversation_model.dart';
import '../providers/messaging_provider.dart';
import 'chat_screen.dart';

/// Screen 24 — Conversations List Screen (`الرسائل`)
/// تعرض المحادثات الخاصة المصرح بها بعد قبول طلبات التعارف مرتبة بحسب أحدث نشاط.
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messagingProvider.notifier).loadConversations();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 160) {
      final state = ref.read(messagingProvider);
      if (state.hasMoreConversations && !state.isLoadingConversations) {
        ref.read(messagingProvider.notifier).loadConversations(loadMore: true);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagingProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          title: const Text('الرسائل'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'تحديث المحادثات',
              onPressed: () =>
                  ref.read(messagingProvider.notifier).loadConversations(),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.borderLight),
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primaryBlue,
            onRefresh: () =>
                ref.read(messagingProvider.notifier).loadConversations(),
            child: Builder(
              builder: (context) {
                if (state.isLoadingConversations &&
                    state.conversations.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryBlue,
                    ),
                  );
                }

                if (state.conversationsError != null &&
                    state.conversations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 44,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.conversationsError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton(
                            onPressed: () => ref
                                .read(messagingProvider.notifier)
                                .loadConversations(),
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state.conversations.isEmpty) {
                  return ListView(
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
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtleBlue,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 32,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'لا توجد محادثات حتى الآن',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'ستظهر محادثاتك هنا بعد قبول طلبات التعارف.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  key: const Key('conversations_list_view'),
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: state.conversations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final conv = state.conversations[index];
                    return _ConversationListTile(
                      conversation: conv,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChatScreen(
                              conversationId: conv.id,
                              initialMemberName: conv.otherMember.fullName,
                            ),
                          ),
                        );
                        if (mounted) {
                          ref
                              .read(messagingProvider.notifier)
                              .loadConversations();
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationListTile extends StatelessWidget {
  final ConversationSummaryModel conversation;
  final VoidCallback onTap;

  const _ConversationListTile({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final other = conversation.otherMember;
    final hasUnread = conversation.unreadCount > 0;
    final previewText = conversation.lastMessage?.bodyPreview.isNotEmpty == true
        ? conversation.lastMessage!.bodyPreview
        : 'بدأت المحادثة بعد قبول طلب التعارف';
    final timestampLabel = _formatTimestamp(
      conversation.lastMessage?.createdAt ?? conversation.lastMessageAt,
    );

    return InkWell(
      key: Key('conversation_tile_${conversation.id}'),
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasUnread
              ? AppColors.surfaceSubtleBlue.withOpacity(0.55)
              : AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread ? AppColors.primaryBlue : AppColors.borderLight,
            width: hasUnread ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            AuthorizedPhotoAvatar(
              photoId: other.primaryPhotoId,
              photoAuthorized: other.photoAuthorized,
              fallbackName: other.fullName,
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
                          other.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                hasUnread ? FontWeight.w800 : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (timestampLabel.isNotEmpty)
                        Text(
                          timestampLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w500,
                            color: hasUnread
                                ? AppColors.primaryBlue
                                : AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          previewText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w400,
                            color: hasUnread
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          key: Key('unread_badge_${conversation.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            conversation.unreadCount > 99
                                ? '+99'
                                : '${conversation.unreadCount}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final sameDay =
        now.year == dt.year && now.month == dt.month && now.day == dt.day;
    if (sameDay) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${dt.month}/${dt.day}';
  }
}
