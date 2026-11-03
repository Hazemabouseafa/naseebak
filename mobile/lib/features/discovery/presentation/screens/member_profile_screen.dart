import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/member_profile_model.dart';
import '../providers/discovery_provider.dart';
import '../widgets/authorized_photo_avatar.dart';
import '../../../matchmaking/presentation/providers/matchmaking_provider.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../../subscription/presentation/screens/subscription_screen.dart';

/// 10. Member Profile Screen (الملف الشخصي للعضو)
/// تعرض بيانات العضو المسموح بها من GET /api/v1/members/{targetUser}/profile
/// مع احترام تام لإعدادات خصوصية الصورة الشخصية، وعدم كشف تاريخ الميلاد الدقيق أو البريد أو أي بيانات خاصة.
/// تتضمن:
/// - زر أساسي بارز "طلب التعارف" (يوضح شرط الاشتراك الشهري النشط دون إنشاء طلب وهمي أو دفع وهمي قبل المرحلتين 5 و6)
/// - زر ثانوي "إضافة إلى المفضلة" / "إزالة من المفضلة"
/// - إجراءات الأمان: "حظر العضو" و"الإبلاغ عن العضو" مربوطة فعلياً بقاعدة البيانات.
class MemberProfileScreen extends ConsumerStatefulWidget {
  final int memberUserId;

  const MemberProfileScreen({
    super.key,
    required this.memberUserId,
  });

  @override
  ConsumerState<MemberProfileScreen> createState() =>
      _MemberProfileScreenState();
}

class _MemberProfileScreenState extends ConsumerState<MemberProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryProvider.notifier).loadMemberProfile(
            widget.memberUserId,
          );
    });
  }

  Future<void> _handleMatchmakingRequestTap(
    MemberProfileDetailModel member,
  ) async {
    final buttonState = member.matchmakingButtonState;

    if (buttonState == 'request_accepted' &&
        member.matchmakingConversationId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            conversationId: member.matchmakingConversationId!,
            initialMemberName: member.fullName,
          ),
        ),
      );
      if (mounted) {
        ref
            .read(discoveryProvider.notifier)
            .loadMemberProfile(widget.memberUserId);
      }
      return;
    }

    if (buttonState == 'request_received_pending' &&
        member.matchmakingRequestId != null) {
      final res = await ref
          .read(matchmakingProvider.notifier)
          .acceptRequest(member.matchmakingRequestId!);
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
      ref
          .read(discoveryProvider.notifier)
          .updateActiveMemberMatchmakingState(
            buttonState: 'request_accepted',
            requestId: member.matchmakingRequestId,
            requestStatus: 'accepted',
            conversationId: res.conversationId,
          );
      if (res.conversationId != null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChatScreen(
              conversationId: res.conversationId!,
              initialMemberName: member.fullName,
            ),
          ),
        );
      }
      return;
    }

    if (buttonState == 'subscription_required' ||
        (!member.viewerCanSendMatchRequests && buttonState == 'available')) {
      await _showSubscriptionRequiredSheet(member);
      return;
    }

    if (buttonState == 'request_pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryBlue,
          content: Text('طلب التعارف قيد الانتظار لدى العضو.'),
        ),
      );
      return;
    }

    if (buttonState != 'available') {
      return;
    }

    // Confirm sending matchmaking request
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          key: const Key('confirm_send_match_request_dialog'),
          backgroundColor: AppColors.backgroundPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'طلب التعارف • ${member.fullName}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          content: const Text(
            'هل ترغب في إرسال طلب تعارف إلى هذا العضو؟',
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              key: const Key('confirm_send_match_request_btn'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('إرسال الطلب'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(matchmakingProvider.notifier)
        .sendRequest(member.userId);

    if (!mounted) return;

    if (result.isSuccess) {
      ref
          .read(discoveryProvider.notifier)
          .updateActiveMemberMatchmakingState(
            buttonState: 'request_pending',
            requestId: result.request?.id,
            requestStatus: 'pending',
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryBlue,
          content: Text('تم إرسال طلب التعارف بنجاح'),
        ),
      );
    } else if (result.isSubscriptionRequired) {
      await _showSubscriptionRequiredSheet(member);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(result.message),
        ),
      );
      ref
          .read(discoveryProvider.notifier)
          .loadMemberProfile(widget.memberUserId);
    }
  }

  Future<void> _showSubscriptionRequiredSheet(
    MemberProfileDetailModel member,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtleBlue,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.accentYellow,
                        width: 1.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      size: 30,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'يتطلب التواصل اشتراكًا شهريًا',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يمكنك تصفح الملفات والبحث وإضافة الأعضاء إلى المفضلة مجانًا، أما إرسال طلب التعارف وبدء التواصل فيتطلب عضوية شهرية نشطة وموثقة في نصيبك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.75,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  key: const Key('sheet_open_subscription_screen_btn'),
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SubscriptionScreen(),
                      ),
                    );
                    if (mounted) {
                      ref
                          .read(discoveryProvider.notifier)
                          .loadMemberProfile(widget.memberUserId);
                    }
                  },
                  child: const Text('اشترك الآن'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('لاحقاً'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ({String label, IconData icon, bool isEnabled}) _resolvePrimaryActionMeta(
    MemberProfileDetailModel member,
  ) {
    return switch (member.matchmakingButtonState) {
      'request_pending' => (
          label: 'طلب التعارف قيد الانتظار',
          icon: Icons.hourglass_top_rounded,
          isEnabled: false,
        ),
      'request_received_pending' => (
          label: 'قبول طلب التعارف الوارد',
          icon: Icons.check_circle_outline_rounded,
          isEnabled: true,
        ),
      'request_accepted' => (
          label: 'فتح المحادثة',
          icon: Icons.chat_bubble_outline_rounded,
          isEnabled: true,
        ),
      'subscription_required' => (
          label: 'يتطلب التواصل اشتراكًا شهريًا',
          icon: Icons.workspace_premium_outlined,
          isEnabled: true,
        ),
      'request_rejected' => (
          label: 'تم الاعتذار عن طلب التعارف',
          icon: Icons.block_outlined,
          isEnabled: false,
        ),
      'user_blocked' || 'request_unavailable' => (
          label: 'طلب التعارف غير متاح',
          icon: Icons.lock_outline_rounded,
          isEnabled: false,
        ),
      _ => (
          label: 'طلب التعارف',
          icon: Icons.favorite_border_rounded,
          isEnabled: true,
        ),
    };
  }

  Future<void> _confirmAndBlockMember(MemberProfileDetailModel member) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.backgroundPrimary,
          title: Text(
            'حظر ${member.fullName}؟',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'عند حظر هذا العضو، لن يتمكن من رؤية ملفك الشخصي أو التواصل معك، وسيتم إزالته فوراً من نتائج البحث والمفضلة.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size(110, 40),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('تأكيد الحظر'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final err = await ref.read(discoveryProvider.notifier).blockMember(
          memberUserId: member.userId,
          reason: 'حظر من شاشة الملف الشخصي',
        );

    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(err),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryBlue,
          content: Text('تم حظر العضو بنجاح.'),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _showReportMemberDialog(MemberProfileDetailModel member) async {
    String selectedCategory = 'inappropriate_behavior';
    final detailsController = TextEditingController();
    String? dialogError;

    final bool? reported = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppColors.backgroundPrimary,
                title: Text(
                  'الإبلاغ عن ${member.fullName}',
                  style: const TextStyle(
                    fontSize: 16,
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
                            value: 'fake_profile',
                            child: Text('ملف غير حقيقي أو مضلل'),
                          ),
                          DropdownMenuItem(
                            value: 'harassment',
                            child: Text('إزعاج أو إساءة'),
                          ),
                          DropdownMenuItem(
                            value: 'scam_attempt',
                            child: Text('محاولة احتيال'),
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
                        controller: detailsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText:
                              'يرجى توضيح سبب البلاغ ليتمكن فريق الإدارة من مراجعته...',
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
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(110, 40),
                    ),
                    onPressed: () async {
                      if (detailsController.text.trim().length < 5) {
                        setDialogState(() {
                          dialogError = 'يرجى كتابة تفاصيل كافية للبلاغ.';
                        });
                        return;
                      }
                      final err = await ref
                          .read(discoveryProvider.notifier)
                          .reportMember(
                            memberUserId: member.userId,
                            reasonCategory: selectedCategory,
                            details: detailsController.text.trim(),
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
        );
      },
    );

    detailsController.dispose();

    if (reported == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryBlue,
          content: Text(
            'تم إرسال البلاغ إلى إدارة نصيبك وسيتم التعامل معه بسرية تامة.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryProvider);
    final member = state.activeMemberProfile;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'رجوع',
        ),
        title: const Text('الملف الشخصي'),
        actions: [
          if (member != null)
            PopupMenuButton<String>(
              key: const Key('member_profile_safety_menu'),
              tooltip: 'خيارات الأمان',
              onSelected: (action) {
                if (action == 'block') {
                  _confirmAndBlockMember(member);
                } else if (action == 'report') {
                  _showReportMemberDialog(member);
                }
              },
              itemBuilder: (context) => const [
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
        child: Builder(
          builder: (context) {
            if (state.isLoadingMemberDetail) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              );
            }

            if (state.memberDetailError != null || member == null) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_person_outlined,
                      size: 48,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      state.memberDetailError ??
                          'هذا الملف الشخصي غير متاح للعرض حالياً.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('العودة'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Profile Header Card (Matching Mockup Screen 08)
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.backgroundPrimary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    height: 150,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.surfaceSubtleBlue,
                                          AppColors.surfaceSubtleYellow,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(15),
                                      ),
                                    ),
                                  ),
                                  AuthorizedPhotoAvatar(
                                    photoId: member.primaryPhotoId,
                                    photoAuthorized: member.photoAuthorized,
                                    fallbackName: member.fullName,
                                    radius: 46,
                                  ),
                                  Positioned(
                                    bottom: 10,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.92),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            member.photoAuthorized
                                                ? Icons.verified_user_outlined
                                                : Icons.lock_outline_rounded,
                                            size: 13,
                                            color: AppColors.primaryBlue,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            member.photoAuthorized
                                                ? 'ملف موثق'
                                                : 'صورة بإذن صاحب الملف',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primaryBlue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${member.fullName} • ${member.ageYears} سنة',
                                            style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceSubtleBlue,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            member.maritalStatusLabelAr,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryBlue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 16,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${member.region}، ${member.countryOfResidence}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 2. Personal Information Section
                        _MemberInfoSectionCard(
                          title: 'المعلومات الشخصية',
                          items: [
                            _MemberFieldPair('النوع', member.genderLabelAr),
                            _MemberFieldPair(
                              'العمر',
                              '${member.ageYears} سنة',
                            ),
                            _MemberFieldPair(
                              'الحالة الاجتماعية',
                              member.maritalStatusLabelAr,
                            ),
                            _MemberFieldPair(
                              'المؤهل الدراسي',
                              member.educationLevelLabelAr,
                            ),
                            _MemberFieldPair('المهنة', member.occupation),
                            _MemberFieldPair(
                              'الطول',
                              '${member.heightCm} سم',
                            ),
                            if (member.zodiacSign.isNotEmpty)
                              _MemberFieldPair('البرج', member.zodiacSign),
                            _MemberFieldPair(
                              'التدخين',
                              member.smokingStatusLabelAr,
                            ),
                            _MemberFieldPair('الجنسية', member.nationality),
                            _MemberFieldPair(
                              'بلد الإقامة',
                              member.countryOfResidence,
                            ),
                            _MemberFieldPair('المنطقة', member.region),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 3. Family Information Section
                        _MemberInfoSectionCard(
                          title: 'المعلومات الأسرية والسكن',
                          items: [
                            _MemberFieldPair(
                              'سبق الزواج',
                              member.previouslyMarried ? 'نعم' : 'لا',
                            ),
                            _MemberFieldPair(
                              'الأطفال',
                              member.hasChildren
                                  ? (member.childrenCount > 0
                                      ? 'نعم (${member.childrenCount})'
                                      : 'نعم')
                                  : 'لا يوجد',
                            ),
                            _MemberFieldPair(
                              'حالة السكن',
                              member.homeOwnershipLabelAr,
                            ),
                          ],
                        ),

                        // 4. Interests & Hobbies Section
                        if (member.hobbies.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundPrimary,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'الهوايات والاهتمامات',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: member.hobbies.map((hobby) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceSubtleBlue,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        hobby,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // 5. Optional Biography (Only shown if member actually provided it)
                        if (member.bio != null &&
                            member.bio!.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundPrimary,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'نبذة عني',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  member.bio!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                    height: 1.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // 6. Safety Quick Strip (Block & Report)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              key: const Key('member_report_btn'),
                              onPressed: () => _showReportMemberDialog(member),
                              icon: const Icon(
                                Icons.flag_outlined,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              label: const Text(
                                'الإبلاغ عن العضو',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton.icon(
                              key: const Key('member_block_btn'),
                              onPressed: () => _confirmAndBlockMember(member),
                              icon: const Icon(
                                Icons.block_rounded,
                                size: 16,
                                color: AppColors.error,
                              ),
                              label: const Text(
                                'حظر العضو',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Bar: Primary "طلب التعارف" + Secondary "إضافة إلى المفضلة"
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundPrimary,
                    border:
                        Border(top: BorderSide(color: AppColors.borderLight)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final meta = _resolvePrimaryActionMeta(member);
                            return ElevatedButton.icon(
                              key: const Key('member_send_request_btn'),
                              onPressed: meta.isEnabled
                                  ? () => _handleMatchmakingRequestTap(member)
                                  : null,
                              icon: Icon(meta.icon, size: 19),
                              label: Text(
                                meta.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        key: const Key('member_favorite_action_btn'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(145, 50),
                          side: BorderSide(
                            color: member.isFavorited
                                ? AppColors.accentYellow
                                : AppColors.borderLight,
                            width: 1.4,
                          ),
                        ),
                        onPressed: () async {
                          final err = await ref
                              .read(discoveryProvider.notifier)
                              .toggleFavorite(member);
                          if (err != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.error,
                                content: Text(err),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          member.isFavorited
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: member.isFavorited
                              ? AppColors.accentYellow
                              : AppColors.primaryBlue,
                          size: 19,
                        ),
                        label: Text(
                          member.isFavorited
                              ? 'في المفضلة'
                              : 'إضافة إلى المفضلة',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MemberFieldPair {
  final String label;
  final String value;
  const _MemberFieldPair(this.label, this.value);
}

class _MemberInfoSectionCard extends StatelessWidget {
  final String title;
  final List<_MemberFieldPair> items;

  const _MemberInfoSectionCard({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Divider(height: 22),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: items.map((item) {
              return SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.value,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
