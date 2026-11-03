<?php

namespace App\Http\Requests\Api\V1;

class UpdateProfileRequest extends CompleteProfileRequest
{
    /**
     * Inherits all strict 18+ age validation, marital status consistency rules,
     * and prevents any client-supplied user_id override.
     */
    public function rules(): array
    {
        return array_merge(parent::rules(), [
            // Explicitly forbid user_id manipulation in request payload
            'user_id' => ['prohibited'],
        ]);
    }

    public function messages(): array
    {
        return array_merge(parent::messages(), [
            'user_id.prohibited' => 'غير مسموح بتمرير معرّف المستخدم يدوياً؛ يتم تحديد الهوية من الجلسة الموثقة فقط.',
        ]);
    }
}
