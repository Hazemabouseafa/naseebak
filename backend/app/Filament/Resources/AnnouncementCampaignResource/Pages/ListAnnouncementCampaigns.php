<?php

namespace App\Filament\Resources\AnnouncementCampaignResource\Pages;

use App\Filament\Resources\AnnouncementCampaignResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListAnnouncementCampaigns extends ListRecords
{
    protected static string $resource = AnnouncementCampaignResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make()
                ->label('إنشاء إعلان إداري جديد'),
        ];
    }
}
