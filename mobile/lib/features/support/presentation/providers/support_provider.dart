import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/support_ticket_model.dart';
import '../../data/repositories/support_repository.dart';

class SupportTicketsState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSubmitting;
  final List<SupportTicketModel> tickets;
  final String? selectedTypeFilter; // null | 'inquiry' | 'complaint'
  final int currentPage;
  final bool hasMorePages;
  final String? errorMessage;

  const SupportTicketsState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSubmitting = false,
    this.tickets = const [],
    this.selectedTypeFilter,
    this.currentPage = 1,
    this.hasMorePages = false,
    this.errorMessage,
  });

  SupportTicketsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSubmitting,
    List<SupportTicketModel>? tickets,
    String? selectedTypeFilter,
    bool clearTypeFilter = false,
    int? currentPage,
    bool? hasMorePages,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SupportTicketsState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      tickets: tickets ?? this.tickets,
      selectedTypeFilter: clearTypeFilter
          ? null
          : (selectedTypeFilter ?? this.selectedTypeFilter),
      currentPage: currentPage ?? this.currentPage,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final supportTicketsProvider =
    StateNotifierProvider<SupportTicketsNotifier, SupportTicketsState>((ref) {
  return SupportTicketsNotifier(
    repository: ref.watch(supportRepositoryProvider),
  );
});

class SupportTicketsNotifier extends StateNotifier<SupportTicketsState> {
  final SupportRepository _repository;

  SupportTicketsNotifier({required SupportRepository repository})
      : _repository = repository,
        super(const SupportTicketsState());

  Future<void> fetchTickets({
    bool refresh = false,
    String? typeFilter,
    bool updateTypeFilter = false,
  }) async {
    final effectiveType =
        updateTypeFilter ? typeFilter : state.selectedTypeFilter;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      selectedTypeFilter: effectiveType,
      clearTypeFilter: updateTypeFilter && typeFilter == null,
    );

    try {
      final result = await _repository.fetchTickets(
        page: 1,
        type: effectiveType,
      );
      state = state.copyWith(
        isLoading: false,
        tickets: result.tickets,
        currentPage: result.currentPage,
        hasMorePages: result.hasMorePages,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: SupportRepository.extractErrorMessage(
          e,
          'تعذر تحميل قائمة الاستفسارات والشكاوى.',
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMorePages) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repository.fetchTickets(
        page: state.currentPage + 1,
        type: state.selectedTypeFilter,
      );
      final existingIds = state.tickets.map((t) => t.id).toSet();
      final appended =
          result.tickets.where((t) => !existingIds.contains(t.id)).toList();

      state = state.copyWith(
        isLoadingMore: false,
        tickets: [...state.tickets, ...appended],
        currentPage: result.currentPage,
        hasMorePages: result.hasMorePages,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<SupportTicketSubmitResult> createTicket({
    required String type,
    required String category,
    required String subject,
    required String message,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final result = await _repository.createTicket(
        type: type,
        category: category,
        subject: subject,
        message: message,
      );

      final matchesFilter = state.selectedTypeFilter == null ||
          state.selectedTypeFilter == result.ticket.type;

      state = state.copyWith(
        isSubmitting: false,
        tickets: matchesFilter
            ? [result.ticket, ...state.tickets]
            : state.tickets,
      );

      return result;
    } catch (e) {
      state = state.copyWith(isSubmitting: false);
      rethrow;
    }
  }

  void upsertTicket(SupportTicketModel updated) {
    final index = state.tickets.indexWhere((t) => t.id == updated.id);
    if (index == -1) {
      state = state.copyWith(tickets: [updated, ...state.tickets]);
      return;
    }
    final next = [...state.tickets];
    next[index] = updated;
    state = state.copyWith(tickets: next);
  }
}

class SupportTicketDetailState {
  final bool isLoading;
  final bool isSendingReply;
  final SupportTicketModel? ticket;
  final String? errorMessage;

  const SupportTicketDetailState({
    this.isLoading = false,
    this.isSendingReply = false,
    this.ticket,
    this.errorMessage,
  });

  SupportTicketDetailState copyWith({
    bool? isLoading,
    bool? isSendingReply,
    SupportTicketModel? ticket,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SupportTicketDetailState(
      isLoading: isLoading ?? this.isLoading,
      isSendingReply: isSendingReply ?? this.isSendingReply,
      ticket: ticket ?? this.ticket,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final supportTicketDetailProvider = StateNotifierProvider.autoDispose
    .family<SupportTicketDetailNotifier, SupportTicketDetailState, int>(
        (ref, ticketId) {
  return SupportTicketDetailNotifier(
    ticketId: ticketId,
    repository: ref.watch(supportRepositoryProvider),
    ticketsNotifier: ref.watch(supportTicketsProvider.notifier),
  )..loadDetail();
});

class SupportTicketDetailNotifier
    extends StateNotifier<SupportTicketDetailState> {
  final int ticketId;
  final SupportRepository _repository;
  final SupportTicketsNotifier _ticketsNotifier;

  SupportTicketDetailNotifier({
    required this.ticketId,
    required SupportRepository repository,
    required SupportTicketsNotifier ticketsNotifier,
  })  : _repository = repository,
        _ticketsNotifier = ticketsNotifier,
        super(const SupportTicketDetailState(isLoading: true));

  Future<void> loadDetail() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ticket = await _repository.fetchTicketDetail(ticketId);
      state = state.copyWith(isLoading: false, ticket: ticket);
      _ticketsNotifier.upsertTicket(ticket);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: SupportRepository.extractErrorMessage(
          e,
          'تعذر تحميل تفاصيل الطلب.',
        ),
      );
    }
  }

  Future<void> sendReply(String body) async {
    state = state.copyWith(isSendingReply: true, clearError: true);
    try {
      final updated = await _repository.sendMemberReply(
        ticketId: ticketId,
        body: body,
      );
      state = state.copyWith(isSendingReply: false, ticket: updated);
      _ticketsNotifier.upsertTicket(updated);
    } catch (e) {
      state = state.copyWith(isSendingReply: false);
      rethrow;
    }
  }
}
