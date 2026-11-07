<?php

namespace App\Filament\Resources\MemberResource\Pages;

use App\Filament\Resources\MemberResource;
use App\Models\Administrator;
use App\Models\User;
use App\Models\UserProfile;
use App\Services\Admin\AdminModerationService;
use Filament\Actions\Action;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ViewRecord;
use Illuminate\Support\Facades\Auth;

class ViewMember extends ViewRecord
{
    protected static string $resource = MemberResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Action::make('approve_profile_header')
                ->label('اعتماد الملف للظهور في البحث')
                ->icon('heroicon-o-check-badge')
                ->color('success')
                ->requiresConfirmation()
                ->visible(fn (): bool => $this->record instanceof User
                    && $this->record->profile !== null
                    && $this->record->profile->moderation_status !== UserProfile::STATUS_APPROVED)
                ->action(function (AdminModerationService $service) {
                    /** @var User $record */
                    $record = $this->record;
                    if (!$record->profile) {
                        return;
                    }
                    /** @var Administrator $actor */
                    $actor = Auth::guard('admin')->user();
                    $service->moderateProfile($actor, $record->profile, UserProfile::STATUS_APPROVED);

                    Notification::make()
                        ->title('تم اعتماد الملف الشخصي بنجاح')
                        ->success()
                        ->send();
                }),

            Action::make('activate_manual_subscription_header')
                ->label(fn (): string => ($this->record instanceof User && $this->record->hasActiveSubscription())
                    ? 'تمديد الاشتراك يدوياً'
                    : 'تفعيل اشتراك يدوي')
                ->icon('heroicon-o-sparkles')
                ->color('warning')
                ->form([
                    Select::make('duration_days')
                        ->label('مدة الاشتراك')
                        ->options([
                            30 => 'شهر واحد (30 يوم)',
                            90 => '3 أشهر (90 يوم)',
                            180 => '6 أشهر (180 يوم)',
                            365 => 'سنة كاملة (365 يوم)',
                        ])
                        ->default(30)
                        ->required(),
                    Textarea::make('notes')
                        ->label('ملاحظات التفعيل الإداري (اختياري)')
                        ->maxLength(500),
                ])
                ->action(function (array $data, AdminModerationService $service) {
                    /** @var User $record */
                    $record = $this->record;
                    /** @var Administrator $actor */
                    $actor = Auth::guard('admin')->user();
                    $sub = $service->activateManualSubscription(
                        actor: $actor,
                        member: $record,
                        durationDays: (int) ($data['duration_days'] ?? 30),
                        notes: $data['notes'] ?? null,
                    );

                    Notification::make()
                        ->title('تم تفعيل الاشتراك اليدوي حتى ' . $sub->ends_at?->format('Y-m-d'))
                        ->success()
                        ->send();
                }),
        ];
    }
}
