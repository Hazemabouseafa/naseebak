import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../models/subscription_model.dart';

class SubscriptionOverviewResponse {
  final SubscriptionEntitlementModel entitlement;
  final SubscriptionRecordModel? currentSubscription;
  final String googlePlayManageUrl;

  const SubscriptionOverviewResponse({
    required this.entitlement,
    this.currentSubscription,
    required this.googlePlayManageUrl,
  });
}

class SubscriptionRepository {
  final ApiClient _apiClient;

  SubscriptionRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// GET /api/v1/subscription
  Future<SubscriptionOverviewResponse> fetchSubscriptionOverview() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.subscription);
      final data = response.data['data'] as Map<String, dynamic>? ?? {};

      final entitlementJson =
          data['entitlement'] as Map<String, dynamic>? ?? {};
      final subJson = data['subscription'] as Map<String, dynamic>?;
      final manageUrl = (data['google_play_manage_url'] ??
              'https://play.google.com/store/account/subscriptions')
          .toString();

      return SubscriptionOverviewResponse(
        entitlement: SubscriptionEntitlementModel.fromJson(entitlementJson),
        currentSubscription: subJson != null
            ? SubscriptionRecordModel.fromJson(subJson)
            : null,
        googlePlayManageUrl: manageUrl,
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  /// GET /api/v1/subscription/plans
  Future<List<SubscriptionPlanModel>> fetchPlans() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.subscriptionPlans);
      final list = response.data['data']?['plans'] as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionPlanModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  /// GET /api/v1/subscription/entitlement
  Future<SubscriptionEntitlementModel> fetchEntitlement() async {
    try {
      final response =
          await _apiClient.dio.get(ApiEndpoints.subscriptionEntitlement);
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      return SubscriptionEntitlementModel.fromJson(data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  /// POST /api/v1/subscription/google-play/verify
  Future<SubscriptionOverviewResponse> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
    String? packageName,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.subscriptionVerifyGooglePlay,
        data: {
          'product_id': productId,
          'purchase_token': purchaseToken,
          if (packageName != null && packageName.isNotEmpty)
            'package_name': packageName,
        },
      );

      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final entitlementJson =
          data['entitlement'] as Map<String, dynamic>? ?? {};
      final subJson = data['subscription'] as Map<String, dynamic>?;

      return SubscriptionOverviewResponse(
        entitlement: SubscriptionEntitlementModel.fromJson(entitlementJson),
        currentSubscription: subJson != null
            ? SubscriptionRecordModel.fromJson(subJson)
            : null,
        googlePlayManageUrl:
            'https://play.google.com/store/account/subscriptions',
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  /// GET /api/v1/subscription/history
  Future<List<SubscriptionRecordModel>> fetchSubscriptionHistory() async {
    try {
      final response =
          await _apiClient.dio.get(ApiEndpoints.subscriptionHistory);
      final list =
          response.data['data']?['subscriptions'] as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionRecordModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['message'] != null) {
      return data['message'].toString();
    }
    return 'تعذر الاتصال بخادم نَصِيبُكَ للتحقق من حالة الاشتراك. يرجى المحاولة مرة أخرى.';
  }
}
