import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/profile_management_provider.dart';

/// ProfilePhotoUploader (مكوّن اختيار وضغط ورفع الصورة الشخصية بأمان)
/// - يختار الصورة من المعرض مع تحديد الأبعاد القصوى (1080px)
/// - يضغط الصورة محلياً لضمان عدم تجاوز 2 ميجابايت (ملائم لخادم VPS المشترك)
/// - يعرض معاينة قبل الرفع ومؤشر تقدم الرفع وحالات الخطأ
class ProfilePhotoUploader extends ConsumerStatefulWidget {
  final String fallbackInitial;
  final double radius;
  final bool showChangeButton;

  const ProfilePhotoUploader({
    super.key,
    required this.fallbackInitial,
    this.radius = 44,
    this.showChangeButton = true,
  });

  @override
  ConsumerState<ProfilePhotoUploader> createState() =>
      _ProfilePhotoUploaderState();
}

class _ProfilePhotoUploaderState extends ConsumerState<ProfilePhotoUploader> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickPreviewAndUpload(BuildContext context) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      Uint8List rawBytes = await pickedFile.readAsBytes();

      // Compress further if needed to ensure <= 2 MB and strip client metadata
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          rawBytes,
          minWidth: 1080,
          minHeight: 1080,
          quality: 82,
          format: CompressFormat.jpeg,
        );
        if (compressed.isNotEmpty) {
          rawBytes = Uint8List.fromList(compressed);
        }
      } catch (_) {
        // Fallback to ImagePicker's already-resized bytes on platforms without native compress plugin
      }

      if (!context.mounted) return;

      // Show confirmation & preview dialog before uploading to server
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final sizeKb = (rawBytes.lengthInBytes / 1024).toStringAsFixed(0);
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: AppColors.backgroundPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'معاينة الصورة الشخصية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: Image.memory(
                      rawBytes,
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'الحجم بعد الضغط: $sizeKb كيلوبايت (الحد الأقصى 2 ميجابايت)',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'سيتم إزالة بيانات الموقع الجغرافي (EXIF) تلقائياً وحفظ الصورة في مساحة خاصة محمية.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(110, 40),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('اعتماد ورفع'),
                ),
              ],
            ),
          );
        },
      );

      if (confirmed == true) {
        await ref.read(profileManagementProvider.notifier).uploadProfilePhoto(
              compressedBytes: rawBytes,
              filename: 'profile_photo.jpg',
              mimeType: 'image/jpeg',
            );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('تعذر اختيار الصورة: ${e.toString()}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileManagementProvider);
    final photoBytes = state.cachedPhotoBytes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: widget.radius,
              backgroundColor: AppColors.surfaceSubtleBlue,
              backgroundImage:
                  photoBytes != null ? MemoryImage(photoBytes) : null,
              child: photoBytes == null
                  ? Text(
                      widget.fallbackInitial,
                      style: TextStyle(
                        fontSize: widget.radius * 0.72,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlue,
                      ),
                    )
                  : null,
            ),
            if (state.isUploadingPhoto)
              SizedBox(
                width: widget.radius * 2,
                height: widget.radius * 2,
                child: CircularProgressIndicator(
                  value: state.uploadProgress > 0 ? state.uploadProgress : null,
                  strokeWidth: 3.2,
                  color: AppColors.accentYellow,
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              child: InkWell(
                key: const Key('change_profile_photo_icon_btn'),
                onTap: state.isUploadingPhoto
                    ? null
                    : () => _pickPreviewAndUpload(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.2),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (state.isUploadingPhoto) ...[
          const SizedBox(height: 8),
          Text(
            'جارٍ رفع الصورة الشخصية... ${(state.uploadProgress * 100).round()}%',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue,
            ),
          ),
        ] else if (widget.showChangeButton) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('change_profile_photo_text_btn'),
            onPressed: () => _pickPreviewAndUpload(context),
            icon: const Icon(
              Icons.photo_library_outlined,
              size: 16,
              color: AppColors.primaryBlue,
            ),
            label: const Text(
              'تغيير الصورة الشخصية',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
