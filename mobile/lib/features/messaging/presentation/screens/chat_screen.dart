import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../discovery/presentation/providers/discovery_provider.dart';
import '../../../discovery/presentation/screens/member_profile_screen.dart';
import '../../../discovery/presentation/widgets/authorized_photo_avatar.dart';
import '../../../subscription/presentation/screens/subscription_screen.dart';
import '../../data/models/conversation_model.dart';
import '../../data/services/realtime_messaging_service.dart';
import '../providers/messaging_provider.dart';

/// Screen 14 — Chat Screen (`المحادثة`)
/// محادثة نصية خاصة فورية بين طرفين مرتبطة بطلب تعارف مقبول.
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
    // Trigger older message cursor pagination when scrolling near top of history
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
      // Preserve draft in controller and show subscription dialog
      if (_messageController.text.trim().isEmpty &&
          ref.read(messagingProvider).preservedDraftText.isNotEmpty) {
        _messageController.text =
            ref.read(messagingProvider).preservedDraftText;
      }
      await _showSubscriptionRequiredDialog();
    } else {
      // Network or server error: clear input only because failed bubble is shown with retry button,
      // or keep draft accessible.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
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
          backgroundColor: AppColors.backgroundPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                color: AppColors.primaryBlue,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'يتطلب التواصل اشتراكًا شهريًا',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'يمكنك قراءة رسائل المحادثة مجانًا، بينما يتطلب إرسال الرسائل الخاصة اشتراكًا شهريًا نشطًا في نَصِيبُكَ. تم الاحتفاظ بمسودة رسالتك لتتمكن من إرسالها فور تفعيل الاشتراك.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
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
              child: const Text('لاحقاً'),
            ),
            ElevatedButton(
              key: const Key('chat_open_subscription_btn'),
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
              child: const Text('اشترك الآن'),
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
          backgroundColor: AppColors.backgroundPrimary,
          title: Text(
            'حظر $otherFullName؟',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'عند حظر هذا العضو سيتم إيقاف المحادثة فوراً ولن يتمكن أي طرف من إرسال رسائل جديدة.',
            style: TextStyle(
              fontSize: 12.5,
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
          backgroundColor: AppColors.primaryBlue,
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
              backgroundColor: AppColors.backgroundPrimary,
              title: Text(
                messageId != null
                    ? 'الإبلاغ عن رسالة من $otherFullName'
                    : 'الإبلاغ عن $otherFullName',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
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
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
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
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('chat_report_details_input'),
                      controller: detailsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'يرجى كتابة تفاصيل البلاغ لمراجعتها من الإدارة...',
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        dialogError!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.error,
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
          backgroundColor: AppColors.primaryBlue,
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
        backgroundColor: AppColors.backgroundSecondary,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundPrimary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            onPressed: () {
              ref.read(messagingProvider.notifier).leaveActiveConversation();
              Navigator.of(context).pop();
            },
            tooltip: 'رجوع',
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              if (otherMember != null) ...[
                AuthorizedPhotoAvatar(
                  photoId: otherMember.primaryPhotoId,
                  photoAuthorized: otherMember.photoAuthorized,
                  fallbackName: otherMember.fullName,
                  radius: 19,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (otherMember != null && otherMember.region.isNotEmpty)
                      Text(
                        '${otherMember.ageYears} سنة • ${otherMember.region}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (otherMember != null)
              PopupMenuButton<String>(
                key: const Key('chat_safety_menu_btn'),
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
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                          color: AppColors.primaryBlue,
                        ),
                        SizedBox(width: 8),
                        Text('عرض الملف الشخصي'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 8),
                        Text('الإبلاغ عن العضو'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(
                          Icons.block_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'حظر العضو',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.borderLight),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Subtle Connection Status Banner when Reconnecting
              if (state.connectionState ==
                  RealtimeConnectionState.reconnecting)
                Container(
                  key: const Key('chat_reconnecting_banner'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: AppColors.surfaceSubtleYellow,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryBlueDark,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'جاري إعادة الاتصال الفوري بالخادم...',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlueDark,
                        ),
                      ),
                    ],
                  ),
                ),

              // Subscription notice strip when user can read history but cannot send messages
              if (conv != null &&
                  !conv.isBlocked &&
                  !conv.canSendMessages &&
                  conv.restrictionCode == 'SUBSCRIPTION_REQUIRED')
                Container(
                  key: const Key('chat_subscription_banner'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSubtleBlue,
                    border: Border(
                      bottom: BorderSide(color: AppColors.borderLight),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_outlined,
                        size: 18,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'إرسال الرسائل يتطلب اشتراكًا شهريًا نشطًا.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlueDark,
                          ),
                        ),
                      ),
                      TextButton(
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
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Message List
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (state.isLoadingMessages &&
                        state.activeMessages.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryBlue,
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
                                color: AppColors.error,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                state.messagesError!,
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
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtleBlue,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.mark_chat_unread_outlined,
                                  size: 30,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'بدأت المحادثة الخاصة بعد قبول طلب التعارف',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'نوصي بالالتزام بالجدية والاحترام المتبادل وفق ضوابط منصة نَصِيبُكَ.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
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
                                  color: AppColors.primaryBlue,
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

              // Composer or Blocked Banner
              if (conv?.isBlocked == true)
                Container(
                  key: const Key('chat_blocked_composer_banner'),
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundPrimary,
                    border:
                        Border(top: BorderSide(color: AppColors.borderLight)),
                  ),
                  child: const Text(
                    'تم إيقاف إرسال الرسائل في هذه المحادثة بسبب وجود حظر بين الطرفين.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.backgroundPrimary,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
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
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك هنا...',
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AppColors.borderLight),
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
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: state.isSendingMessage ? null : _handleSendPressed,
                  child: state.isSendingMessage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                ),
              ),
            ],
          ),
          if (currentLen > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$currentLen / $maxLen',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: currentLen > maxLen
                        ? AppColors.error
                        : AppColors.textMuted,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtleBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlueDark,
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
          padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
          decoration: BoxDecoration(
            color: isOutgoing
                ? AppColors.primaryBlue
                : AppColors.backgroundPrimary,
            borderRadius: BorderRadius.only(
              topRight: const Radius.circular(16),
              topLeft: const Radius.circular(16),
              bottomRight: Radius.circular(isOutgoing ? 4 : 16),
              bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
            ),
            border: isOutgoing
                ? null
                : Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.body,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isOutgoing ? Colors.white : AppColors.textPrimary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: isOutgoing
                          ? Colors.white.withOpacity(0.82)
                          : AppColors.textMuted,
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
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              if (message.sendState == OutgoingSendState.failed &&
                  onRetry != null) ...[
                const SizedBox(height: 4),
                InkWell(
                  key: Key('retry_message_${message.clientMessageId}'),
                  onTap: onRetry,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 13,
                        color: AppColors.accentYellow,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'فشل الإرسال • اضغط لإعادة المحاولة',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentYellow,
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
        color: AppColors.accentYellow,
      );
    }
    if (message.isRead || message.deliveryStatus == 'read') {
      return const Icon(
        Icons.done_all_rounded,
        size: 14,
        color: AppColors.accentYellow,
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
