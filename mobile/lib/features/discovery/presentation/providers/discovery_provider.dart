import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/member_profile_model.dart';
import '../../data/models/search_preferences_model.dart';
import '../../data/repositories/discovery_repository.dart';

class DiscoveryState {
  // Screen 07: Discovery Home
  final bool isLoadingDiscovery;
  final List<MemberCardModel> suggestedMembers;
  final String? discoveryError;

  // Screen 08 & 09: Search Filters & Paginated Search Results
  final SearchPreferencesModel filters;
  final bool isSearchingInitial;
  final bool isLoadingMore;
  final List<MemberCardModel> searchResults;
  final int currentPage;
  final int totalMatching;
  final bool hasMorePages;
  final String? searchError;
  final String? paginationError;

  // Screen 16: Favorites
  final bool isLoadingFavorites;
  final List<MemberCardModel> favorites;
  final String? favoritesError;

  // Screen 10: Active Member Profile Detail
  final bool isLoadingMemberDetail;
  final MemberProfileDetailModel? activeMemberProfile;
  final String? memberDetailError;

  const DiscoveryState({
    this.isLoadingDiscovery = false,
    this.suggestedMembers = const [],
    this.discoveryError,
    this.filters = const SearchPreferencesModel(),
    this.isSearchingInitial = false,
    this.isLoadingMore = false,
    this.searchResults = const [],
    this.currentPage = 1,
    this.totalMatching = 0,
    this.hasMorePages = false,
    this.searchError,
    this.paginationError,
    this.isLoadingFavorites = false,
    this.favorites = const [],
    this.favoritesError,
    this.isLoadingMemberDetail = false,
    this.activeMemberProfile,
    this.memberDetailError,
  });

  DiscoveryState copyWith({
    bool? isLoadingDiscovery,
    List<MemberCardModel>? suggestedMembers,
    String? discoveryError,
    bool clearDiscoveryError = false,
    SearchPreferencesModel? filters,
    bool? isSearchingInitial,
    bool? isLoadingMore,
    List<MemberCardModel>? searchResults,
    int? currentPage,
    int? totalMatching,
    bool? hasMorePages,
    String? searchError,
    bool clearSearchError = false,
    String? paginationError,
    bool clearPaginationError = false,
    bool? isLoadingFavorites,
    List<MemberCardModel>? favorites,
    String? favoritesError,
    bool clearFavoritesError = false,
    bool? isLoadingMemberDetail,
    MemberProfileDetailModel? activeMemberProfile,
    bool clearActiveMemberProfile = false,
    String? memberDetailError,
    bool clearMemberDetailError = false,
  }) {
    return DiscoveryState(
      isLoadingDiscovery: isLoadingDiscovery ?? this.isLoadingDiscovery,
      suggestedMembers: suggestedMembers ?? this.suggestedMembers,
      discoveryError:
          clearDiscoveryError ? null : (discoveryError ?? this.discoveryError),
      filters: filters ?? this.filters,
      isSearchingInitial: isSearchingInitial ?? this.isSearchingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      searchResults: searchResults ?? this.searchResults,
      currentPage: currentPage ?? this.currentPage,
      totalMatching: totalMatching ?? this.totalMatching,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      searchError: clearSearchError ? null : (searchError ?? this.searchError),
      paginationError: clearPaginationError
          ? null
          : (paginationError ?? this.paginationError),
      isLoadingFavorites: isLoadingFavorites ?? this.isLoadingFavorites,
      favorites: favorites ?? this.favorites,
      favoritesError:
          clearFavoritesError ? null : (favoritesError ?? this.favoritesError),
      isLoadingMemberDetail:
          isLoadingMemberDetail ?? this.isLoadingMemberDetail,
      activeMemberProfile: clearActiveMemberProfile
          ? null
          : (activeMemberProfile ?? this.activeMemberProfile),
      memberDetailError: clearMemberDetailError
          ? null
          : (memberDetailError ?? this.memberDetailError),
    );
  }
}

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DiscoveryRepository(apiClient);
});

class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  final DiscoveryRepository _repository;

  DiscoveryNotifier(this._repository) : super(const DiscoveryState());

  /// Loads Screen 07 Discovery Feed (real backend records only; never generates fake members)
  Future<void> loadDiscoveryFeed() async {
    state = state.copyWith(
      isLoadingDiscovery: true,
      clearDiscoveryError: true,
    );

    try {
      final result = await _repository.fetchDiscoveryFeed();
      state = state.copyWith(
        isLoadingDiscovery: false,
        suggestedMembers: result.suggestedMembers,
        filters: result.savedPreferences,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingDiscovery: false,
        discoveryError: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Updates search filter state in memory
  void updateFilters(SearchPreferencesModel updatedFilters) {
    state = state.copyWith(
      filters: updatedFilters,
      clearSearchError: true,
    );
  }

  /// Resets search filters to default adult parameters (18-60)
  void resetFilters({String? defaultGender}) {
    state = state.copyWith(
      filters: SearchPreferencesModel(
        gender: defaultGender,
        minAge: 18,
        maxAge: 60,
      ),
      clearSearchError: true,
    );
  }

  /// Loads saved search preferences from GET /api/v1/search/preferences
  Future<void> loadSavedPreferences() async {
    try {
      final saved = await _repository.fetchSavedSearchPreferences();
      state = state.copyWith(filters: saved, clearSearchError: true);
    } catch (_) {
      // Preserve current in-memory filters if offline
    }
  }

  /// Executes Page 1 search against PostgreSQL backend (20 per page)
  Future<bool> executeSearch({bool savePreferences = true}) async {
    final validationError = state.filters.validate();
    if (validationError != null) {
      state = state.copyWith(searchError: validationError);
      return false;
    }

    state = state.copyWith(
      isSearchingInitial: true,
      clearSearchError: true,
      clearPaginationError: true,
    );

    try {
      final response = await _repository.searchMembers(
        filters: state.filters,
        page: 1,
        perPage: 20,
        savePreferences: savePreferences,
      );

      state = state.copyWith(
        isSearchingInitial: false,
        searchResults: response.members,
        currentPage: response.currentPage,
        totalMatching: response.total,
        hasMorePages: response.hasMorePages,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSearchingInitial: false,
        searchError: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Loads the next page of search results (prevents duplicate concurrent requests)
  Future<void> loadNextSearchPage() async {
    if (state.isSearchingInitial ||
        state.isLoadingMore ||
        !state.hasMorePages) {
      return;
    }

    state = state.copyWith(
      isLoadingMore: true,
      clearPaginationError: true,
    );

    try {
      final nextPage = state.currentPage + 1;
      final response = await _repository.searchMembers(
        filters: state.filters,
        page: nextPage,
        perPage: 20,
        savePreferences: false,
      );

      // Deduplicate by userId in case of concurrent database writes
      final existingIds = state.searchResults.map((m) => m.userId).toSet();
      final newUniqueMembers = response.members
          .where((m) => !existingIds.contains(m.userId))
          .toList();

      state = state.copyWith(
        isLoadingMore: false,
        searchResults: [...state.searchResults, ...newUniqueMembers],
        currentPage: response.currentPage,
        totalMatching: response.total,
        hasMorePages: response.hasMorePages,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        paginationError: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Changes sort order ('newest' | 'age_asc' | 'age_desc') and re-queries page 1
  Future<void> changeSortOrder(String newSort) async {
    if (state.filters.sort == newSort) return;
    state = state.copyWith(
      filters: state.filters.copyWith(sort: newSort),
    );
    await executeSearch(savePreferences: false);
  }

  /// Removes a single filter chip on Screen 09 and re-runs the backend search
  Future<void> removeFilterChipAndRefresh(String chipKey) async {
    final updated = state.filters.removeFilterByKey(chipKey);
    state = state.copyWith(filters: updated);
    await executeSearch(savePreferences: true);
  }

  /// Loads a member's full permitted public profile (Screen 10)
  Future<void> loadMemberProfile(int targetUserId) async {
    state = state.copyWith(
      isLoadingMemberDetail: true,
      clearMemberDetailError: true,
      clearActiveMemberProfile: true,
    );

    try {
      final detail = await _repository.fetchMemberProfile(targetUserId);
      state = state.copyWith(
        isLoadingMemberDetail: false,
        activeMemberProfile: detail,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMemberDetail: false,
        memberDetailError: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Loads Screen 16 Favorites from GET /api/v1/favorites
  Future<void> loadFavorites() async {
    state = state.copyWith(
      isLoadingFavorites: true,
      clearFavoritesError: true,
    );

    try {
      final list = await _repository.fetchFavorites();
      state = state.copyWith(
        isLoadingFavorites: false,
        favorites: list,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingFavorites: false,
        favoritesError: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Toggles favorite status on the backend and synchronizes across Discovery, Search Results, Favorites, and Active Profile
  Future<String?> toggleFavorite(MemberCardModel member) async {
    final targetId = member.userId;
    final currentlyFavorited = member.isFavorited;
    final nextFavorited = !currentlyFavorited;

    try {
      if (nextFavorited) {
        await _repository.addFavorite(targetId);
      } else {
        await _repository.removeFavorite(targetId);
      }

      final updatedSuggested = state.suggestedMembers
          .map((m) => m.userId == targetId
              ? m.copyWith(isFavorited: nextFavorited)
              : m)
          .toList();

      final updatedSearch = state.searchResults
          .map((m) => m.userId == targetId
              ? m.copyWith(isFavorited: nextFavorited)
              : m)
          .toList();

      List<MemberCardModel> updatedFavorites;
      if (nextFavorited) {
        final exists = state.favorites.any((m) => m.userId == targetId);
        updatedFavorites = exists
            ? state.favorites
                .map((m) => m.userId == targetId
                    ? m.copyWith(isFavorited: true)
                    : m)
                .toList()
            : [member.copyWith(isFavorited: true), ...state.favorites];
      } else {
        updatedFavorites =
            state.favorites.where((m) => m.userId != targetId).toList();
      }

      final updatedActive = state.activeMemberProfile?.userId == targetId
          ? state.activeMemberProfile!.copyWith(isFavorited: nextFavorited)
          : state.activeMemberProfile;

      state = state.copyWith(
        suggestedMembers: updatedSuggested,
        searchResults: updatedSearch,
        favorites: updatedFavorites,
        activeMemberProfile: updatedActive,
      );

      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Blocks a member on the backend and immediately removes them from local lists
  Future<String?> blockMember({
    required int memberUserId,
    String? reason,
  }) async {
    try {
      await _repository.blockMember(
        memberUserId: memberUserId,
        reason: reason,
      );

      state = state.copyWith(
        suggestedMembers: state.suggestedMembers
            .where((m) => m.userId != memberUserId)
            .toList(),
        searchResults: state.searchResults
            .where((m) => m.userId != memberUserId)
            .toList(),
        favorites: state.favorites
            .where((m) => m.userId != memberUserId)
            .toList(),
        clearActiveMemberProfile: true,
      );
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Reports a member to administrators on the backend
  Future<String?> reportMember({
    required int memberUserId,
    required String reasonCategory,
    required String details,
    int? conversationId,
    int? messageId,
  }) async {
    try {
      await _repository.reportMember(
        memberUserId: memberUserId,
        reasonCategory: reasonCategory,
        details: details,
        conversationId: conversationId,
        messageId: messageId,
      );
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Updates the matchmaking button state on the currently loaded MemberProfileDetailModel
  void updateActiveMemberMatchmakingState({
    required String buttonState,
    int? requestId,
    String? requestStatus,
    int? conversationId,
  }) {
    final active = state.activeMemberProfile;
    if (active == null) return;
    state = state.copyWith(
      activeMemberProfile: active.copyWith(
        matchmakingButtonState: buttonState,
        matchmakingRequestId: requestId,
        matchmakingRequestStatus: requestStatus,
        matchmakingConversationId: conversationId,
      ),
    );
  }
}

final discoveryProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
  final repo = ref.watch(discoveryRepositoryProvider);
  return DiscoveryNotifier(repo);
});
