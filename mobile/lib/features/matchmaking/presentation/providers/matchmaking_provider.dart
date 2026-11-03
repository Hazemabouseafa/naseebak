import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/matchmaking_request_model.dart';
import '../../data/repositories/matchmaking_repository.dart';

class MatchmakingState {
  final bool isLoading;
  final bool isMutating;
  final List<MatchmakingRequestItemModel> incoming;
  final List<MatchmakingRequestItemModel> sent;
  final List<MatchmakingRequestItemModel> accepted;
  final String? errorMessage;

  const MatchmakingState({
    this.isLoading = false,
    this.isMutating = false,
    this.incoming = const [],
    this.sent = const [],
    this.accepted = const [],
    this.errorMessage,
  });

  MatchmakingState copyWith({
    bool? isLoading,
    bool? isMutating,
    List<MatchmakingRequestItemModel>? incoming,
    List<MatchmakingRequestItemModel>? sent,
    List<MatchmakingRequestItemModel>? accepted,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MatchmakingState(
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      incoming: incoming ?? this.incoming,
      sent: sent ?? this.sent,
      accepted: accepted ?? this.accepted,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final matchmakingProvider =
    StateNotifierProvider<MatchmakingNotifier, MatchmakingState>((ref) {
  return MatchmakingNotifier(
    repository: ref.watch(matchmakingRepositoryProvider),
  );
});

class MatchmakingNotifier extends StateNotifier<MatchmakingState> {
  final MatchmakingRepository _repository;

  MatchmakingNotifier({required MatchmakingRepository repository})
      : _repository = repository,
        super(const MatchmakingState());

  Future<void> loadRequests() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final bundle = await _repository.fetchAllRequests();
      state = state.copyWith(
        isLoading: false,
        incoming: bundle.incoming,
        sent: bundle.sent,
        accepted: bundle.accepted,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _extractError(e),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تحميل قائمة طلبات التعارف حالياً.',
      );
    }
  }

  Future<MatchmakingCreateResult> sendRequest(int recipientId) async {
    if (state.isMutating) {
      return const MatchmakingCreateResult(
        isSuccess: false,
        message: 'جاري إرسال الطلب بالفعل...',
      );
    }

    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final result = await _repository.sendMatchmakingRequest(recipientId);
      state = state.copyWith(isMutating: false);
      if (result.isSuccess) {
        await loadRequests();
      }
      return result;
    } catch (_) {
      state = state.copyWith(isMutating: false);
      return const MatchmakingCreateResult(
        isSuccess: false,
        message: 'تعذر إرسال طلب التعارف حالياً.',
      );
    }
  }

  Future<({int? conversationId, String? errorMessage})> acceptRequest(
      int requestId) async {
    if (state.isMutating) {
      return (conversationId: null, errorMessage: null);
    }

    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _repository.acceptRequest(requestId);
      await loadRequests();
      state = state.copyWith(isMutating: false);
      return (conversationId: res.conversationId, errorMessage: null);
    } on DioException catch (e) {
      final err = _extractError(e);
      state = state.copyWith(isMutating: false, errorMessage: err);
      return (conversationId: null, errorMessage: err);
    } catch (_) {
      const err = 'تعذر قبول طلب التعارف حالياً.';
      state = state.copyWith(isMutating: false, errorMessage: err);
      return (conversationId: null, errorMessage: err);
    }
  }

  Future<String?> rejectRequest(int requestId) async {
    if (state.isMutating) return null;

    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await _repository.rejectRequest(requestId);
      await loadRequests();
      state = state.copyWith(isMutating: false);
      return null;
    } on DioException catch (e) {
      final err = _extractError(e);
      state = state.copyWith(isMutating: false, errorMessage: err);
      return err;
    } catch (_) {
      const err = 'تعذر رفض طلب التعارف حالياً.';
      state = state.copyWith(isMutating: false, errorMessage: err);
      return err;
    }
  }

  Future<String?> cancelRequest(int requestId) async {
    if (state.isMutating) return null;

    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await _repository.cancelRequest(requestId);
      await loadRequests();
      state = state.copyWith(isMutating: false);
      return null;
    } on DioException catch (e) {
      final err = _extractError(e);
      state = state.copyWith(isMutating: false, errorMessage: err);
      return err;
    } catch (_) {
      const err = 'تعذر إلغاء طلب التعارف حالياً.';
      state = state.copyWith(isMutating: false, errorMessage: err);
      return err;
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'حدث خطأ أثناء تنفيذ العملية. يرجى المحاولة مرة أخرى.';
  }
}
