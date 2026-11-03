import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/discovery_provider.dart';

/// AuthorizedPhotoAvatar / NaseebakAvatar (مكوّن عرض الصورة الشخصية المحمية بتصميم Astra)
/// يمرر جلسة المصادقة (Sanctum Bearer Token) عبر DiscoveryRepository لتحميل الصورة
/// إذا كان مصرّحاً بها، ويعرض رمزاً محايداً فاخراً بإطار ذهبي ناعم إذا كانت محجوبة أو غير متوفرة.
class AuthorizedPhotoAvatar extends ConsumerStatefulWidget {
  final int? photoId;
  final bool photoAuthorized;
  final String fallbackName;
  final double radius;
  final bool showGoldBorder;

  const AuthorizedPhotoAvatar({
    super.key,
    required this.photoId,
    required this.photoAuthorized,
    required this.fallbackName,
    this.radius = 29,
    this.showGoldBorder = true,
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
    if (!widget.photoAuthorized || widget.photoId == null || _attemptedLoad) {
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

    final avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: AppColors.creamHighlight,
      backgroundImage:
          _loadedBytes != null ? MemoryImage(_loadedBytes!) : null,
      child: _loadedBytes == null
          ? Text(
              initial,
              style: TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: widget.radius * 0.68,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryNavy,
              ),
            )
          : null,
    );

    if (!widget.showGoldBorder) {
      return avatar;
    }

    return Container(
      padding: const EdgeInsets.all(2.2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.photoAuthorized
              ? AppColors.goldAccent
              : AppColors.subtleBorder,
          width: 1.6,
        ),
      ),
      child: avatar,
    );
  }
}

typedef NaseebakAvatar = AuthorizedPhotoAvatar;
