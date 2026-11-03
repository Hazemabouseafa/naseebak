import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../models/member_profile_model.dart';
import '../models/search_preferences_model.dart';

class DiscoveryRepository {
  final ApiClient _apiClient;

  const DiscoveryRepository(this._apiClient);

  /// GET /api/v1/discovery
  /// Fetches real suggested members and saved search preferences.
  Future<({
    List<MemberCardModel> suggestedMembers,
    SearchPreferencesModel savedPreferences,
  })> fetchDiscoveryFeed() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        ApiEndpoints.discovery,
      );
      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
      final rawSuggested =
          (data['suggested_members'] as List<dynamic>?) ?? const [];
      final rawPrefs =
          (data['saved_preferences'] as Map<String, dynamic>?) ?? const {};

      final members = rawSuggested
          .whereType<Map<String, dynamic>>()
          .map(MemberCardModel.fromJson)
          .toList();

      return (
        suggestedMembers: members,
        savedPreferences: SearchPreferencesModel.fromJson(rawPrefs),
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(
        e,
        fallback: 'تعذر تحميل قائمة الأعضاء المقترحين حالياً.',
      ));
    }
  }

  /// GET /api/v1/members/search
  /// Executes server-side PostgreSQL search with pagination and sorting.
  Future<PaginatedMembersResponse> searchMembers({
    required SearchPreferencesModel filters,
    required int page,
    int perPage = 20,
    bool savePreferences = false,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        ApiEndpoints.membersSearch,
        queryParameters: filters.toQueryParameters(
          page: page,
          perPage: perPage,
          savePreferences: savePreferences,
        ),
      );

      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
      return PaginatedMembersResponse.fromJson(data);
    } on DioException catch (e) {
      throw Exception(_mapDioError(
        e,
        fallback: 'تعذر تنفيذ عملية البحث. يرجى المحاولة مرة أخرى.',
      ));
    }
  }

  /// GET /api/v1/search/preferences
  Future<SearchPreferencesModel> fetchSavedSearchPreferences() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        ApiEndpoints.searchPreferences,
      );
      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
      final prefsMap =
          (data['preferences'] as Map<String, dynamic>?) ?? const {};
      return SearchPreferencesModel.fromJson(prefsMap);
    } on DioException catch (e) {
      throw Exception(_mapDioError(
        e,
        fallback: 'تعذر استرجاع تفضيلات البحث المحفوظة.',
      ));
    }
  }

  /// PUT /api/v1/search/preferences
  Future<SearchPreferencesModel> saveSearchPreferences(
    SearchPreferencesModel preferences,
  ) async {
    try {
      final response = await _apiClient.dio.put<Map<String, dynamic>>(
        ApiEndpoints.searchPreferences,
        data: preferences.toPreferenceBody(),
      );
      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
      final prefsMap =
          (data['preferences'] as Map<String, dynamic>?) ?? const {};
      return SearchPreferencesModel.fromJson(prefsMap).copyWith(
        sort: preferences.sort,
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(
        e,
        fallback: 'تعذر حفظ معايير البحث.',
      ));
    }
  }

  /// GET /api/v1/members/{targetUser}/profile
  Future<MemberProfileDetailModel> fetchMemberProfile(int targetUserId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        ApiEndpoints.memberProfile(targetUserId),
      );
      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
      final memberMap = (data['member'] as Map<String, dynamic>?) ?? {};
      final entitlementMap =
          (data['viewer_entitlement'] as Map<String, dynamic>?) ?? {};
      final matchmakingMap = data['matchmaking'] as Map<String, dynamic>?;
      final hasActiveSub =
          (entitlementMap['has_active_subscription'] as bool?) ?? false;
      final canSendMatchRequests =
          (entitlementMap['can_send_match_requests'] as bool?) ?? hasActiveSub;
      final canSendMessages =
          (entitlementMap['can_send_messages'] as bool?) ?? hasActiveSub;

      return MemberProfileDetailModel.fromJson(
        memberMap,
        viewerHasActiveSubscription: hasActiveSub,
        viewerCanSendMatchRequests: canSendMatchRequests,
        viewerCanSendMessages: canSendMessages,
        matchmakingJson: matchmakingMap,
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(
        e,
        fallback: 'هذا الملف الشخصي غير متاح للعرض.',
      ));
    }
  }

  /// GET /api/v1/favorites
  Future<List<MemberCardModel>> fetchFavorites() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        ApiEndpoints.favorites,
      );
      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
      final rawList = (data['favorites'] as List<dynamic>?) ?? const [];

      return rawList
          .whereType<Map<String, dynamic>>()
          .map(MemberCardModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw Exception(_mapDioError(
        e,
        fallback: 'تعذر تحميل قائمة المفضلة.',
      ));
    }
  }

  /// POST /api/v1/favorites/{member}
  Future<void> addFavorite(int memberUserId) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.favoriteMember(memberUserId),
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(
        e,
        fallback: 'تعذر إضافة العضو إلى المفضلة.',
      ));
    }
  }

  /// DELETE /api/v1/favorites/{member}
  Future<void> removeFavorite(int memberUserId) async {
    try {
      await _apiClient.dio.delete<Map<String, dynamic>>(
        ApiEndpoints.favoriteMember(memberUserId),
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(
        e,
        fallback: 'تعذر إزالة العضو من المفضلة.',
      ));
    }
  }

  /// POST /api/v1/members/{member}/block
  Future<void> blockMember({
    required int memberUserId,
    String? reason,
  }) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.blockMember(memberUserId),
        data: {'reason': reason},
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(
        e,
        fallback: 'تعذر تنفيذ حظر العضو حالياً.',
      ));
    }
  }

  /// POST /api/v1/members/{member}/report
  Future<void> reportMember({
    required int memberUserId,
    required String reasonCategory,
    required String details,
    int? conversationId,
    int? messageId,
  }) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.reportMember(memberUserId),
        data: {
          'reason_category': reasonCategory,
          'details': details,
          if (conversationId != null) 'conversation_id': conversationId,
          if (messageId != null) 'message_id': messageId,
        },
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(
        e,
        fallback: 'تعذر إرسال البلاغ حالياً.',
      ));
    }
  }

  /// GET /api/v1/profile/photos/{photoId}/stream
  Future<Uint8List> fetchAuthorizedPhotoBytes(int photoId) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        ApiEndpoints.photoStream(photoId),
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const <int>[]);
    } on DioException catch (e) {
      throw Exception(_mapDioError(
        e,
        fallback: 'الصورة الشخصية محمية وفقاً لإعدادات الخصوصية.',
      ));
    }
  }

  String _mapDioError(DioException e, {required String fallback}) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'انتهت مهلة الاتصال بالخادم. يرجى التحقق من جودة الإنترنت والمحاولة مرة أخرى.';
    }

    if (e.type == DioExceptionType.connectionError) {
      return 'لا يوجد اتصال بالإنترنت أو تعذر الوصول إلى خادم نصيبك.';
    }

    final statusCode = e.response?.statusCode;
    if (statusCode == 401) {
      return 'انتهت صلاحية الجلسة. يرجى إعادة تسجيل الدخول.';
    }

    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final firstField = errors.values.first;
        if (firstField is List && firstField.isNotEmpty) {
          return firstField.first.toString();
        }
      }
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    return fallback;
  }
}
