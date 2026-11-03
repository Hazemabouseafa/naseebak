<?php

namespace Tests\Feature;

use App\Models\Administrator;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class Phase9ProductionDeploymentTest extends TestCase
{
    use RefreshDatabase;

    public function test_laravel_framework_is_upgraded_to_security_supported_v12_and_filament_is_compatible(): void
    {
        $version = app()->version();
        $this->assertTrue(
            version_compare($version, '12.0.0', '>='),
            "Expected Laravel version >= 12.0.0, found {$version}"
        );

        $this->assertTrue(class_exists(\Filament\Panel::class));
        $this->assertTrue(class_exists(\Laravel\Reverb\ReverbServiceProvider::class));
        $this->assertTrue(class_exists(\Laravel\Sanctum\SanctumServiceProvider::class));
    }

    public function test_public_health_endpoint_returns_safe_readiness_without_sensitive_diagnostics(): void
    {
        Storage::fake('private');

        $response = $this->getJson('/api/v1/health');

        $response->assertStatus(200)
            ->assertJson([
                'app' => 'نصيبك — Naseebak API',
                'version' => '1.0.0',
                'status' => 'ok',
                'checks' => [
                    'database' => 'ok',
                    'private_storage' => 'ok',
                ],
            ]);

        $rawContent = (string) $response->getContent();
        $this->assertStringNotContainsString((string) config('app.key'), $rawContent);
        $this->assertStringNotContainsString('DB_PASSWORD', $rawContent);
        $this->assertStringNotContainsString('storage/app/private', $rawContent);
        $this->assertStringContainsString('no-store', (string) $response->headers->get('Cache-Control'));
    }

    public function test_admin_diagnostics_endpoint_enforces_admin_authentication_and_returns_safe_metrics(): void
    {
        Storage::fake('private');

        // 1. Unauthenticated request blocked -> 401
        $this->getJson('/admin/operations/health')
            ->assertStatus(401)
            ->assertJsonPath('code', 'ADMIN_UNAUTHENTICATED');

        // 2. Regular member Sanctum token blocked -> 401
        $member = User::create([
            'google_sub' => 'google-phase9-member-1',
            'email' => 'phase9-member@naseebak.local',
            'status' => 'active',
            'profile_completed' => true,
        ]);
        $memberToken = $member->createToken('android-client')->plainTextToken;

        $this->withToken($memberToken)
            ->getJson('/admin/operations/health')
            ->assertStatus(401);

        // 3. Authenticated active administrator succeeds -> 200
        $admin = Administrator::create([
            'name' => 'مدير النظام',
            'email' => 'ops-admin@naseebak.local',
            'password' => Hash::make('StrongAdminPass!2026#'),
            'role' => Administrator::ROLE_SUPER_ADMIN,
            'is_active' => true,
            'mfa_enabled' => false,
        ]);

        $this->actingAs($admin, 'admin')
            ->getJson('/admin/operations/health')
            ->assertStatus(200)
            ->assertJsonPath('status', 'ok')
            ->assertJsonPath('data.database_connected', true)
            ->assertJsonPath('data.private_storage_writable', true)
            ->assertJsonStructure([
                'status',
                'data' => [
                    'framework_version',
                    'php_version',
                    'environment',
                    'debug_mode',
                    'database_connected',
                    'private_storage_writable',
                    'queue' => [
                        'driver',
                        'pending_jobs_count',
                        'failed_jobs_count',
                    ],
                    'reverb' => [
                        'configured',
                    ],
                    'timestamp',
                ],
            ]);
    }

    public function test_private_filesystem_disk_and_scheduled_maintenance_commands_are_configured(): void
    {
        $privateDiskConfig = config('filesystems.disks.private');
        $this->assertIsArray($privateDiskConfig);
        $this->assertSame('local', $privateDiskConfig['driver']);
        $this->assertFalse($privateDiskConfig['serve'] ?? true);
        $this->assertSame('private', $privateDiskConfig['visibility'] ?? 'private');
        $this->assertEmpty(config('filesystems.links'));

        $exitCode = Artisan::call('naseebak:expire-subscriptions');
        $this->assertSame(0, $exitCode);

        $scheduleExitCode = Artisan::call('schedule:list');
        $this->assertSame(0, $scheduleExitCode);
        $scheduleOutput = Artisan::output();
        $this->assertStringContainsString('naseebak:expire-subscriptions', $scheduleOutput);
        $this->assertStringContainsString('sanctum:prune-expired', $scheduleOutput);
    }
}
