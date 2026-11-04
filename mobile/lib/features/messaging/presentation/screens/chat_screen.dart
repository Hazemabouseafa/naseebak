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

/// Screen 14 — Chat Screen (`المحادثة`)
/// محادثة نصية خاصة فورية بين طرفين مرتبطة بطلب تعارف مقبول بتصميم نَصِيبُكَ الفاخر.
/// تحترم قواعد الاشتراك الشهري النشط للإرسال، وتسمح بقراءة السجل دائماً للمشاركين المصرح لهم.
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
          backgroundColor: NaseebakColors.error,
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
          backgroundColor: NaseebakColors.error,
          content: Text(result.message),
        ),
      );
    }
  }

  Future<void> _retryFailedMessage(ChatMessageModel failedMessage) async {
    final currentUserId = ref.read(authControllerProvider).user?.id ?? 0;
    final res = await ref.read(messagingProvider.notifier).sendMessage(
          conversationId: widget.conversationId,
          currentUserId: currentUserId,
          rawText: failedMessage.body,
          retryClientMessageId: failedMessage.clientMessageId,
        );

    if (!mounted) return;
    if (res.isSubscriptionRequired) {
      _messageController.text = failedMessage.body;
      await _showSubscriptionRequiredDialog();
    }
  }

  Future<void> _showSubscriptionRequiredDialog() async {
    if (_dialogShownForCurrentPrompt) return;
    _dialogShownForCurrentPrompt = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          key: const Key('chat_subscription_required_dialog'),
          backgroundColor: NaseebakColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: NaseebakColors.borderLight),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NaseebakColors.accentGoldMuted.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: NaseebakColors.accentGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'يتطلب التواصل اشتراكًا شهريًا',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: NaseebakColors.textDarkNavy,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'يمكنك قراءة رسائل المحادثة مجانًا، بينما يتطلب إرسال الرسائل الخاصة اشتراكًا شهريًا نشطًا في نَصِيبُكَ. تم الاحتفاظ بمسودة رسالتك لتتمكن من إرسالها فور تفعيل الاشتراك.',
            style: TextStyle(
              fontSize: 13,
              color: NaseebakColors.textWarmGray,
              height: 1.7,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref
                    .read(messagingProvider.notifier)
                    .dismissSubscriptionRequiredPrompt();
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'لاحقاً',
                style: TextStyle(color: NaseebakColors.textMuted),
              ),
            ),
            ElevatedButton(
              key: const Key('chat_open_subscription_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NaseebakColors.accentGold,
                foregroundColor: NaseebakColors.primaryNavyDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                ref
                    .read(messagingProvider.notifier)
                    .dismissSubscriptionRequiredPrompt();
                Navigator.of(dialogContext).pop();
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
                'اشترك الآن',
                style: TextStyle(fontWeight: FontWeight.w800),
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
          backgroundColor: NaseebakColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: NaseebakColors.borderLight),
          ),
          title: Text(
            'حظر $otherFullName؟',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: NaseebakColors.textDarkNavy,
            ),
          ),
          content: const Text(
            'عند حظر هذا العضو سيتم إيقاف المحادثة فوراً ولن يتمكن أي طرف من إرسال رسائل جديدة.',
            style: TextStyle(
              fontSize: 12.5,
              color: NaseebakColors.textWarmGray,
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
                backgroundColor: NaseebakColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
        SnackBar(backgroundColor: NaseebakColors.error, content: Text(err)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: NaseebakColors.primaryNavy,
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
              backgroundColor: NaseebakColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: NaseebakColors.borderLight),
              ),
              title: Text(
                messageId != null
                    ? 'الإبلاغ عن رسالة من $otherFullName'
                    : 'الإبلاغ عن $otherFullName',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: NaseebakColors.textDarkNavy,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'سبب البلاغ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: NaseebakColors.textDarkNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: NaseebakColors.backgroundBeige,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
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
                          child: Text('إزعاج أو إساءة في المحادثة'),
                        ),
                        DropdownMenuItem(
                          value: 'scam_attempt',
                          child: Text('محاولة احتيال أو طلب أموال'),
                        ),
                        DropdownMenuItem(
                          value: 'fake_profile',
                          child: Text('ملف غير حقيقي أو مضلل'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('سبب آخر'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'تفاصيل البلاغ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: NaseebakColors.textDarkNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('chat_report_details_input'),
                      controller: detailsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'يرجى كتابة تفاصيل البلاغ لمراجعتها من الإدارة...',
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
                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        dialogError!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: NaseebakColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  key: const Key('chat_submit_report_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NaseebakColors.primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (detailsController.text.trim().length < 5) {
                      setDialogState(() {
                        dialogError = 'يرجى كتابة تفاصيل كافية للبلاغ.';
                      });
                      return;
                    }
                    final err =
                        await ref.read(discoveryProvider.notifier).reportMember(
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
          backgroundColor: NaseebakColors.primaryNavy,
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
        backgroundColor: NaseebakColors.backgroundBeige,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  NaseebakColors.primaryNavy,
                  NaseebakColors.primaryNavyDark,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        ref.read(messagingProvider.notifier).leaveActiveConversation();
                        Navigator.of(context).pop();
                      },
                      tooltip: 'رجوع',
                    ),
                    if (otherMember != null) ...[
                      Stack(
                        children: [
                          AuthorizedPhotoAvatar(
                            photoId: otherMember.primaryPhotoId,
                            photoAuthorized: otherMember.photoAuthorized,
                            fallbackName: otherMember.fullName,
                            radius: 20,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: NaseebakColors.accentGold,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: NaseebakColors.primaryNavyDark,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (otherMember != null && otherMember.region.isNotEmpty)
                            Text(
                              '${otherMember.ageYears} سنة • ${otherMember.region}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (otherMember != null)
                      PopupMenuButton<String>(
                        key: const Key('chat_safety_menu_btn'),
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white,
                        ),
                        tooltip: 'خيارات المحادثة',
                        onSelected: (action) {
                          if (action == 'profile') {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => MemberProfileScreen(
                                  memberUserId: otherMember.userId,
                                ),
                              ),
                            );
                          } else if (action == 'block') {
                            _confirmAndBlockOtherMember(
                              otherMember.userId,
                              otherMember.fullName,
                            );
                          } else if (action == 'report') {
                            _showReportDialog(
                              otherUserId: otherMember.userId,
                              otherFullName: otherMember.fullName,
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'profile',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 18,
                                  color: NaseebakColors.primaryNavy,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'عرض الملف الشخصي',
                                  style: TextStyle(color: NaseebakColors.textDarkNavy),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  size: 18,
                                  color: NaseebakColors.textDarkNavy,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'الإبلاغ عن العضو',
                                  style: TextStyle(color: NaseebakColors.textDarkNavy),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'block',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.block_rounded,
                                  size: 18,
                                  color: NaseebakColors.error,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'حظر العضو',
                                  style: TextStyle(color: NaseebakColors.error),
                                ),
                              ],
                            ),
                          ),
                        ],
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
              if (state.connectionState ==
                  RealtimeConnectionState.reconnecting)
                Container(
                  key: const Key('chat_reconnecting_banner'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  color: NaseebakColors.accentGoldMuted.withOpacity(0.35),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: NaseebakColors.primaryNavyDark,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'جاري إعادة الاتصال الفوري بالخادم...',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: NaseebakColors.primaryNavyDark,
                        ),
                      ),
                    ],
                  ),
                ),

              if (conv != null &&
                  !conv.isBlocked &&
                  !conv.canSendMessages &&
                  conv.restrictionCode == 'SUBSCRIPTION_REQUIRED')
                Container(
                  key: const Key('chat_subscription_banner'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: NaseebakColors.accentGoldMuted.withOpacity(0.22),
                    border: Border(
                      bottom: BorderSide(
                        color: NaseebakColors.accentGold.withOpacity(0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        size: 20,
                        color: NaseebakColors.accentGoldDark,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'إرسال الرسائل يتطلب اشتراكًا شهريًا نشطًا.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: NaseebakColors.primaryNavyDark,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NaseebakColors.accentGold,
                          foregroundColor: NaseebakColors.primaryNavyDark,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
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
                          'اشترك الآن',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: Builder(
                  builder: (context) {
                    if (state.isLoadingMessages &&
                        state.activeMessages.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: NaseebakColors.accentGold,
                        ),
                      );
                    }

                    if (state.messagesError != null &&
                        state.activeMessages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 42,
                                color: NaseebakColors.error,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                state.messagesError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: NaseebakColors.textDarkNavy,
                                ),
                              ),
                              const SizedBox(height: 14),
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
                                    .openConversation(widget.conversationId),
                                child: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (state.activeMessages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: NaseebakColors.accentGoldMuted.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: NaseebakColors.accentGold.withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.mark_chat_unread_rounded,
                                  size: 32,
                                  color: NaseebakColors.accentGoldDark,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'بدأت المحادثة الخاصة بعد قبول طلب التعارف',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: NaseebakColors.textDarkNavy,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'نوصي بالالتزام بالجدية والاحترام المتبادل وفق ضوابط منصة نَصِيبُكَ الشرعية والأخلاقية.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: NaseebakColors.textWarmGray,
                                  height: 1.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      key: const Key('chat_messages_list'),
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                      itemCount: state.activeMessages.length +
                          (state.isLoadingOlderMessages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (state.isLoadingOlderMessages && index == 0) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: NaseebakColors.accentGold,
                                ),
                              ),
                            ),
                          );
                        }

                        final msgIndex = state.isLoadingOlderMessages
                            ? index - 1
                            : index;
                        final message = state.activeMessages[msgIndex];
                        final prevMessage = msgIndex > 0
                            ? state.activeMessages[msgIndex - 1]
                            : null;

                        final showDateHeader = _shouldShowDateSeparator(
                          prevMessage?.createdAt,
                          message.createdAt,
                        );

                        final isOutgoing = message.senderId == currentUserId;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDateHeader)
                              _DateSeparatorChip(
                                label: _formatDateHeader(message.createdAt),
                              ),
                            _MessageBubbleItem(
                              message: message,
                              isOutgoing: isOutgoing,
                              onRetry: message.sendState ==
                                      OutgoingSendState.failed
                                  ? () => _retryFailedMessage(message)
                                  : null,
                              onReportMessage: (!isOutgoing &&
                                      otherMember != null &&
                                      message.id > 0)
                                  ? () => _showReportDialog(
                                        otherUserId: otherMember.userId,
                                        otherFullName: otherMember.fullName,
                                        messageId: message.id,
                                      )
                                  : null,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              if (conv?.isBlocked == true)
                Container(
                  key: const Key('chat_blocked_composer_banner'),
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: NaseebakColors.cardBackground,
                    border: Border(
                      top: BorderSide(color: NaseebakColors.borderLight),
                    ),
                  ),
                  child: const Text(
                    'تم إيقاف إرسال الرسائل في هذه المحادثة بسبب وجود حظر بين الطرفين.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: NaseebakColors.error,
                    ),
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
    final currentLen = _messageController.text.characters.length;
    final maxLen = state.maxMessageLength;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: NaseebakColors.cardBackground,
        border: const Border(top: BorderSide(color: NaseebakColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, -3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('chat_message_input'),
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: maxLen,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 14,
                    color: NaseebakColors.textDarkNavy,
                  ),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك باحترام وجدية...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: NaseebakColors.textMuted,
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    filled: true,
                    fillColor: NaseebakColors.backgroundBeige,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: NaseebakColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: NaseebakColors.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: NaseebakColors.accentGold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 46,
                width: 48,
                child: ElevatedButton(
                  key: const Key('chat_send_message_btn'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: NaseebakColors.primaryNavy,
                    foregroundColor: NaseebakColors.accentGoldLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: state.isSendingMessage ? null : _handleSendPressed,
                  child: state.isSendingMessage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: NaseebakColors.accentGold,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: NaseebakColors.accentGold,
                        ),
                ),
              ),
            ],
          ),
          if (currentLen > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$currentLen / $maxLen',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: currentLen > maxLen
                        ? NaseebakColors.error
                        : NaseebakColors.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _shouldShowDateSeparator(String? previousIso, String? currentIso) {
    if (currentIso == null) return false;
    if (previousIso == null) return true;
    final prev = DateTime.tryParse(previousIso)?.toLocal();
    final curr = DateTime.tryParse(currentIso)?.toLocal();
    if (prev == null || curr == null) return false;
    return prev.year != curr.year ||
        prev.month != curr.month ||
        prev.day != curr.day;
  }

  String _formatDateHeader(String? iso) {
    final dt = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
    if (dt == null) return 'اليوم';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(msgDay).inDays;
    if (diffDays == 0) return 'اليوم';
    if (diffDays == 1) return 'أمس';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}

class _DateSeparatorChip extends StatelessWidget {
  final String label;

  const _DateSeparatorChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: NaseebakColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NaseebakColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: NaseebakColors.primaryNavyDark,
            ),
          ),
        ),
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
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onReportMessage,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 295),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            gradient: isOutgoing
                ? const LinearGradient(
                    colors: [
                      NaseebakColors.primaryNavy,
                      NaseebakColors.primaryNavyDark,
                    ],
                  )
                : null,
            color: isOutgoing ? null : NaseebakColors.cardBackground,
            borderRadius: BorderRadius.only(
              topRight: const Radius.circular(18),
              topLeft: const Radius.circular(18),
              bottomRight: Radius.circular(isOutgoing ? 4 : 18),
              bottomLeft: Radius.circular(isOutgoing ? 18 : 4),
            ),
            border: isOutgoing
                ? Border.all(
                    color: NaseebakColors.accentGold.withOpacity(0.2),
                    width: 0.8,
                  )
                : Border.all(color: NaseebakColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: isOutgoing
                    ? NaseebakColors.primaryNavyDark.withOpacity(0.12)
                    : NaseebakColors.shadowColor,
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.body,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isOutgoing ? Colors.white : NaseebakColors.textDarkNavy,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: isOutgoing
                          ? Colors.white.withOpacity(0.75)
                          : NaseebakColors.textMuted,
                    ),
                  ),
                  if (isOutgoing) ...[
                    const SizedBox(width: 5),
                    _buildDeliveryIcon(),
                  ],
                  if (!isOutgoing && onReportMessage != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: onReportMessage,
                      child: const Icon(
                        Icons.flag_outlined,
                        size: 13,
                        color: NaseebakColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              if (message.sendState == OutgoingSendState.failed &&
                  onRetry != null) ...[
                const SizedBox(height: 5),
                InkWell(
                  key: Key('retry_message_${message.clientMessageId}'),
                  onTap: onRetry,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 13,
                        color: NaseebakColors.accentGoldLight,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'فشل الإرسال • اضغط لإعادة المحاولة',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: NaseebakColors.accentGoldLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryIcon() {
    if (message.sendState == OutgoingSendState.sending) {
      return const Icon(
        Icons.access_time_rounded,
        size: 12,
        color: Colors.white70,
      );
    }
    if (message.sendState == OutgoingSendState.failed) {
      return const Icon(
        Icons.error_outline_rounded,
        size: 13,
        color: NaseebakColors.error,
      );
    }
    if (message.isRead || message.deliveryStatus == 'read') {
      return const Icon(
        Icons.done_all_rounded,
        size: 14,
        color: NaseebakColors.accentGold,
      );
    }
    if (message.deliveryStatus == 'delivered_recipient') {
      return const Icon(
        Icons.done_all_rounded,
        size: 14,
        color: Colors.white70,
      );
    }
    return const Icon(
      Icons.check_rounded,
      size: 13,
      color: Colors.white70,
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
