<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Throwable;

class HealthCheckController extends Controller
{
    /**
     * GET /api/v1/health
     *
     * Safe public health & readiness endpoint for Coolify reverse proxy and uptime monitors.
     * Verifies PostgreSQL connectivity and private photo storage availability without
     * exposing internal paths, stack traces, environment variables, or credentials.
     */
    public function publicHealth(): JsonResponse
    {
        $dbHealthy = false;
        $storageHealthy = false;

        try {
            DB::connection()->getPdo();
            $dbHealthy = true;
        } catch (Throwable) {
            $dbHealthy = false;
        }

        try {
            $disk = Storage::disk('private');
            $storageHealthy = is_dir($disk->path('')) && is_writable($disk->path(''));
        } catch (Throwable) {
            $storageHealthy = false;
        }

        $overallHealthy = $dbHealthy && $storageHealthy;

        return response()->json([
            'app' => 'نصيبك — Naseebak API',
            'version' => '1.0.0',
            'status' => $overallHealthy ? 'ok' : 'degraded',
            'checks' => [
                'database' => $dbHealthy ? 'ok' : 'error',
                'private_storage' => $storageHealthy ? 'ok' : 'error',
            ],
            'timestamp' => now()->toIso8601String(),
        ], $overallHealthy ? 200 : 503, [
            'Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0',
        ]);
    }

    /**
     * GET /admin/operations/health
     *
     * Authenticated administrator-only operational health summary (queue depth, failed jobs,
     * Reverb configuration state, private storage status). Never exposes secret values.
     */
    public function adminDiagnostics(): JsonResponse
    {
        $dbHealthy = false;
        $pendingJobs = 0;
        $failedJobs = 0;

        try {
            DB::connection()->getPdo();
            $dbHealthy = true;

            if (Schema::hasTable('jobs')) {
                $pendingJobs = (int) DB::table('jobs')->count();
            }
            if (Schema::hasTable('failed_jobs')) {
                $failedJobs = (int) DB::table('failed_jobs')->count();
            }
        } catch (Throwable) {
            $dbHealthy = false;
        }

        $privateDiskPath = Storage::disk('private')->path('');
        $storageWritable = is_dir($privateDiskPath) && is_writable($privateDiskPath);

        $freeBytes = @disk_free_space($privateDiskPath);
        $totalBytes = @disk_total_space($privateDiskPath);
        $freePercent = ($freeBytes !== false && $totalBytes !== false && $totalBytes > 0)
            ? round(($freeBytes / $totalBytes) * 100, 2)
            : null;

        $reverbConfigured = !empty(config('broadcasting.connections.reverb.key'))
            && !empty(config('broadcasting.connections.reverb.secret'))
            && !empty(config('broadcasting.connections.reverb.app_id'));

        return response()->json([
            'status' => ($dbHealthy && $storageWritable) ? 'ok' : 'degraded',
            'data' => [
                'framework_version' => app()->version(),
                'php_version' => PHP_VERSION,
                'environment' => app()->environment(),
                'debug_mode' => (bool) config('app.debug'),
                'database_connected' => $dbHealthy,
                'private_storage_writable' => $storageWritable,
                'disk_free_percent' => $freePercent,
                'queue' => [
                    'driver' => config('queue.default'),
                    'pending_jobs_count' => $pendingJobs,
                    'failed_jobs_count' => $failedJobs,
                ],
                'reverb' => [
                    'configured' => $reverbConfigured,
                ],
                'timestamp' => now()->toIso8601String(),
            ],
        ]);
    }
}
