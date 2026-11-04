import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../../discovery/data/models/blocked_member_model.dart';
import '../../../discovery/presentation/providers/discovery_provider.dart';

/// Screen 12 — Blocked Members Screen (`الأعضاء المحظورون`)
/// قائمة الأعضاء المحظورين مع إمكانية إلغاء الحظر والربط الحقيقي مع الخادم
class BlockedMembersScreen extends ConsumerStatefulWidget {
  const BlockedMembersScreen({super.key});

  @override
  ConsumerState<BlockedMembersScreen> createState() =>
      _BlockedMembersScreenState();
}

class _BlockedMembersScreenState extends ConsumerState<BlockedMembersScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<BlockedMemberModel> _blockedMembers = const [];

  @override
  void initState() {
    super.initState();
    _loadBlockedMembers();
  }

  Future<void> _loadBlockedMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final members =
          await ref.read(discoveryRepositoryProvider).fetchBlockedMembers();
      if (!mounted) return;
      setState(() {
        _blockedMembers = members;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUnblock(BlockedMemberModel member) async {
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
          title: const Row(
            children: [
              Icon(Icons.lock_open_rounded,
                  color: NaseebakColors.primaryNavy, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'إلغاء حظر العضو؟',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: NaseebakColors.textDarkNavy,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في إلغاء حظر "${member.fullName}"؟ سيتمكن العضو من رؤية ملفك العام مجدداً وفق إعدادات الخصوصية.',
            style: const TextStyle(
              fontSize: 13,
              color: NaseebakColors.textWarmGray,
              height: 1.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: NaseebakColors.primaryNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('نعم، إلغاء الحظر'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(discoveryRepositoryProvider)
          .unblockMember(member.blockedUserId);

      if (!mounted) return;
      setState(() {
        _blockedMembers = _blockedMembers
            .where((m) => m.blockedUserId != member.blockedUserId)
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: NaseebakColors.primaryNavy,
          content: Text('تم إلغاء حظر "${member.fullName}" بنجاح.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: NaseebakColors.error,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NaseebakColors.backgroundBeige,
        body: Column(
          children: [
            NaseebakCurvedHeader(
              title: 'الأعضاء المحظورون',
              subtitle: 'إدارة قائمة الحظر لحماية خصوصيتك وراحتك',
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: NaseebakColors.primaryNavy,
                onRefresh: _loadBlockedMembers,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Info Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: NaseebakColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: NaseebakColors.borderLight),
                          boxShadow: const [
                            BoxShadow(
                              color: NaseebakColors.shadowColor,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: NaseebakColors.accentGoldMuted
                                    .withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                color: NaseebakColors.primaryNavy,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'العضو المحظور لا يستطيع رؤية ملفك الشخصي أو إرسال طلبات تعارف أو مراسلتك عبر المحادثات الخاصة.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: NaseebakColors.textWarmGray,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: NaseebakColors.primaryNavy,
                            ),
                          ),
                        )
                      else if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: NaseebakColors.error,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: NaseebakColors.textWarmGray,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _loadBlockedMembers,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        )
                      else if (_blockedMembers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: NaseebakEmptyState(
                            icon: Icons.block_flipped,
                            title: 'لا يوجد أعضاء محظورون',
                            message:
                                'قائمة الحظر الخاصة بك فارغة حاليًا. يمكنك حظر أي عضو مسيء مباشرة من ملفه الشخصي أو من داخل المحادثة الخاصة.',
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.block_rounded,
                              size: 16,
                              color: NaseebakColors.error,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'إجمالي المحظورين: ${_blockedMembers.length}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: NaseebakColors.textDarkNavy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._blockedMembers.map((member) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: NaseebakColors.cardBackground,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: NaseebakColors.borderLight),
                              boxShadow: const [
                                BoxShadow(
                                  color: NaseebakColors.shadowColor,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      NaseebakColors.accentGoldMuted.withOpacity(0.3),
                                  child: Icon(
                                    member.gender == 'male'
                                        ? Icons.person_rounded
                                        : Icons.person_2_rounded,
                                    color: NaseebakColors.primaryNavy,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.fullName,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: NaseebakColors.textDarkNavy,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${member.ageYears} سنة${member.region.isNotEmpty ? ' • ${member.region}' : ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: NaseebakColors.textWarmGray,
                                        ),
                                      ),
                                      if (member.reason.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          member.reason,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: NaseebakColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  key: Key('unblock_btn_${member.blockedUserId}'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: NaseebakColors.error,
                                    side: const BorderSide(
                                      color: NaseebakColors.errorBorder,
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 36),
                                  ),
                                  onPressed: () => _handleUnblock(member),
                                  child: const Text(
                                    'إلغاء الحظر',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
