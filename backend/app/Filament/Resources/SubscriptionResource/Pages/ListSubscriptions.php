<?php

namespace App\Filament\Resources\SubscriptionResource\Pages;

use App\Filament\Resources\SubscriptionResource;
use App\Models\Administrator;
use App\Models\User;
use App\Services\Admin\AdminModerationService;
use Filament\Actions\Action;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ListRecords;
use Illuminate\Support\Facades\Auth;

class ListSubscriptions extends ListRecords
{
    protected static string $resource = SubscriptionResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Action::make('create_manual_subscription')
                ->label('تفعيل اشتراك يدوي لعضو')
                ->icon('heroicon-o-sparkles')
                ->color('warning')
                ->modalHeading('تفعيل اشتراك يدوي لعضو من لوحة التحكم')
                ->modalDescription('اختر العضو والمدة المطلوبة لتفعيل أو تمديد اشتراكه في نَصِيبُكَ فوراً.')
                ->form([
                    Select::make('user_id')
                        ->label('العضو')
                        ->searchable()
                        ->preload()
                        ->options(fn (): array => User::query()
                            ->where('role', 'member')
                            ->with('profile')
                            ->latest('id')
                            ->limit(200)
                            ->get()
                            ->mapWithKeys(function (User $u): array {
                                $name = $u->profile?->full_name ?: 'عضو بدون اسم';
                                return [$u->id => "{$name} ({$u->email}) - #{$u->id}"];
                            })
                            ->all())
                        ->required(),
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
                        ->placeholder('مثال: تفعيل اشتراك يدوي بعد التحويل البنكي / فودافون كاش / منحة إدارية')
                        ->maxLength(500),
                ])
                ->action(function (array $data, AdminModerationService $service) {
                    $member = User::find($data['user_id'] ?? null);
                    if (!$member) {
                        Notification::make()
                            ->title('لم يتم العثور على العضو المحدد')
                            ->danger()
                            ->send();
                        return;
                    }

                    /** @var Administrator $actor */
                    $actor = Auth::guard('admin')->user();
                    $sub = $service->activateManualSubscription(
                        actor: $actor,
                        member: $member,
                        durationDays: (int) ($data['duration_days'] ?? 30),
                        notes: $data['notes'] ?? null,
                    );

                    Notification::make()
                        ->title('تم تفعيل الاشتراك اليدوي للعضو بنجاح حتى ' . $sub->ends_at?->format('Y-m-d'))
                        ->success()
                        ->send();
                }),
        ];
    }
}
