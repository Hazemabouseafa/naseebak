<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Default Broadcaster (Laravel Reverb)
    |--------------------------------------------------------------------------
    */
    'default' => env('BROADCAST_CONNECTION', 'reverb'),

    'connections' => [
        'reverb' => [
            'driver' => 'reverb',
            'key' => env('REVERB_APP_KEY', 'naseebak-reverb-key'),
            'secret' => env('REVERB_APP_SECRET', 'naseebak-reverb-secret'),
            'app_id' => env('REVERB_APP_ID', 'naseebak-app'),
            'options' => [
                'host' => env('REVERB_HOST', '127.0.0.1'),
                'port' => env('REVERB_PORT', 8080),
                'scheme' => env('REVERB_SCHEME', 'http'),
                'useTLS' => env('REVERB_SCHEME', 'https') === 'https',
            ],
            'client_options' => [],
        ],

        'log' => [
            'driver' => 'log',
        ],

        'null' => [
            'driver' => 'null',
        ],
    ],
];
