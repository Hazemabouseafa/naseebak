import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../../subscription/presentation/screens/subscription_screen.dart';
import '../../data/models/conversation_model.dart';
import '../providers/messaging_provider.dart';
import 'chat_screen.dart';

/// Screen 08 — Conversations List Screen (تصميم Screen 08 من UX Pilot)
/// تعرض المحادثات الخاصة المصرح بها بعد قبول طلبات التعارف بتصميم عصري وأنيق
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

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

  void _openSubscription() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SubscriptionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagingProvider);

    final filteredConversations = _searchQuery.trim().isEmpty
        ? state.conversations
        : state.conversations.where((c) {
            final q = _searchQuery.trim();
            return c.otherMember.fullName.contains(q) ||
                (c.lastMessage?.bodyPreview.contains(q) ?? false);
          }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.cardWhite,
        appBar: AppBar(
          backgroundColor: AppColors.cardWhite,
          elevation: 0,
          centerTitle: true,
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'المحادثات',
                style: TextStyle(
                  fontFamily: NaseebakTypography.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Opacity(
                opacity: 0.0,
                child: SizedBox(
                  height: 0,
                  child: Text('الرسائل'),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: NaseebakCircleButton(
                icon: Icons.refresh_rounded,
                size: 40,
                iconSize: 20,
                onTap: () =>
                    ref.read(messagingProvider.notifier).loadConversations(),
                tooltip: 'تحديث المحادثات',
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // 1. Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.softBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.subtleBorder),
                ),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'ابحث في المحادثات...',
                    hintStyle: TextStyle(
                      fontFamily: NaseebakTypography.fontFamily,
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ),

            // 2. Premium Upgrade Banner Strip (UX Pilot)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: InkWell(
                onTap: _openSubscription,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryNavy, Color(0xFF1D4A7A)],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.goldAccent.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 18,
                          color: AppColors.goldAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'رقّ حسابك لفتح ميزات الدردشة المتقدمة',
                          style: TextStyle(
                            fontFamily: NaseebakTypography.fontFamily,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.goldAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ترقية',
                          style: TextStyle(
                            fontFamily: NaseebakTypography.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Conversations List Area
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryBlue,
                backgroundColor: AppColors.cardWhite,
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
                                  color: AppColors.cardWhite,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.error),
                                ),
                                child: const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 32,
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                state.conversationsError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: NaseebakTypography.fontFamily,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
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
                        vertical: 4,
                      ),
                      itemCount: filteredConversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final conv = filteredConversations[index];
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
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasUnread
              ? AppColors.surfaceSubtleBlue
              : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasUnread
                ? AppColors.primaryBlue.withOpacity(0.35)
                : AppColors.subtleBorder,
            width: hasUnread ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AuthorizedPhotoAvatar(
                  photoId: other.primaryPhotoId,
                  photoAuthorized: other.photoAuthorized,
                  fallbackName: other.fullName,
                  radius: 26,
                ),
                // Green Online Indicator Dot
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
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
                            fontFamily: NaseebakTypography.fontFamily,
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
                            fontFamily: NaseebakTypography.fontFamily,
                            fontSize: 11.5,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w500,
                            color: hasUnread
                                ? AppColors.primaryBlue
                                : AppColors.textSecondary,
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
                            fontFamily: NaseebakTypography.fontFamily,
                            fontSize: 13,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.w400,
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
                              fontFamily: NaseebakTypography.fontFamily,
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
