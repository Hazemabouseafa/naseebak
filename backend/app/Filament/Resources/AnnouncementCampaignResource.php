<?php

namespace App\Filament\Resources;

use App\Filament\Resources\AnnouncementCampaignResource\Pages;
use App\Models\Administrator;
use App\Models\AnnouncementCampaign;
use App\Providers\Filament\AdminPanelProvider;
use App\Services\Notification\NotificationService;
use Filament\Forms\Components\Checkbox;
use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\Placeholder;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Form;
use Filament\Forms\Get;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Auth;

class AnnouncementCampaignResource extends Resource
{
    protected static ?string $model = AnnouncementCampaign::class;

    protected static ?string $navigationIcon = 'heroicon-o-bell-alert';
    protected static ?string $navigationLabel = 'إدارة الإشعارات';
    protected static ?string $modelLabel = 'حملة إشعار إداري';
    protected static ?string $pluralModelLabel = 'إدارة الإشعارات والإعلانات العامة';
    protected static ?string $navigationGroup = AdminPanelProvider::NAV_GROUP_SYSTEM;
    protected static ?int $navigationSort = 2;

    /**
     * Only active Super Administrators can access administrative announcement campaigns.
     * Moderators are restricted from sending bulk push notifications or viewing FCM infrastructure.
     */
    public static function canAccess(): bool
    {
        /** @var ?Administrator $admin */
        $admin = Auth::guard('admin')->user();
        return $admin !== null && $admin->isSuperAdmin();
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Section::make('إعداد الإعلان الإداري ومعاينة الجمهور')
                    ->columns(2)
                    ->schema([
                        TextInput::make('title_ar')
                            ->label('عنوان الإشعار (بالعربية)')
                            ->required()
                            ->maxLength(160)
                            ->live(onBlur: true),

                        Select::make('audience')
                            ->label('الجمهور المستهدف')
                            ->required()
                            ->options([
                                AnnouncementCampaign::AUDIENCE_ALL_ELIGIBLE => 'جميع الأعضاء النشطين المؤهلين',
                                AnnouncementCampaign::AUDIENCE_ACTIVE_SUBSCRIBERS => 'المشتركون النشطون حالياً',
                                AnnouncementCampaign::AUDIENCE_EXPIRED_SUBSCRIBERS => 'الأعضاء المنتهية اشتراكاتهم',
                            ])
                            ->default(AnnouncementCampaign::AUDIENCE_ALL_ELIGIBLE)
                            ->live(),

                        Textarea::make('body_ar')
                            ->label('نص الإشعار العام (لا تُدرج أي بيانات خاصة)')
                            ->required()
                            ->rows(3)
                            ->maxLength(500)
                            ->live(onBlur: true)
                            ->columnSpanFull(),

                        DateTimePicker::make('scheduled_at')
                            ->label('جدولة الإرسال في وقت لاحق (اختياري — اتركه فارغاً للإرسال الفوري في الخلفية)')
                            ->nullable(),

                        Placeholder::make('preview_summary')
                            ->label('معاينة الإشعار وعدد المستلمين المؤهلين')
                            ->content(function (Get $get): string {
                                $audience = (string) ($get('audience') ?: AnnouncementCampaign::AUDIENCE_ALL_ELIGIBLE);
                                $title = (string) ($get('title_ar') ?: '—');
                                $body = (string) ($get('body_ar') ?: '—');
                                $count = app(NotificationService::class)->countEligibleAudience($audience);

                                return "عدد المستلمين المؤهلين (ممن لم يوقفوا الإعلانات العامة): ({$count}) عضو | المعاينة: [{$title}] — {$body}";
                            }),

                        Checkbox::make('confirmed')
                            ->label('أؤكد مراجعة نص الإشعار ومعاينة عدد المستلمين والموافقة على إرساله عبر قائمة الانتظار')
                            ->accepted()
                            ->required()
                            ->columnSpanFull(),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('id', 'desc')
            ->columns([
                TextColumn::make('id')
                    ->label('#')
                    ->sortable(),

                TextColumn::make('title_ar')
                    ->label('عنوان الإشعار')
                    ->searchable()
                    ->limit(45),

                TextColumn::make('audience')
                    ->label('الجمهور المستهدف')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        AnnouncementCampaign::AUDIENCE_ACTIVE_SUBSCRIBERS => 'المشتركون النشطون',
                        AnnouncementCampaign::AUDIENCE_EXPIRED_SUBSCRIBERS => 'المنتهية اشتراكاتهم',
                        default => 'جميع الأعضاء المؤهلين',
                    }),

                TextColumn::make('status')
                    ->label('حالة الحملة')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        AnnouncementCampaign::STATUS_COMPLETED => 'success',
                        AnnouncementCampaign::STATUS_PROCESSING, AnnouncementCampaign::STATUS_QUEUED => 'warning',
                        AnnouncementCampaign::STATUS_CANCELLED => 'danger',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        AnnouncementCampaign::STATUS_DRAFT => 'مسودة',
                        AnnouncementCampaign::STATUS_SCHEDULED => 'مجدولة',
                        AnnouncementCampaign::STATUS_QUEUED => 'في قائمة الانتظار',
                        AnnouncementCampaign::STATUS_PROCESSING => 'قيد الإرسال',
                        AnnouncementCampaign::STATUS_COMPLETED => 'مكتملة الإدراج',
                        AnnouncementCampaign::STATUS_CANCELLED => 'ملغاة',
                        default => $state,
                    }),

                TextColumn::make('eligible_recipients_count')
                    ->label('المستلمون المؤهلون')
                    ->numeric(),

                TextColumn::make('queued_count')
                    ->label('تمت جدولتها')
                    ->numeric(),

                TextColumn::make('submitted_to_fcm_count')
                    ->label('مُرسل إلى FCM')
                    ->description('قبول خادم FCM لا يعني بالضرورة العرض على الجهاز')
                    ->numeric(),

                TextColumn::make('rejected_by_fcm_count')
                    ->label('مرفوض / بلا جهاز')
                    ->numeric(),

                TextColumn::make('confirmed_read_count')
                    ->label('مؤكد القراءة بالتطبيق')
                    ->numeric(),

                TextColumn::make('created_at')
                    ->label('تاريخ الإنشاء')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
            ])
            ->actions([
                Tables\Actions\ViewAction::make()->label('عرض التفاصيل'),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListAnnouncementCampaigns::route('/'),
            'create' => Pages\CreateAnnouncementCampaign::route('/create'),
        ];
    }
}
