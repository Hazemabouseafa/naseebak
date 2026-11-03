<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Filesystem Disk
    |--------------------------------------------------------------------------
    */

    'default' => env('FILESYSTEM_DISK', 'local'),

    /*
    |--------------------------------------------------------------------------
    | Filesystem Disks
    |--------------------------------------------------------------------------
    |
    | Naseebak stores all member profile photos exclusively on the 'private'
    | disk (storage/app/private/member-photos/{user_id}/{uuid}.jpg).
    | Public symlinks to private photos are strictly prohibited.
    |
    */

    'disks' => [

        'local' => [
            'driver' => 'local',
            'root' => storage_path('app/private'),
            'serve' => false,
            'throw' => false,
            'report' => false,
        ],

        'private' => [
            'driver' => 'local',
            'root' => env('PRIVATE_STORAGE_ROOT', storage_path('app/private')),
            'visibility' => 'private',
            'serve' => false,
            'throw' => false,
            'report' => false,
        ],

        'public' => [
            'driver' => 'local',
            'root' => storage_path('app/public'),
            'url' => env('APP_URL').'/storage',
            'visibility' => 'public',
            'throw' => false,
            'report' => false,
        ],

        'backups' => [
            'driver' => env('BACKUP_DISK_DRIVER', 'local'),
            'root' => env('BACKUP_LOCAL_ROOT', storage_path('app/backups')),
            'key' => env('BACKUP_S3_ACCESS_KEY_ID'),
            'secret' => env('BACKUP_S3_SECRET_ACCESS_KEY'),
            'region' => env('BACKUP_S3_DEFAULT_REGION', 'eu-central-1'),
            'bucket' => env('BACKUP_S3_BUCKET'),
            'endpoint' => env('BACKUP_S3_ENDPOINT'),
            'use_path_style_endpoint' => env('BACKUP_S3_USE_PATH_STYLE_ENDPOINT', false),
            'visibility' => 'private',
            'throw' => false,
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Symbolic Links
    |--------------------------------------------------------------------------
    |
    | Do NOT link storage/app/private to public/.
    |
    */

    'links' => [],

];
