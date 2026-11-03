import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../data/models/conversation_model.dart';
import '../providers/messaging_provider.dart';
import 'chat_screen.dart';

/// Screen 24 — Conversations List Screen (`الرسائل`)
/// تعرض المحادثات الخاصة المصرح بها بعد قبول طلبات التعارف بتصميم نَصِيبُكَ الفاخر
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
        backgroundColor: NaseebakColors.backgroundBeige,
        body: Column(
          children: [
            NaseebakCurvedHeader(
              title: 'الرسائل',
              subtitle: 'محادثاتك الخاصة المصرح بها بعد قبول طلبات التعارف',
              trailing: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                  tooltip: 'تحديث المحادثات',
                  onPressed: () =>
                      ref.read(messagingProvider.notifier).loadConversations(),
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                color: NaseebakColors.accentGold,
                backgroundColor: NaseebakColors.primaryNavy,
                onRefresh: () =>
                    ref.read(messagingProvider.notifier).loadConversations(),
                child: Builder(
                  builder: (context) {
                    if (state.isLoadingConversations &&
                        state.conversations.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: const [
                          NaseebakLoadingSkeleton(height: 84),
                          SizedBox(height: 12),
                          NaseebakLoadingSkeleton(height: 84),
                          SizedBox(height: 12),
                          NaseebakLoadingSkeleton(height: 84),
                        ],
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
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: NaseebakColors.cardBackground,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: NaseebakColors.errorBorder),
                                ),
                                child: const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 32,
                                  color: NaseebakColors.error,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                state.conversationsError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: NaseebakColors.textDarkNavy,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: NaseebakColors.primaryNavy,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
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
                        children: const [
                          SizedBox(height: 80),
                          NaseebakEmptyState(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'لا توجد محادثات حتى الآن',
                            subtitle: 'ستظهر محادثاتك هنا بعد قبول طلبات التعارف.',
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
                        vertical: 14,
                      ),
                      itemCount: state.conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final conv = state.conversations[index];
                        return _ConversationListCard(
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
          ],
        ),
      ),
    );
  }
}

class _ConversationListCard extends StatelessWidget {
  final ConversationSummaryModel conversation;
  final VoidCallback onTap;

  const _ConversationListCard({
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
              ? NaseebakColors.accentGoldMuted.withOpacity(0.18)
              : NaseebakColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread
                ? NaseebakColors.accentGold.withOpacity(0.55)
                : NaseebakColors.borderLight,
            width: hasUnread ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: hasUnread
                  ? NaseebakColors.accentGold.withOpacity(0.08)
                  : NaseebakColors.shadowColor,
              offset: const Offset(0, 3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                AuthorizedPhotoAvatar(
                  photoId: other.primaryPhotoId,
                  photoAuthorized: other.photoAuthorized,
                  fallbackName: other.fullName,
                  radius: 26,
                ),
                if (hasUnread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: NaseebakColors.accentGold,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: NaseebakColors.cardBackground,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
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
                            color: NaseebakColors.textDarkNavy,
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
                                ? NaseebakColors.accentGoldDark
                                : NaseebakColors.textMuted,
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
                                ? NaseebakColors.textDarkNavy
                                : NaseebakColors.textWarmGray,
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
                            gradient: const LinearGradient(
                              colors: [
                                NaseebakColors.primaryNavy,
                                NaseebakColors.primaryNavyDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: NaseebakColors.accentGold.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            conversation.unreadCount > 99
                                ? '+99'
                                : '${conversation.unreadCount}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: NaseebakColors.accentGoldLight,
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
