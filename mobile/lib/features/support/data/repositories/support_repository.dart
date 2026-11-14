import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/support_ticket_model.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(apiClient: ref.watch(apiClientProvider));
});

class SupportTicketSubmitResult {
  final SupportTicketModel ticket;
  final String message;

  const SupportTicketSubmitResult({
    required this.ticket,
    required this.message,
  });
}

class SupportRepository {
  final ApiClient _apiClient;

  const SupportRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  Map<String, dynamic> _extractDataMap(dynamic body) {
    if (body is Map) {
      final inner = body['data'];
      if (inner is Map) {
        return Map<String, dynamic>.from(inner);
      }
      return Map<String, dynamic>.from(body);
    }
    return const <String, dynamic>{};
  }

  /// GET /api/v1/support/tickets
  Future<PaginatedSupportTicketsResponse> fetchTickets({
    int page = 1,
    int perPage = 20,
    String? type,
    String? status,
  }) async {
    final response = await _apiClient.dio.get<dynamic>(
      ApiEndpoints.supportTickets,
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (type != null && type.isNotEmpty) 'type': type,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );

    return PaginatedSupportTicketsResponse.fromJson(_extractDataMap(response.data));
  }

  /// POST /api/v1/support/tickets
  Future<SupportTicketSubmitResult> createTicket({
    required String type,
    required String category,
    required String subject,
    required String message,
  }) async {
    final response = await _apiClient.dio.post<dynamic>(
      ApiEndpoints.supportTickets,
      data: {
        'type': type,
        'category': category,
        'subject': subject.trim(),
        'message': message.trim(),
      },
    );

    final raw = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : const <String, dynamic>{};
    final data = _extractDataMap(response.data);
    final rawTicket = data['ticket'] is Map
        ? Map<String, dynamic>.from(data['ticket'] as Map)
        : data;

    return SupportTicketSubmitResult(
      ticket: SupportTicketModel.fromJson(rawTicket),
      message: (raw['message'] ??
              'تم إرسال طلبك إلى إدارة نَصِيبُكَ بنجاح، وسيتم الرد عليك في أقرب وقت.')
          .toString(),
    );
  }

  /// GET /api/v1/support/tickets/{id}
  Future<SupportTicketModel> fetchTicketDetail(int ticketId) async {
    final response = await _apiClient.dio.get<dynamic>(
      ApiEndpoints.supportTicketDetail(ticketId),
    );
    final data = _extractDataMap(response.data);
    final rawTicket = data['ticket'] is Map
        ? Map<String, dynamic>.from(data['ticket'] as Map)
        : data;
    return SupportTicketModel.fromJson(rawTicket);
  }

  /// POST /api/v1/support/tickets/{id}/replies
  Future<SupportTicketModel> sendMemberReply({
    required int ticketId,
    required String body,
  }) async {
    final response = await _apiClient.dio.post<dynamic>(
      ApiEndpoints.supportTicketReplies(ticketId),
      data: {'body': body.trim()},
    );
    final data = _extractDataMap(response.data);
    final rawTicket = data['ticket'] is Map
        ? Map<String, dynamic>.from(data['ticket'] as Map)
        : data;
    return SupportTicketModel.fromJson(rawTicket);
  }

  static String extractErrorMessage(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final firstValue = errors.values.first;
          if (firstValue is List && firstValue.isNotEmpty) {
            return firstValue.first.toString();
          }
          if (firstValue != null) {
            return firstValue.toString();
          }
        }
        final message = data['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          return message;
        }
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'تعذر الاتصال بالخادم حاليًا، يرجى التحقق من الإنترنت والمحاولة مرة أخرى.';
      }
    }
    return fallback;
  }
}
