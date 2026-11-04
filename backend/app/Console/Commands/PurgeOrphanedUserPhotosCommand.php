<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Models\UserPhoto;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

class PurgeOrphanedUserPhotosCommand extends Command
{
    protected $signature = 'naseebak:purge-orphaned-photos {--dry-run : Report orphaned photos without deleting them}';

    protected $description = 'Scans private storage for photo files belonging to deleted users or missing database records';

    public function handle(): int
    {
        $isDryRun = (bool) $this->option('dry-run');
        $disk = Storage::disk('private');

        $this->info($isDryRun ? 'Running orphaned photos scan (dry-run)...' : 'Purging orphaned photos from private storage...');

        $directories = $disk->directories('member-photos');
        $purgedDirs = 0;
        $purgedFiles = 0;

        foreach ($directories as $dir) {
            // Directory format: member-photos/{user_id}
            $parts = explode('/', $dir);
            $userIdStr = end($parts);

            if (!is_numeric($userIdStr)) {
                continue;
            }

            $userId = (int) $userIdStr;
            $user = User::withTrashed()->find($userId);

            // If user is deleted or does not exist at all, directory should be purged
            if (!$user || $user->trashed() || $user->account_status === 'deleted') {
                $files = $disk->allFiles($dir);
                $fileCount = count($files);

                if ($isDryRun) {
                    $this->line("[DRY-RUN] Would delete directory: {$dir} ({$fileCount} files)");
                } else {
                    $disk->deleteDirectory($dir);
                    $this->line("Purged directory: {$dir} ({$fileCount} files)");
                    $purgedDirs++;
                    $purgedFiles += $fileCount;
                }
            } else {
                // User exists and is active; verify individual files exist in user_photos table
                $activePhotos = UserPhoto::where('user_id', $userId)->pluck('file_path')->all();
                $filesOnDisk = $disk->files($dir);

                foreach ($filesOnDisk as $filePath) {
                    if (!in_array($filePath, $activePhotos, true)) {
                        if ($isDryRun) {
                            $this->line("[DRY-RUN] Would delete unreferenced file: {$filePath}");
                        } else {
                            $disk->delete($filePath);
                            $this->line("Deleted unreferenced file: {$filePath}");
                            $purgedFiles++;
                        }
                    }
                }
            }
        }

        $this->info("Completed. Purged {$purgedDirs} directories, {$purgedFiles} files.");
        return self::SUCCESS;
    }
}
