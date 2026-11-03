import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';

/// Screen 12 — Blocked Members Screen (`الأعضاء المحظورون`)
/// قائمة الأعضاء المحظورين مع إمكانية إلغاء الحظر بتصميم نَصِيبُكَ الفاخر
class BlockedMembersScreen extends ConsumerStatefulWidget {
  const BlockedMembersScreen({super.key});

  @override
  ConsumerState<BlockedMembersScreen> createState() =>
      _BlockedMembersScreenState();
}

class _BlockedMembersScreenState extends ConsumerState<BlockedMembersScreen> {
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                              color: NaseebakColors.accentGoldMuted.withOpacity(0.2),
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
                    const SizedBox(height: 40),
                    // Empty state (Backend provides POST /members/{id}/block, GET /blocked-members to be exposed in future API update)
                    const NaseebakEmptyState(
                      icon: Icons.block_flipped,
                      title: 'لا يوجد أعضاء محظورون',
                      message: 'قائمة الحظر الخاصة بك فارغة حاليًا. يمكنك حظر أي عضو مسيء مباشرة من ملفه الشخصي أو من داخل المحادثة الخاصة.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
