<?php

namespace App\Filament\Resources\AnnouncementCampaignResource\Pages;

use App\Filament\Resources\AnnouncementCampaignResource;
use App\Models\Administrator;
use App\Services\Notification\NotificationService;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;

class CreateAnnouncementCampaign extends CreateRecord
{
    protected static string $resource = AnnouncementCampaignResource::class;

    protected function handleRecordCreation(array $data): Model
    {
        /** @var Administrator $actor */
        $actor = Auth::guard('admin')->user();

        return app(NotificationService::class)->createAndQueueAnnouncementCampaign($actor, $data);
    }
}
