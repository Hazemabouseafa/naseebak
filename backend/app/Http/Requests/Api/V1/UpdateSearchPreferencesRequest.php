<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class UpdateSearchPreferencesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null && $this->user()->account_status === 'active';
    }

    public function rules(): array
    {
        return [
            'preferred_gender' => ['nullable', Rule::in(['male', 'female'])],
            'min_age' => ['required', 'integer', 'min:18', 'max:95'],
            'max_age' => ['required', 'integer', 'min:18', 'max:95'],
            'marital_statuses' => ['nullable', 'array'],
            'marital_statuses.*' => ['required', 'string', Rule::in(SearchMembersRequest::ALLOWED_MARITAL_STATUSES)],
            'education_level' => ['nullable', 'string', Rule::in(SearchMembersRequest::ALLOWED_EDUCATION_LEVELS)],
            'smoking_status' => ['nullable', 'string', Rule::in(SearchMembersRequest::ALLOWED_SMOKING_STATUSES)],
            'occupation' => ['nullable', 'string', 'max:120'],
            'nationality' => ['nullable', 'string', 'max:64'],
            'country_of_residence' => ['nullable', 'string', 'max:64'],
            'region' => ['nullable', 'string', 'max:80'],
        ];
    }

    public function messages(): array
    {
        return [
            'min_age.min' => 'الحد الأدنى للعمر يجب ألا يقل عن 18 سنة.',
            'max_age.min' => 'الحد الأقصى للعمر يجب ألا يقل عن 18 سنة.',
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator) {
                if ($validator->errors()->isNotEmpty()) {
                    return;
                }

                $minAge = (int) $this->input('min_age', 18);
                $maxAge = (int) $this->input('max_age', 60);

                if ($minAge > $maxAge) {
                    $validator->errors()->add(
                        'min_age',
                        'الحد الأدنى للعمر يجب أن يكون أقل من أو يساوي الحد الأقصى للعمر.'
                    );
                }
            },
        ];
    }
}
