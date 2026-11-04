<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class AccountDeletionVerificationMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public readonly string $signedUrl,
        public readonly string $userEmail
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'تأكيد طلب حذف حسابك على منصة نَصِيبُكَ',
        );
    }

    public function content(): Content
    {
        return new Content(
            htmlString: '
                <div dir="rtl" style="font-family: Arial, sans-serif; line-height: 1.8; color: #1e293b; padding: 24px;">
                    <h2 style="color: #123D6A;">نَصِيبُكَ — تأكيد طلب حذف الحساب والبيانات</h2>
                    <p>مرحباً،</p>
                    <p>لقد تلقينا طلباً لحذف حسابك والبيانات الشخصية المرتبطة به على منصة نَصِيبُكَ.</p>
                    <p>لتأكيد رغبتك في حذف الحساب نهائياً، يرجى النقر على الرابط التالي خلال 30 دقيقة:</p>
                    <p><a href="' . htmlspecialchars($this->signedUrl, ENT_QUOTES, 'UTF-8') . '" style="background: #DC2626; color: #ffffff; padding: 12px 20px; text-decoration: none; border-radius: 8px; font-weight: bold; display: inline-block;">تأكيد حذف الحساب نهائياً</a></p>
                    <p style="font-size: 13px; color: #64748b;">إذا لم تكن أنت من أرسل هذا الطلب، فيمكنك تجاهل هذه الرسالة ولن يتم حذف حسابك بأي شكل.</p>
                    <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 24px 0;">
                    <p style="font-size: 12px; color: #94a3b8;">فريق أمان نَصِيبُكَ — Naseebak Platform</p>
                </div>
            ',
        );
    }
}
