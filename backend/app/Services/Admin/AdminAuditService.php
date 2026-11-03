<?php

namespace App\Services\Admin;

use App\Models\AdminAuditLog;
use App\Models\Administrator;
use Illuminate\Database\Eloquent\Model;

class AdminAuditService
{
    /**
     * Records an append-only administrative action in PostgreSQL.
     */
    public function record(
        Administrator $actor,
        string $action,
        ?Model $target = null,
        ?array $previousValues = null,
        ?array $newValues = null,
        ?string $reason = null,
        ?string $ipAddress = null
    ): AdminAuditLog {
        return AdminAuditLog::create([
            'administrator_id' => $actor->id,
            'action' => $action,
            'target_type' => $target ? get_class($target) : null,
            'target_id' => $target?->getKey(),
            'previous_values' => $previousValues,
            'new_values' => $newValues,
            'ip_address' => $ipAddress ?? request()?->ip(),
            'justification' => $reason,
            'created_at' => now(),
        ]);
    }
}
