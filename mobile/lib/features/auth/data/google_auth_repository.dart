import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_session_storage.dart';
import 'auth_user_model.dart';

class GoogleAuthRepository {
  final ApiClient _apiClient;
  final SecureSessionStorage _sessionStorage;
  final GoogleSignIn _googleSignIn;

  GoogleAuthRepository({
    required ApiClient apiClient,
    required SecureSessionStorage sessionStorage,
    GoogleSignIn? googleSignIn,
  })  : _apiClient = apiClient,
        _sessionStorage = sessionStorage,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile', 'openid'],
              serverClientId: ApiEndpoints.googleServerClientId.isNotEmpty
                  ? ApiEndpoints.googleServerClientId
                  : null,
            );

  /// Performs the complete Google OAuth / OpenID Connect flow:
  /// 1. Opens Google account selection
  /// 2. Obtains a Google ID Token
  /// 3. Sends the ID token over HTTPS to Laravel (/api/v1/auth/google)
  /// 4. Stores the Laravel Sanctum session credential in FlutterSecureStorage
  Future<AuthSessionResult> signInWithGoogle() async {
    GoogleSignInAccount? googleAccount;
    try {
      // Clear any stale cached Google session so account selection mints a fresh ID token
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      googleAccount = await _googleSignIn.signIn();
    } on PlatformException catch (e) {
      throw Exception(
        'تعذر إتمام تسجيل الدخول عبر خدمات Google (${e.code}). يرجى المحاولة مرة أخرى.',
      );
    }

    if (googleAccount == null) {
      throw Exception('تم إلغاء اختيار حساب Google.');
    }

    final GoogleSignInAuthentication googleAuth;
    try {
      googleAuth = await googleAccount.authentication;
    } on PlatformException catch (e) {
      throw Exception(
        'تعذر الحصول على مصادقة حساب Google (${e.code}). يرجى المحاولة مرة أخرى.',
      );
    }

    final idToken = googleAuth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'تعذر الحصول على رمز التحقق (ID Token) من Google. تأكد من ضبط GOOGLE_SERVER_CLIENT_ID.',
      );
    }

    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.authGoogle,
        data: {
          'id_token': idToken,
          'device_name': 'Naseebak Android Client',
        },
      );

      final body = response.data ?? {};
      final data = (body['data'] as Map<String, dynamic>?) ?? {};
      final token = (data['token'] as String?) ?? '';

      if (token.isEmpty) {
        throw Exception('لم يتم استلام رمز الجلسة من الخادم.');
      }

      await _sessionStorage.saveToken(token);

      final userMap = (data['user'] as Map<String, dynamic>?) ?? {};
      final user = AuthUserModel.fromJson(
        userMap,
        googleSuggestedName: (data['google_suggested_name'] as String?) ??
            (data['google_Suggested_name'] as String?) ??
            googleAccount.displayName,
      );

      return AuthSessionResult(
        token: token,
        isNewUser: (data['is_new_user'] as bool?) ?? false,
        nextRoute: (data['next_route'] as String?) ??
            (user.profileCompleted ? 'home' : 'complete_profile'),
        user: user,
      );
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (e.response?.statusCode == 403 &&
          responseData is Map<String, dynamic> &&
          responseData['code'] == 'ACCOUNT_SUSPENDED') {
        await _sessionStorage.clearToken();
        throw SuspendedAccountException(
          message: (responseData['message'] as String?) ??
              'تم تقييد هذا الحساب من قِبل الإدارة.',
          reason: (responseData['suspension_reason'] as String?) ??
              'مخالفة شروط الاستخدام.',
        );
      }

      final serverMessage = responseData is Map<String, dynamic>
          ? (responseData['message'] as String?)
          : null;
      throw Exception(
        serverMessage ?? 'تعذر الاتصال بخادم نَصِيبُكَ. يرجى التحقق من اتصال الإنترنت.',
      );
    }
  }

  /// Restores an existing Sanctum session on app startup
  Future<AuthUserModel?> restoreSession() async {
    final token = await _sessionStorage.readToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        ApiEndpoints.authMe,
      );
      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
      final userMap = (data['user'] as Map<String, dynamic>?) ?? {};
      return AuthUserModel.fromJson(userMap);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (e.response?.statusCode == 403 &&
          responseData is Map<String, dynamic> &&
          responseData['code'] == 'ACCOUNT_SUSPENDED') {
        await _sessionStorage.clearToken();
        throw SuspendedAccountException(
          message: (responseData['message'] as String?) ??
              'تم تقييد هذا الحساب من قِبل الإدارة.',
          reason: (responseData['suspension_reason'] as String?) ??
              'مخالفة شروط الاستخدام.',
        );
      }
      if (e.response?.statusCode == 401) {
        await _sessionStorage.clearToken();
      }
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _apiClient.dio.post<void>(ApiEndpoints.authLogout);
    } catch (_) {
      // Ignore network errors during logout cleanup
    } finally {
      await _sessionStorage.clearToken();
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }

  /// Sends DELETE /api/v1/auth/account to purge all personal data, photos, and revoke session
  Future<Map<String, dynamic>> deleteAccount({
    required String confirmation,
    String? reason,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.dio.delete<Map<String, dynamic>>(
        ApiEndpoints.authDeleteAccount,
        data: {
          'confirmation': confirmation,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
      final body = response.data ?? {};
      return (body['data'] as Map<String, dynamic>?) ?? {};
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('تعذر إتمام طلب حذف الحساب حالياً. يرجى المحاولة مرة أخرى.');
    } finally {
      await _sessionStorage.clearToken();
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }
}
