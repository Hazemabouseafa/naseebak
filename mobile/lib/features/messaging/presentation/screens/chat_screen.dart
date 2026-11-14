import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../discovery/presentation/providers/discovery_provider.dart';
import '../../../discovery/presentation/screens/member_profile_screen.dart';
import '../../../subscription/presentation/screens/subscription_screen.dart';
import '../../data/models/conversation_model.dart';
import '../../data/services/realtime_messaging_service.dart';
import '../providers/messaging_provider.dart';

/// Screen 09 — Private Chat (`المحادثة`) (تصميم Screen 09 من UX Pilot)
/// هيدر أبيض نقي مع زر الرجوع الدائري #F0F4FA، صورة العضو، اسم العضو وحالة "متصل الآن"،
/// منبه الخصوصية الأزرق، فقاعات الرسائل (المستلمة بيضاء بإطار رمادي والمرسلة زرقاء ملكية #184A8C)،
/// وشريط الإدخال المعاصر مع زر الإرسال وزر المرفقات الدائري.
class ChatScreen extends ConsumerStatefulWidget {
  final int conversationId;
  final String? initialMemberName;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.initialMemberName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _dialogShownForCurrentPrompt = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(messagingProvider.notifier)
          .openConversation(widget.conversationId);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <= 80) {
      ref.read(messagingProvider.notifier).loadOlderMessages();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSendPressed() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final state = ref.read(messagingProvider);
    final currentUserId = ref.read(authControllerProvider).user?.id ?? 0;

    if (state.activeConversation?.isBlocked == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('لا يمكن إرسال رسائل في هذه المحادثة بسبب الحظر.'),
        ),
      );
      return;
    }

    final result = await ref.read(messagingProvider.notifier).sendMessage(
          conversationId: widget.conversationId,
          currentUserId: currentUserId,
          rawText: text,
        );

    if (!mounted) return;

    if (result.isSuccess) {
      _messageController.clear();
      setState(() {});
      _scrollToBottom();
    } else if (result.isSubscriptionRequired) {
      if (_messageController.text.trim().isEmpty &&
          ref.read(messagingProvider).preservedDraftText.isNotEmpty) {
        _messageController.text =
            ref.read(messagingProvider).preservedDraftText;
      }
      await _showSubscriptionRequiredDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(result.message),
        ),
      );
    }
  }

  Future<void> _retryFailedMessage(ChatMessageModel msg) async {
    final currentUserId = ref.read(authControllerProvider).user?.id ?? 0;
    final result = await ref.read(messagingProvider.notifier).sendMessage(
          conversationId: widget.conversationId,
          currentUserId: currentUserId,
          rawText: msg.body,
          retryClientMessageId: msg.clientMessageId,
        );
    if (!mounted) return;
    if (result.isSubscriptionRequired) {
      await _showSubscriptionRequiredDialog();
    }
  }

  Future<void> _showSubscriptionRequiredDialog() async {
    if (_dialogShownForCurrentPrompt) return;
    _dialogShownForCurrentPrompt = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        key: const Key('chat_subscription_required_dialog'),
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.cardWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.subtleBorder),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.primaryBlue,
                size: 26,
              ),
              SizedBox(width: 8),
              Text(
                'الاشتراك الشهري مطلوب',
                style: TextStyle(
                  fontFamily: NaseebakTypography.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: const Text(
            'يتطلب إرسال الرسائل في المحادثات اشتراكًا شهريًا نشطًا في نَصِيبُكَ. يمكنك تصفح سجل الرسائل السابقة بحرية في أي وقت.',
            style: TextStyle(
              fontFamily: NaseebakTypography.fontFamily,
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.65,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('لاحقاً'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SubscriptionScreen(),
                  ),
                );
                if (mounted) {
                  await ref
                      .read(messagingProvider.notifier)
                      .resynchronizeAfterReconnection();
                }
              },
              child: const Text(
                'عرض العضوية',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );

    _dialogShownForCurrentPrompt = false;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmAndBlockOtherMember(
    int otherUserId,
    String otherFullName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.cardWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'حظر $otherFullName؟',
            style: const TextStyle(
              fontFamily: NaseebakTypography.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'عند حظر هذا العضو سيتم إيقاف المحادثة فوراً ولن يتمكن أي طرف من إرسال رسائل جديدة.',
            style: TextStyle(
              fontFamily: NaseebakTypography.fontFamily,
              fontSize: 13,
              color: AppColors.textSecondary,
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
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('تأكيد الحظر'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final err = await ref.read(discoveryProvider.notifier).blockMember(
          memberUserId: otherUserId,
          reason: 'حظر من داخل شاشة المحادثة',
        );

    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text(err)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryNavy,
          content: Text('تم حظر العضو وإغلاق المحادثة.'),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _showReportDialog({
    required int otherUserId,
    required String otherFullName,
    int? messageId,
  }) async {
    String selectedCategory = 'inappropriate_behavior';
    final detailsController = TextEditingController();
    String? dialogError;

    final reported = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: AppColors.cardWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                messageId != null
                    ? 'الإبلاغ عن رسالة من $otherFullName'
                    : 'الإبلاغ عن $otherFullName',
                style: const TextStyle(
                  fontFamily: NaseebakTypography.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('سبب البلاغ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedCategory,
                      items: const [
                        DropdownMenuItem(value: 'inappropriate_behavior', child: Text('سلوك أو محتوى غير لائق')),
                        DropdownMenuItem(value: 'harassment', child: Text('إزعاج أو إساءة في المحادثة')),
                        DropdownMenuItem(value: 'scam_attempt', child: Text('محاولة احتيال')),
                        DropdownMenuItem(value: 'fake_profile', child: Text('ملف غير حقيقي أو مضلل')),
                        DropdownMenuItem(value: 'other', child: Text('سبب آخر')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('تفاصيل البلاغ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: detailsController,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'يرجى كتابة تفاصيل البلاغ...'),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Text(dialogError!, style: const TextStyle(color: AppColors.error, fontSize: 11.5)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () async {
                    if (detailsController.text.trim().length < 5) {
                      setDialogState(() => dialogError = 'يرجى كتابة تفاصيل كافية للبلاغ.');
                      return;
                    }
                    final err = await ref.read(discoveryProvider.notifier).reportMember(
                          memberUserId: otherUserId,
                          reasonCategory: selectedCategory,
                          details: detailsController.text.trim(),
                          conversationId: widget.conversationId,
                          messageId: messageId,
                        );
                    if (err != null) {
                      setDialogState(() => dialogError = err);
                    } else if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: const Text('إرسال البلاغ'),
                ),
              ],
            ),
          );
        },
      ),
    );

    detailsController.dispose();

    if (reported == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryNavy,
          content: Text('تم استلام البلاغ وسيتم مراجعته من فريق الإشراف.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagingProvider);
    final currentUserId = ref.watch(authControllerProvider).user?.id ?? 0;
    final conv = state.activeConversation;
    final otherMember = conv?.otherMember;
    final displayTitle =
        otherMember?.fullName ?? widget.initialMemberName ?? 'المحادثة';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.cardWhite,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.cardWhite,
              border: Border(
                bottom: BorderSide(color: AppColors.subtleBorder, width: 1),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    // Circular Back Button (#F0F4FA)
                    NaseebakCircleButton(
                      icon: Icons.arrow_forward_rounded,
                      size: 40,
                      iconSize: 20,
                      onTap: () {
                        ref.read(messagingProvider.notifier).leaveActiveConversation();
                        Navigator.of(context).pop();
                      },
                      tooltip: 'رجوع',
                    ),
                    const SizedBox(width: 10),

                    // Avatar with Online Green Dot (displays member photo when authorized & opens MemberProfileScreen on tap)
                    GestureDetector(
                      onTap: otherMember == null
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => MemberProfileScreen(
                                    memberUserId: otherMember.userId,
                                  ),
                                ),
                              );
                            },
                      child: Stack(
                        children: [
                          AuthorizedPhotoAvatar(
                            photoId: otherMember?.primaryPhotoId,
                            photoAuthorized:
                                otherMember?.photoAuthorized ?? false,
                            fallbackName: displayTitle,
                            radius: 20,
                            showGoldBorder: false,
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Name and "متصل الآن"
                    Expanded(
                      child: GestureDetector(
                        onTap: otherMember == null
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => MemberProfileScreen(
                                      memberUserId: otherMember.userId,
                                    ),
                                  ),
                                );
                              },
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'متصل الآن',
                              style: TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // More Menu Button (3-dots)
                    NaseebakCircleButton(
                      buttonKey: const Key('chat_safety_menu_btn'),
                      icon: Icons.more_vert_rounded,
                      size: 40,
                      iconSize: 20,
                      onTap: () {
                        if (otherMember == null) return;
                        showModalBottomSheet<void>(
                          context: context,
                          backgroundColor: AppColors.cardWhite,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (ctx) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.person_outline_rounded, color: AppColors.primaryBlue),
                                    title: const Text('عرض الملف الشخصي'),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => MemberProfileScreen(memberUserId: otherMember.userId),
                                        ),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.flag_outlined, color: AppColors.textSecondary),
                                    title: const Text('الإبلاغ عن العضو'),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      _showReportDialog(otherUserId: otherMember.userId, otherFullName: otherMember.fullName);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.block_rounded, color: AppColors.error),
                                    title: const Text('حظر العضو', style: TextStyle(color: AppColors.error)),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      _confirmAndBlockOtherMember(otherMember.userId, otherMember.fullName);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      tooltip: 'خيارات المحادثة',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Reconnecting Banner
              if (state.connectionState == RealtimeConnectionState.reconnecting)
                Container(
                  key: const Key('chat_reconnecting_banner'),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  color: AppColors.surfaceSubtleBlue,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'جاري إعادة الاتصال الفوري بالخادم...',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                ),

              // Subscription Warning Banner
              if (conv != null && !conv.isBlocked && !conv.canSendMessages && conv.restrictionCode == 'SUBSCRIPTION_REQUIRED')
                Container(
                  key: const Key('chat_subscription_banner'),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: AppColors.surfaceSubtleBlue,
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, size: 20, color: AppColors.goldAccent),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'إرسال الرسائل يتطلب عضوية فعّالة.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
                          );
                          if (mounted) {
                            await ref.read(messagingProvider.notifier).resynchronizeAfterReconnection();
                          }
                        },
                        child: const Text('عرض العضوية', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),

              // Messages List
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    // Centered Date Pill
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtleBlue,
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Text(
                              'اليوم',
                              style: TextStyle(
                                fontFamily: NaseebakTypography.fontFamily,
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Privacy Reminder Card (Screen 09 Signature)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtleBlue,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2), width: 1.2),
                      ),
                      child: const Center(
                        child: Text(
                          'خصوصيتك مهمة، خليك حريص على معلوماتك الشخصية.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: NaseebakTypography.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),

                    // Messages Items
                    ...state.activeMessages.map((message) {
                      final isOutgoing = message.senderId == currentUserId;
                      return _MessageBubbleItem(
                        message: message,
                        isOutgoing: isOutgoing,
                        onRetry: message.sendState == OutgoingSendState.failed
                            ? () => _retryFailedMessage(message)
                            : null,
                        onReportMessage: (!isOutgoing && otherMember != null && message.id > 0)
                            ? () => _showReportDialog(
                                  otherUserId: otherMember.userId,
                                  otherFullName: otherMember.fullName,
                                  messageId: message.id,
                                )
                            : null,
                      );
                    }),
                  ],
                ),
              ),

              // Message Composer
              if (conv?.isBlocked == true)
                Container(
                  key: const Key('chat_blocked_composer_banner'),
                  padding: const EdgeInsets.all(16),
                  color: AppColors.cardWhite,
                  child: const Text(
                    'تم إيقاف إرسال الرسائل في هذه المحادثة بسبب وجود حظر بين الطرفين.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.error),
                  ),
                )
              else
                _buildMessageComposer(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageComposer(MessagingState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(top: BorderSide(color: AppColors.subtleBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Attachment / Options Circular '+' Button
          NaseebakCircleButton(
            icon: Icons.add_rounded,
            size: 42,
            iconSize: 22,
            backgroundColor: AppColors.surfaceSubtleBlue,
            iconColor: AppColors.textPrimary,
            onTap: () {},
          ),
          const SizedBox(width: 8),

          // Message Input Field
          Expanded(
            child: TextField(
              key: const Key('chat_message_input'),
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك...',
                hintStyle: const TextStyle(
                  fontFamily: NaseebakTypography.fontFamily,
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: AppColors.softBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.subtleBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.subtleBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primaryBlue),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Circular Send Button (#184A8C)
          Material(
            color: AppColors.primaryBlue,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('chat_send_message_btn'),
              onTap: state.isSendingMessage ? null : _handleSendPressed,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.send_rounded, size: 20, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubbleItem extends StatelessWidget {
  final ChatMessageModel message;
  final bool isOutgoing;
  final VoidCallback? onRetry;
  final VoidCallback? onReportMessage;

  const _MessageBubbleItem({
    required this.message,
    required this.isOutgoing,
    this.onRetry,
    this.onReportMessage,
  });

  @override
  Widget build(BuildContext context) {
    final timeLabel = _formatTime(message.createdAt);

    return Align(
      alignment: isOutgoing ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: isOutgoing ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isOutgoing ? AppColors.primaryBlue : AppColors.cardWhite,
              borderRadius: BorderRadius.circular(18),
              border: isOutgoing ? null : Border.all(color: AppColors.subtleBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message.body,
              style: TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 14,
                color: isOutgoing ? Colors.white : AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeLabel,
                  style: const TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (isOutgoing) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all_rounded, size: 14, color: AppColors.primaryBlue),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _formatTime(String? iso) {
    final dt = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
