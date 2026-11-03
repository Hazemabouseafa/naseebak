import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/profile_registration_draft.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  final ApiClient _apiClient;

  const ProfileRepository(this._apiClient);

  /// GET /api/v1/profile
  Future<ProfileResponseBundle> fetchOwnProfile() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        ApiEndpoints.profile,
      );
      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
      final profileMap = data['profile'] as Map<String, dynamic>?;
      final privacyMap = (data['privacy'] as Map<String, dynamic>?) ?? {};

      final profile =
          profileMap != null ? ProfileModel.fromJson(profileMap) : null;

      return ProfileResponseBundle(
        profileCompleted: (data['profile_completed'] as bool?) ?? (profile != null),
        completionPercentage:
            (data['completion_percentage'] as num?)?.toInt() ?? 0,
        profile: profile,
        isVisible: (privacyMap['is_visible'] as bool?) ??
            (profile?.isVisible ?? true),
        photoPrivacy: (privacyMap['photo_privacy'] as String?) ??
            (profile?.photoPrivacy ?? 'public'),
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(
        e,
        fallback: 'تعذر تحميل بيانات الملف الشخصي من الخادم.',
      ));
    }
  }

  /// PATCH /api/v1/profile
  Future<ProfileResponseBundle> updateProfile(
    ProfileRegistrationDraft draft, {
    String? photoPrivacy,
  }) async {
    try {
      final payload = draft.toApiPayload();
      if (photoPrivacy != null) {
        payload['photo_privacy'] = photoPrivacy;
      }

      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        ApiEndpoints.profile,
        data: payload,
      );

      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
      final profileMap = data['profile'] as Map<String, dynamic>?;
      final profile =
          profileMap != null ? ProfileModel.fromJson(profileMap) : null;

      return ProfileResponseBundle(
        profileCompleted: (data['profile_completed'] as bool?) ?? true,
        completionPercentage:
            (data['completion_percentage'] as num?)?.toInt() ?? 90,
        profile: profile,
        isVisible: profile?.isVisible ?? draft.isVisible,
        photoPrivacy: profile?.photoPrivacy ?? (photoPrivacy ?? 'public'),
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(
        e,
        fallback: 'تعذر حفظ التعديلات على الملف الشخصي.',
      ));
    }
  }

  /// POST /api/v1/profile/photo
  /// Uploads compressed image bytes (<= 1080px, <= 2 MB) with progress callback.
  Future<ProfilePhotoMetadata> uploadProfilePhotoBytes({
    required Uint8List imageBytes,
    required String filename,
    String mimeType = 'image/jpeg',
    void Function(double progress)? onProgress,
  }) async {
    if (imageBytes.lengthInBytes > 2 * 1024 * 1024) {
      throw Exception('حجم الصورة يتجاوز الحد الأقصى المسموح به (2 ميجابايت).');
    }

    try {
      final formData = FormData.fromMap({
        'is_primary': '1',
        'photo': MultipartFile.fromBytes(
          imageBytes,
          filename: filename,
          contentType: DioMediaType.parse(mimeType),
        ),
      });

      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.profilePhoto,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress((sent / total).clamp(0.0, 1.0));
          }
        },
      );

      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
      final photoMap = (data['photo'] as Map<String, dynamic>?) ?? {};
      return ProfilePhotoMetadata.fromJson(photoMap);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(
        e,
        fallback: 'فشل رفع الصورة الشخصية. يرجى التحقق من جودة الاتصال والمحاولة مجدداً.',
      ));
    }
  }

  /// GET /api/v1/profile/photos/{photoId}/stream
  /// Fetches private profile photo bytes over the authenticated Sanctum connection.
  Future<Uint8List> fetchProtectedPhotoBytes(int photoId) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        ApiEndpoints.photoStream(photoId),
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const <int>[]);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(
        e,
        fallback: 'غير مصرح بعرض هذه الصورة الشخصية أو تعذر تحميلها.',
      ));
    }
  }

  /// GET /api/v1/profile/privacy
  Future<({bool isVisible, String photoPrivacy})> fetchPrivacySettings() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        ApiEndpoints.profilePrivacy,
      );
      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
      return (
        isVisible: (data['is_visible'] as bool?) ?? true,
        photoPrivacy: (data['photo_privacy'] as String?) ?? 'public',
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(
        e,
        fallback: 'تعذر جلب إعدادات الخصوصية الحالية.',
      ));
    }
  }

  /// PATCH /api/v1/profile/privacy
  Future<({bool isVisible, String photoPrivacy})> updatePrivacySettings({
    required bool isVisible,
    required String photoPrivacy,
  }) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        ApiEndpoints.profilePrivacy,
        data: {
          'is_visible': isVisible,
          'photo_privacy': photoPrivacy,
        },
      );
      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
      return (
        isVisible: (data['is_visible'] as bool?) ?? isVisible,
        photoPrivacy: (data['photo_privacy'] as String?) ?? photoPrivacy,
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(
        e,
        fallback: 'تعذر تحديث إعدادات الخصوصية.',
      ));
    }
  }

  String _extractErrorMessage(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final firstFieldErrors = errors.values.first;
        if (firstFieldErrors is List && firstFieldErrors.isNotEmpty) {
          return firstFieldErrors.first.toString();
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
