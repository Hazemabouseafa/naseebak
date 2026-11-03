import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../models/matchmaking_request_model.dart';

final matchmakingRepositoryProvider = Provider<MatchmakingRepository>((ref) {
  return MatchmakingRepository(dio: ref.watch(dioProvider));
});

class MatchmakingRepository {
  final Dio _dio;

  MatchmakingRepository({required Dio dio}) : _dio = dio;

  Future<MatchmakingRequestsBundle> fetchAllRequests() async {
    final response = await _dio.get(ApiEndpoints.matchmakingRequests);
    final body = response.data as Map<String, dynamic>;
    final data =
        body['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return MatchmakingRequestsBundle.fromJson(data);
  }

  Future<MatchmakingCreateResult> sendMatchmakingRequest(int recipientId) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.matchmakingRequests,
        data: {'recipient_id': recipientId},
      );
      final body = response.data as Map<String, dynamic>;
      final data =
          body['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      final rawReq = data['request'] as Map<String, dynamic>?;

      return MatchmakingCreateResult(
        isSuccess: true,
        message: (body['message'] as String?) ?? 'تم إرسال طلب التعارف بنجاح',
        request:
            rawReq != null ? MatchmakingRequestItemModel.fromJson(rawReq) : null,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final code = data is Map<String, dynamic> ? data['code'] as String? : null;
      final msg = data is Map<String, dynamic>
          ? (data['message'] as String? ?? 'تعذر إرسال طلب التعارف.')
          : 'تعذر إرسال طلب التعارف.';

      return MatchmakingCreateResult(
        isSuccess: false,
        isSubscriptionRequired: code == 'SUBSCRIPTION_REQUIRED',
        errorCode: code,
        message: msg,
      );
    }
  }

  /// Accepts an incoming pending matchmaking request and returns the created conversation ID.
  Future<({MatchmakingRequestItemModel? request, int? conversationId, String message})>
      acceptRequest(int requestId) async {
    final response = await _dio.post(
      ApiEndpoints.acceptMatchmakingRequest(requestId),
    );
    final body = response.data as Map<String, dynamic>;
    final data =
        body['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final rawReq = data['request'] as Map<String, dynamic>?;

    return (
      request: rawReq != null && rawReq.containsKey('member')
          ? MatchmakingRequestItemModel.fromJson(rawReq)
          : null,
      conversationId: (data['conversation_id'] as num?)?.toInt(),
      message: (body['message'] as String?) ??
          'تم قبول طلب التعارف وفتح المحادثة الخاصة بنجاح.',
    );
  }

  Future<String> rejectRequest(int requestId) async {
    final response = await _dio.post(
      ApiEndpoints.rejectMatchmakingRequest(requestId),
    );
    final body = response.data as Map<String, dynamic>;
    return (body['message'] as String?) ?? 'تم رفض طلب التعارف.';
  }

  Future<String> cancelRequest(int requestId) async {
    final response = await _dio.post(
      ApiEndpoints.cancelMatchmakingRequest(requestId),
    );
    final body = response.data as Map<String, dynamic>;
    return (body['message'] as String?) ?? 'تم إلغاء طلب التعارف المرسل.';
  }
}
