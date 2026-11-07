import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_session_storage.dart';
import '../../data/auth_user_model.dart';
import '../../data/google_auth_repository.dart';

enum AuthDestination {
  welcome,
  googleSignIn,
  completeProfile,
  home,
  suspended,
}

class AuthState {
  final bool isLoading;
  final AuthDestination destination;
  final AuthUserModel? user;
  final String? errorMessage;
  final String? suspensionReason;

  const AuthState({
    this.isLoading = false,
    this.destination = AuthDestination.welcome,
    this.user,
    this.errorMessage,
    this.suspensionReason,
  });

  AuthState copyWith({
    bool? isLoading,
    AuthDestination? destination,
    AuthUserModel? user,
    String? errorMessage,
    String? suspensionReason,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      destination: destination ?? this.destination,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      suspensionReason: suspensionReason ?? this.suspensionReason,
    );
  }
}

final secureSessionStorageProvider = Provider<SecureSessionStorage>((ref) {
  return const SecureSessionStorage();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureSessionStorageProvider);
  return ApiClient(sessionStorage: storage);
});

final googleAuthRepositoryProvider = Provider<GoogleAuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(secureSessionStorageProvider);
  return GoogleAuthRepository(
    apiClient: apiClient,
    sessionStorage: storage,
  );
});

class AuthController extends StateNotifier<AuthState> {
  final GoogleAuthRepository _repository;

  AuthController(this._repository) : super(const AuthState()) {
    restoreExistingSession();
  }

  /// Automatically restores the persisted Sanctum session on app startup
  /// so the user never has to sign in again after closing and reopening the app.
  Future<void> restoreExistingSession() async {
    try {
      final cachedUser = await _repository.readCachedSessionUser();
      if (!mounted) return;

      if (cachedUser != null) {
        state = state.copyWith(
          user: cachedUser,
          destination: cachedUser.profileCompleted
              ? AuthDestination.home
              : AuthDestination.completeProfile,
          clearError: true,
        );
      }

      final freshUser = await _repository.restoreSession();
      if (!mounted) return;

      if (freshUser != null) {
        state = state.copyWith(
          isLoading: false,
          user: freshUser,
          destination: freshUser.profileCompleted
              ? AuthDestination.home
              : AuthDestination.completeProfile,
          clearError: true,
        );
      } else if (cachedUser != null) {
        // Server explicitly invalidated the token (401)
        state = const AuthState(
          isLoading: false,
          destination: AuthDestination.welcome,
        );
      }
    } on SuspendedAccountException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        destination: AuthDestination.suspended,
        errorMessage: e.message,
        suspensionReason: e.reason,
      );
    } catch (_) {
      // Preserve current state if storage is unavailable (e.g. in unit tests)
    }
  }

  void navigateToGoogleSignIn() {
    state = state.copyWith(
      destination: AuthDestination.googleSignIn,
      clearError: true,
    );
  }

  void navigateToWelcome() {
    state = state.copyWith(
      destination: AuthDestination.welcome,
      clearError: true,
    );
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repository.signInWithGoogle();
      final nextDest =
          (result.user.profileCompleted || result.nextRoute == 'home')
              ? AuthDestination.home
              : AuthDestination.completeProfile;

      state = state.copyWith(
        isLoading: false,
        user: result.user,
        destination: nextDest,
      );
    } on SuspendedAccountException catch (e) {
      state = state.copyWith(
        isLoading: false,
        destination: AuthDestination.suspended,
        errorMessage: e.message,
        suspensionReason: e.reason,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Navigates authenticated users with incomplete profiles to the profile completion flow.
  void navigateToCompleteProfile() {
    state = state.copyWith(
      destination: AuthDestination.completeProfile,
      clearError: true,
    );
  }

  @Deprecated('Use navigateToCompleteProfile instead')
  void enterProfileRegistrationPreview() => navigateToCompleteProfile();

  void markProfileCompleted() {
    final updatedUser = state.user?.copyWith(profileCompleted: true);
    if (updatedUser != null) {
      _repository.cacheUser(updatedUser);
    }
    state = state.copyWith(
      user: updatedUser,
      destination: AuthDestination.home,
      clearError: true,
    );
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.signOut();
    } finally {
      state = const AuthState(
        isLoading: false,
        destination: AuthDestination.welcome,
      );
    }
  }

  Future<Map<String, dynamic>> deleteAccount({
    required String confirmation,
    String? reason,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _repository.deleteAccount(
        confirmation: confirmation,
        reason: reason,
        notes: notes,
      );
      state = const AuthState(
        isLoading: false,
        destination: AuthDestination.welcome,
      );
      return data;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repo = ref.watch(googleAuthRepositoryProvider);
  return AuthController(repo);
});
