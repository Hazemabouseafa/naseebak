import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/discovery_provider.dart';

/// AuthorizedPhotoAvatar (مكوّن عرض الصورة الشخصية المحمية)
/// يمرر جلسة المصادقة (Sanctum Bearer Token) عبر DiscoveryRepository لتحميل الصورة
/// إذا كان مصرّحاً بها، ويعرض رمزاً محايداً أنيقاً (بدون أي صورة مكسورة) إذا كانت محجوبة أو غير متوفرة.
class AuthorizedPhotoAvatar extends ConsumerStatefulWidget {
  final int? photoId;
  final bool photoAuthorized;
  final String fallbackName;
  final double radius;

  const AuthorizedPhotoAvatar({
    super.key,
    required this.photoId,
    required this.photoAuthorized,
    required this.fallbackName,
    this.radius = 29,
  });

  @override
  ConsumerState<AuthorizedPhotoAvatar> createState() =>
      _AuthorizedPhotoAvatarState();
}

class _AuthorizedPhotoAvatarState extends ConsumerState<AuthorizedPhotoAvatar> {
  Uint8List? _loadedBytes;
  bool _attemptedLoad = false;

  @override
  void initState() {
    super.initState();
    _loadPhotoIfPermitted();
  }

  @override
  void didUpdateWidget(covariant AuthorizedPhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId ||
        oldWidget.photoAuthorized != widget.photoAuthorized) {
      _loadedBytes = null;
      _attemptedLoad = false;
      _loadPhotoIfPermitted();
    }
  }

  Future<void> _loadPhotoIfPermitted() async {
    if (!widget.photoAuthorized ||
        widget.photoId == null ||
        _attemptedLoad) {
      return;
    }

    _attemptedLoad = true;
    try {
      final bytes = await ref
          .read(discoveryRepositoryProvider)
          .fetchAuthorizedPhotoBytes(widget.photoId!);
      if (mounted && bytes.isNotEmpty) {
        setState(() => _loadedBytes = bytes);
      }
    } catch (_) {
      // Keep neutral placeholder on network or permission error (never show broken image)
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.fallbackName.trim().isNotEmpty
        ? widget.fallbackName.trim().substring(0, 1)
        : 'ن';

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: AppColors.surfaceSubtleBlue,
      backgroundImage:
          _loadedBytes != null ? MemoryImage(_loadedBytes!) : null,
      child: _loadedBytes == null
          ? Text(
              initial,
              style: TextStyle(
                fontSize: widget.radius * 0.68,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
              ),
            )
          : null,
    );
  }
}
