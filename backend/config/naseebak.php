<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Naseebak Platform Configuration
    |--------------------------------------------------------------------------
    */
    'name_ar' => 'نصيبك',
    'name_en' => 'Naseebak',
    'minimum_age' => 18,

    'google_auth' => [
        'android_client_id' => env('GOOGLE_ANDROID_CLIENT_ID'),
        'web_client_id' => env('GOOGLE_WEB_CLIENT_ID'),
        'allowed_issuers' => [
            'accounts.google.com',
            'https://accounts.google.com',
        ],
    ],

    'google_play' => [
        'package_name' => env('GOOGLE_PLAY_PACKAGE_NAME', 'com.naseebak.app'),
        'service_account_json' => env('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH'),
        'monthly_subscription_id' => env('GOOGLE_PLAY_MONTHLY_SUBSCRIPTION_ID', 'naseebak_monthly_membership'),
        'rtdn_oidc_audience' => env('GOOGLE_PLAY_RTDN_OIDC_AUDIENCE'),
        'rtdn_service_account_email' => env('GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT_EMAIL'),
        'rtdn_oidc_public_key_pem' => env('GOOGLE_PLAY_RTDN_OIDC_PUBLIC_KEY_PEM'),
        'rtdn_allowed_issuers' => [
            'https://accounts.google.com',
            'accounts.google.com',
        ],
    ],

    'fcm' => [
        'project_id' => env('FCM_PROJECT_ID'),
        'service_account_json' => env('FCM_SERVICE_ACCOUNT_JSON_PATH'),
        'generic_message_notification_title' => 'رسالة جديدة',
        'generic_message_notification_body' => 'لديك رسالة جديدة',
        'channels' => [
            'matchmaking' => 'matchmaking_requests',
            'messages' => 'private_messages',
            'subscriptions' => 'subscription_updates',
            'announcements' => 'announcements',
        ],
    ],

    'notifications' => [
        'subscription_expiry_reminder_days' => (int) env('NASEEBAK_SUB_EXPIRY_REMINDER_DAYS', 3),
        'notifications_per_page' => (int) env('NASEEBAK_NOTIFICATIONS_PER_PAGE', 20),
        'retention_days' => (int) env('NASEEBAK_NOTIFICATION_RETENTION_DAYS', 90),
        'delivery_attempts_retention_days' => (int) env('NASEEBAK_DELIVERY_ATTEMPTS_RETENTION_DAYS', 30),
        'campaign_chunk_size' => (int) env('NASEEBAK_CAMPAIGN_CHUNK_SIZE', 100),
    ],

    'web_payments' => [
        'allowed_gateways' => ['paymob', 'sha7nawy'],
        'paymob' => [
            'api_key' => env('PAYMOB_API_KEY'),
            'secret_key' => env('PAYMOB_SECRET_KEY'),
            'public_key' => env('PAYMOB_PUBLIC_KEY'),
            'hmac_secret' => env('PAYMOB_HMAC_SECRET'),
            'integration_id_card' => env('PAYMOB_INTEGRATION_ID_CARD'),
            'iframe_id' => env('PAYMOB_IFRAME_ID'),
        ],
        'sha7nawy' => [
            'base_url' => env('SHA7NAWY_BASE_URL', 'https://gate.sha7nawy.com'),
            'api_key' => env('SHA7NAWY_API_KEY'),
            'merchant_id' => env('SHA7NAWY_MERCHANT_ID'),
            'webhook_secret' => env('SHA7NAWY_WEBHOOK_SECRET'),
        ],
    ],

    'uploads' => [
        'max_photo_size_kb' => 2048, // 2 MB strict upload limit for shared VPS
        'max_photos_per_user' => 3,
        'compression_quality' => 80,
        'max_dimension_px' => 1080,
    ],

    'matchmaking' => [
        // Safe non-harassment policy: rejected requests cannot be re-sent automatically by default
        'allow_rerequest_after_rejection' => env('NASEEBAK_ALLOW_REREQUEST_AFTER_REJECTION', false),
    ],

    'messaging' => [
        'max_message_length' => (int) env('NASEEBAK_MAX_MESSAGE_LENGTH', 2000),
        'messages_per_page' => (int) env('NASEEBAK_MESSAGES_PER_PAGE', 30),
        'conversations_per_page' => (int) env('NASEEBAK_CONVERSATIONS_PER_PAGE', 20),
    ],
];
