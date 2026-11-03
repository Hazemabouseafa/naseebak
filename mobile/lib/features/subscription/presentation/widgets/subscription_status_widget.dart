import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/subscription_model.dart';

class SubscriptionStatusWidget extends StatelessWidget {
  final SubscriptionEntitlementModel entitlement;
  final SubscriptionRecordModel? subscription;
  final VoidCallback? onManageTap;
  final VoidCallback? onSubscribeTap;

  const SubscriptionStatusWidget({
    super.key,
    required this.entitlement,
    this.subscription,
    this.onManageTap,
    this.onSubscribeTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = entitlement.hasActiveSubscription;
    final status = entitlement.subscriptionStatus;

    final Color badgeBg = isActive
        ? AppColors.surfaceSubtleBlue
        : (status == 'expired' || status == 'on_hold'
            ? AppColors.surfaceSubtleYellow
            : AppColors.backgroundSecondary);

    final Color badgeTextColor =
        isActive ? AppColors.primaryBlue : AppColors.darkBlue;

    final String statusLabel = switch (status) {
      'active' => 'اشتراك شهري نشط',
      'cancelled' => 'نشط (ملغى التجديد التلقائي)',
      'in_grace_period' => 'فترة سماح لتحديث الدفع',
      'on_hold' => 'الاشتراك معلق مؤقتاً',
      'pending' => 'عملية الدفع قيد التأكيد',
      'expired' => 'اشتراك منتهي الصلاحية',
      'refunded' => 'اشتراك مسترد',
      _ => 'عضوية مجانية (بدون اشتراك نشط)',
    };

    return Container(
      key: const Key('subscription_status_widget'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppColors.primaryBlue : AppColors.borderLight,
          width: isActive ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtleBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActive
                      ? Icons.workspace_premium_rounded
                      : Icons.card_membership_outlined,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'حالة العضوية والاشتراك',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (subscription?.currentPeriodEnd != null) ...[
            const SizedBox(height: 10),
            Text(
              isActive
                  ? 'صالح حتى: ${_formatDate(subscription!.currentPeriodEnd!)}'
                  : 'انتهت الصلاحية في: ${_formatDate(subscription!.currentPeriodEnd!)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (!isActive && onSubscribeTap != null) ...[
                Expanded(
                  child: ElevatedButton(
                    key: const Key('status_widget_subscribe_btn'),
                    onPressed: onSubscribeTap,
                    child: const Text('اشترك الآن'),
                  ),
                ),
                if (onManageTap != null) const SizedBox(width: 10),
              ],
              if (onManageTap != null)
                Expanded(
                  child: OutlinedButton(
                    key: const Key('status_widget_manage_btn'),
                    onPressed: onManageTap,
                    child: const Text('اشتراكي'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
