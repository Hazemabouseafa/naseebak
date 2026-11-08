import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../providers/discovery_provider.dart';

/// AuthorizedPhotoAvatar / NaseebakAvatar (مكوّن عرض الصورة الشخصية المحمية بتصميم Astra)
/// يمرر جلسة المصادقة (Sanctum Bearer Token) عبر DiscoveryRepository لتحميل الصورة
/// إذا كان مصرّحاً بها، ويعرض رمزاً محايداً فاخراً بإطار ذهبي ناعم إذا كانت محجوبة أو غير متوفرة.
class AuthorizedPhotoAvatar extends ConsumerStatefulWidget {
  static final Map<int, Uint8List> _photoMemoryCache = <int, Uint8List>{};

  static void cachePhoto(int photoId, Uint8List bytes) {
    if (bytes.isNotEmpty) {
      _photoMemoryCache[photoId] = bytes;
    }
  }

  static Uint8List? getCachedPhoto(int? photoId) {
    if (photoId == null) return null;
    return _photoMemoryCache[photoId];
  }

  final int? photoId;
  final bool photoAuthorized;
  final String fallbackName;
  final double radius;
  final bool showGoldBorder;
  final bool isFullBleedCover;
  final String gender;

  const AuthorizedPhotoAvatar({
    super.key,
    required this.photoId,
    required this.photoAuthorized,
    required this.fallbackName,
    this.radius = 29,
    this.showGoldBorder = true,
    this.isFullBleedCover = false,
    this.gender = 'male',
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
    if (widget.photoAuthorized &&
        widget.photoId != null &&
        AuthorizedPhotoAvatar._photoMemoryCache.containsKey(widget.photoId!)) {
      _loadedBytes = AuthorizedPhotoAvatar._photoMemoryCache[widget.photoId!];
      _attemptedLoad = true;
    } else {
      _loadPhotoIfPermitted();
    }
  }

  @override
  void didUpdateWidget(covariant AuthorizedPhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId ||
        oldWidget.photoAuthorized != widget.photoAuthorized) {
      if (widget.photoAuthorized &&
          widget.photoId != null &&
          AuthorizedPhotoAvatar._photoMemoryCache.containsKey(widget.photoId!)) {
        _loadedBytes = AuthorizedPhotoAvatar._photoMemoryCache[widget.photoId!];
        _attemptedLoad = true;
      } else {
        _loadedBytes = null;
        _attemptedLoad = false;
        _loadPhotoIfPermitted();
      }
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
      if (bytes.isNotEmpty) {
        AuthorizedPhotoAvatar._photoMemoryCache[widget.photoId!] = bytes;
        if (mounted) {
          setState(() => _loadedBytes = bytes);
        }
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

    if (widget.isFullBleedCover) {
      if (_loadedBytes != null) {
        return SizedBox.expand(
          child: Image.memory(
            _loadedBytes!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          ),
        );
      }

      final isFemale = widget.gender.toLowerCase() == 'female';
      return SizedBox.expand(
        child: CustomPaint(
          painter: _FullCardPortraitPainter(isFemale: isFemale),
          child: Align(
            alignment: const Alignment(0, -0.25),
            child: Text(
              initial,
              style: TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ),
        ),
      );
    }

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

class _FullCardPortraitPainter extends CustomPainter {
  final bool isFemale;

  const _FullCardPortraitPainter({required this.isFemale});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final haloPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.22),
        radius: 0.65,
        colors: [
          AppColors.goldAccent.withOpacity(0.22),
          Colors.white.withOpacity(0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), haloPaint);

    // Full-card large head & shoulders portrait silhouette filling the card
    final silhouettePaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.fill;

    final headRadius = w * 0.19;
    final headCenter = Offset(w * 0.5, h * 0.34);
    canvas.drawCircle(headCenter, headRadius, silhouettePaint);

    final shouldersPath = Path()
      ..moveTo(w * 0.10, h * 0.92)
      ..quadraticBezierTo(w * 0.14, h * 0.56, w * 0.50, h * 0.56)
      ..quadraticBezierTo(w * 0.86, h * 0.56, w * 0.90, h * 0.92)
      ..lineTo(w * 0.90, h)
      ..lineTo(w * 0.10, h)
      ..close();
    canvas.drawPath(shouldersPath, silhouettePaint);
  }

  @override
  bool shouldRepaint(covariant _FullCardPortraitPainter oldDelegate) =>
      oldDelegate.isFemale != isFemale;
}

typedef NaseebakAvatar = AuthorizedPhotoAvatar;
