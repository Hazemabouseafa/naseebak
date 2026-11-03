class SubscriptionEntitlementModel {
  final bool hasActiveSubscription;
  final String subscriptionStatus;
  final String? paymentChannel;
  final DateTime? currentPeriodEnd;
  final bool autoRenewing;
  final bool canSendMatchRequests;
  final bool canSendMessages;

  const SubscriptionEntitlementModel({
    required this.hasActiveSubscription,
    required this.subscriptionStatus,
    this.paymentChannel,
    this.currentPeriodEnd,
    this.autoRenewing = false,
    required this.canSendMatchRequests,
    required this.canSendMessages,
  });

  factory SubscriptionEntitlementModel.freeDefault() {
    return const SubscriptionEntitlementModel(
      hasActiveSubscription: false,
      subscriptionStatus: 'none',
      paymentChannel: null,
      currentPeriodEnd: null,
      autoRenewing: false,
      canSendMatchRequests: false,
      canSendMessages: false,
    );
  }

  factory SubscriptionEntitlementModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionEntitlementModel(
      hasActiveSubscription: json['has_active_subscription'] == true,
      subscriptionStatus: (json['subscription_status'] ?? 'none').toString(),
      paymentChannel: json['payment_channel']?.toString(),
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.tryParse(json['current_period_end'].toString())
          : null,
      autoRenewing: json['auto_renewing'] == true,
      canSendMatchRequests: json['can_send_match_requests'] == true,
      canSendMessages: json['can_send_messages'] == true,
    );
  }
}

class SubscriptionPlanModel {
  final int id;
  final String code;
  final String nameAr;
  final String? descriptionAr;
  final int durationDays;
  final String googlePlayProductId;
  final List<String> featuresAr;
  final String renewalTermsAr;
  final String cancellationTermsAr;

  const SubscriptionPlanModel({
    required this.id,
    required this.code,
    required this.nameAr,
    this.descriptionAr,
    required this.durationDays,
    required this.googlePlayProductId,
    required this.featuresAr,
    required this.renewalTermsAr,
    required this.cancellationTermsAr,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features_ar'];
    final List<String> parsedFeatures = rawFeatures is List
        ? rawFeatures.map((e) => e.toString()).toList()
        : const [
            'إرسال طلبات التعارف',
            'التواصل بعد الموافقة',
            'إرسال الرسائل الخاصة',
          ];

    return SubscriptionPlanModel(
      id: (json['id'] as num?)?.toInt() ?? 1,
      code: (json['code'] ?? 'monthly_membership').toString(),
      nameAr: (json['name_ar'] ?? 'العضوية الشهرية — نصيبك').toString(),
      descriptionAr: json['description_ar']?.toString(),
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 30,
      googlePlayProductId:
          (json['google_play_product_id'] ?? 'naseebak_monthly_membership')
              .toString(),
      featuresAr: parsedFeatures,
      renewalTermsAr: (json['renewal_terms_ar'] ??
              'يتجدد الاشتراك شهرياً عبر Google Play ما لم يتم إلغاؤه قبل نهاية الفترة الحالية.')
          .toString(),
      cancellationTermsAr: (json['cancellation_terms_ar'] ??
              'يمكنك إلغاء التجديد في أي وقت من إعدادات متجر Google Play مع استمرار الصلاحية حتى نهاية الفترة المدفوعة.')
          .toString(),
    );
  }
}

class SubscriptionRecordModel {
  final int id;
  final String planCode;
  final String planNameAr;
  final String channel;
  final String channelLabelAr;
  final String status;
  final String statusLabelAr;
  final bool isCurrentlyEntitled;
  final bool autoRenewing;
  final DateTime? startsAt;
  final DateTime? currentPeriodEnd;
  final DateTime? cancelledAt;
  final DateTime? lastVerifiedAt;

  const SubscriptionRecordModel({
    required this.id,
    required this.planCode,
    required this.planNameAr,
    required this.channel,
    required this.channelLabelAr,
    required this.status,
    required this.statusLabelAr,
    required this.isCurrentlyEntitled,
    required this.autoRenewing,
    this.startsAt,
    this.currentPeriodEnd,
    this.cancelledAt,
    this.lastVerifiedAt,
  });

  factory SubscriptionRecordModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionRecordModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      planCode: (json['plan_code'] ?? 'monthly_membership').toString(),
      planNameAr: (json['plan_name_ar'] ?? 'العضوية الشهرية — نصيبك').toString(),
      channel: (json['channel'] ?? 'google_play').toString(),
      channelLabelAr: (json['channel_label_ar'] ?? 'متجر Google Play').toString(),
      status: (json['status'] ?? 'pending').toString(),
      statusLabelAr: (json['status_label_ar'] ?? 'قيد المراجعة').toString(),
      isCurrentlyEntitled: json['is_currently_entitled'] == true,
      autoRenewing: json['auto_renewing'] == true,
      startsAt: json['starts_at'] != null
          ? DateTime.tryParse(json['starts_at'].toString())
          : null,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.tryParse(json['current_period_end'].toString())
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'].toString())
          : null,
      lastVerifiedAt: json['last_verified_at'] != null
          ? DateTime.tryParse(json['last_verified_at'].toString())
          : null,
    );
  }
}

class StoreProductPricingModel {
  final String productId;
  final String title;
  final String description;
  final String formattedPrice;
  final double rawPrice;
  final String currencyCode;

  const StoreProductPricingModel({
    required this.productId,
    required this.title,
    required this.description,
    required this.formattedPrice,
    required this.rawPrice,
    required this.currencyCode,
  });
}
