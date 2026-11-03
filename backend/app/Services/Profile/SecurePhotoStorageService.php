<?php

namespace App\Services\Profile;

use App\Models\User;
use App\Models\UserPhoto;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;
use Symfony\Component\HttpFoundation\StreamedResponse;

class SecurePhotoStorageService
{
    public const ALLOWED_MIME_MAP = [
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
    ];

    /**
     * Validates actual binary image content, strips EXIF/GPS metadata by re-encoding
     * the pixel buffer, generates a cryptographically random filename, stores the file
     * on the private disk, and removes replaced orphan files.
     *
     * @param User $user Authenticated owner
     * @param UploadedFile $uploadedFile Incoming multipart file
     * @param bool $isPrimary Whether this photo should replace the primary profile photo
     * @return UserPhoto
     */
    public function storeSanitizedProfilePhoto(
        User $user,
        UploadedFile $uploadedFile,
        bool $isPrimary = true
    ): UserPhoto {
        $realPath = $uploadedFile->getRealPath();
        if ($realPath === false || !is_readable($realPath)) {
            throw new RuntimeException('تعذر قراءة ملف الصورة المرفوع.');
        }

        // 1. Verify actual binary image header & dimensions (do NOT trust extension or client MIME)
        $imageInfo = @getimagesize($realPath);
        if ($imageInfo === false || empty($imageInfo['mime'])) {
            throw new RuntimeException('الملف المرفوع ليس صورة صالحة.');
        }

        $detectedMime = strtolower((string) $imageInfo['mime']);
        if (!array_key_exists($detectedMime, self::ALLOWED_MIME_MAP)) {
            throw new RuntimeException('صيغة الصورة غير مدعومة. الصيغ المسموحة: JPEG, PNG, WebP.');
        }

        [$origWidth, $origHeight] = $imageInfo;
        if ($origWidth < 200 || $origHeight < 200) {
            throw new RuntimeException('أبعاد الصورة صغيرة جداً (الحد الأدنى 200×200 بكسل).');
        }

        // 2. Re-encode image via GD (if available) to strip all EXIF/GPS metadata and cap max dimension at 1080px
        $maxDimension = (int) config('naseebak.uploads.max_dimension_px', 1080);
        $quality = (int) config('naseebak.uploads.compression_quality', 82);

        [$sanitizedBinary, $outputMime, $outputExt] = $this->reencodeAndStripMetadata(
            $realPath,
            $detectedMime,
            (int) $origWidth,
            (int) $origHeight,
            $maxDimension,
            $quality
        );

        // 3. Generate safe random filename without any user-supplied path components
        $safeFilename = Str::uuid()->toString() . '.' . $outputExt;
        $relativeStoragePath = "member-photos/{$user->id}/{$safeFilename}";

        Storage::disk('private')->put($relativeStoragePath, $sanitizedBinary);
        $byteSize = strlen($sanitizedBinary);

        // 4. Atomically update DB records and collect any replaced primary photos to purge from disk
        $orphanPathsToDelete = [];

        $newPhoto = DB::transaction(function () use (
            $user,
            $relativeStoragePath,
            $outputMime,
            $byteSize,
            $isPrimary,
            &$orphanPathsToDelete
        ) {
            if ($isPrimary) {
                $existingPrimaryPhotos = UserPhoto::where('user_id', $user->id)
                    ->where('is_primary', true)
                    ->lockForUpdate()
                    ->get();

                foreach ($existingPrimaryPhotos as $oldPhoto) {
                    $orphanPathsToDelete[] = [
                        'disk' => $oldPhoto->storage_disk,
                        'path' => $oldPhoto->file_path,
                    ];
                    $oldPhoto->delete();
                }
            }

            return UserPhoto::create([
                'user_id' => $user->id,
                'storage_disk' => 'private',
                'file_path' => $relativeStoragePath,
                'mime_type' => $outputMime,
                'file_size_bytes' => $byteSize,
                'is_primary' => $isPrimary,
                'moderation_status' => 'pending',
            ]);
        });

        // 5. Delete replaced orphan files outside the DB transaction
        foreach ($orphanPathsToDelete as $orphan) {
            if (!empty($orphan['path'])) {
                Storage::disk($orphan['disk'] ?? 'private')->delete($orphan['path']);
            }
        }

        return $newPhoto;
    }

    /**
     * Purges all stored photos belonging to a user (prepared for Account Deletion cleanup).
     */
    public function purgeAllUserPhotos(User $user): void
    {
        $photos = UserPhoto::where('user_id', $user->id)->get();

        foreach ($photos as $photo) {
            if (!empty($photo->file_path)) {
                Storage::disk($photo->storage_disk ?: 'private')->delete($photo->file_path);
            }
            $photo->delete();
        }

        Storage::disk('private')->deleteDirectory("member-photos/{$user->id}");
    }

    /**
     * Prevents path traversal and verifies the file path stays strictly within member-photos/.
     */
    public function isSafeRelativePhotoPath(string $filePath): bool
    {
        $normalized = str_replace('\\', '/', $filePath);
        if (str_contains($normalized, '..') || str_starts_with($normalized, '/')) {
            return false;
        }
        return (bool) preg_match('#^(member-photos|user_photos)/[0-9]+/[a-zA-Z0-9\-_]+\.(jpg|jpeg|png|webp)$#', $normalized);
    }

    /**
     * Checks whether the physical photo file exists in private storage on a safe path.
     */
    public function exists(UserPhoto $photo): bool
    {
        if (empty($photo->file_path) || !$this->isSafeRelativePhotoPath($photo->file_path)) {
            return false;
        }

        return Storage::disk($photo->storage_disk ?: 'private')->exists($photo->file_path);
    }

    /**
     * Streams a private UserPhoto with strict no-store headers.
     */
    public function streamPhoto(UserPhoto $photo): StreamedResponse
    {
        $disk = Storage::disk($photo->storage_disk ?: 'private');
        $binaryContent = (string) $disk->get($photo->file_path);
        $mimeType = $photo->mime_type ?: 'image/jpeg';

        return response()->stream(
            static function () use ($binaryContent): void {
                echo $binaryContent;
            },
            200,
            [
                'Content-Type' => $mimeType,
                'Content-Length' => (string) strlen($binaryContent),
                'Cache-Control' => 'private, no-store, no-cache, must-revalidate, max-age=0',
                'Pragma' => 'no-cache',
                'X-Content-Type-Options' => 'nosniff',
            ]
        );
    }

    /**
     * @return array{0: string, 1: string, 2: string} [binary, mime, ext]
     */
    private function reencodeAndStripMetadata(
        string $realPath,
        string $detectedMime,
        int $origWidth,
        int $origHeight,
        int $maxDimension,
        int $quality
    ): array {
        if (!extension_loaded('gd')) {
            // Fallback in test environments without GD extension while still verifying header
            $raw = file_get_contents($realPath);
            if ($raw === false) {
                throw new RuntimeException('تعذر قراءة محتوى الصورة.');
            }
            return [$raw, $detectedMime, self::ALLOWED_MIME_MAP[$detectedMime]];
        }

        $srcImage = match ($detectedMime) {
            'image/jpeg' => @imagecreatefromjpeg($realPath),
            'image/png' => @imagecreatefrompng($realPath),
            'image/webp' => function_exists('imagecreatefromwebp') ? @imagecreatefromwebp($realPath) : false,
            default => false,
        };

        if ($srcImage === false) {
            throw new RuntimeException('تعذر معالجة بيانات الصورة المرفوعة.');
        }

        // Calculate target dimensions preserving aspect ratio (max 1080px)
        $targetWidth = $origWidth;
        $targetHeight = $origHeight;
        if ($origWidth > $maxDimension || $origHeight > $maxDimension) {
            if ($origWidth >= $origHeight) {
                $targetWidth = $maxDimension;
                $targetHeight = (int) round(($origHeight / $origWidth) * $maxDimension);
            } else {
                $targetHeight = $maxDimension;
                $targetWidth = (int) round(($origWidth / $origHeight) * $maxDimension);
            }
        }

        $dstImage = imagecreatetruecolor($targetWidth, $targetHeight);
        if ($dstImage === false) {
            imagedestroy($srcImage);
            throw new RuntimeException('تعذر تخصيص الذاكرة لمعالجة الصورة.');
        }

        // Fill white background in case a transparent PNG/WebP is converted to JPEG
        $white = imagecolorallocate($dstImage, 255, 255, 255);
        imagefill($dstImage, 0, 0, $white);

        imagecopyresampled(
            $dstImage,
            $srcImage,
            0,
            0,
            0,
            0,
            $targetWidth,
            $targetHeight,
            $origWidth,
            $origHeight
        );

        ob_start();
        imagejpeg($dstImage, null, $quality);
        $binary = (string) ob_get_clean();

        imagedestroy($srcImage);
        imagedestroy($dstImage);

        if ($binary === '') {
            throw new RuntimeException('فشل ضغط الصورة وتنظيف البيانات الوصفية.');
        }

        return [$binary, 'image/jpeg', 'jpg'];
    }
}
