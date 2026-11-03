<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class SearchMembersRequest extends FormRequest
{
    public const ALLOWED_SORTS = [
        'newest',
        'age_asc',
        'age_desc',
    ];

    public const ALLOWED_EDUCATION_LEVELS = [
        'high_school',
        'diploma',
        'bachelor',
        'master',
        'doctorate',
        'other',
    ];

    public const ALLOWED_MARITAL_STATUSES = [
        'single',
        'divorced',
        'widowed',
    ];

    public const ALLOWED_SMOKING_STATUSES = [
        'non_smoker',
        'smoker',
        'occasional',
        'all',
    ];

    public function authorize(): bool
    {
        return $this->user() !== null && $this->user()->account_status === 'active';
    }

    public function rules(): array
    {
        return [
            'gender' => ['nullable', Rule::in(['male', 'female'])],
            'min_age' => ['nullable', 'integer', 'min:18', 'max:95'],
            'max_age' => ['nullable', 'integer', 'min:18', 'max:95'],
            'marital_statuses' => ['nullable', 'array'],
            'marital_statuses.*' => ['required', 'string', Rule::in(self::ALLOWED_MARITAL_STATUSES)],
            'marital_status' => ['nullable', 'string', Rule::in(self::ALLOWED_MARITAL_STATUSES)],
            'education_level' => ['nullable', 'string', Rule::in(self::ALLOWED_EDUCATION_LEVELS)],
            'smoking_status' => ['nullable', 'string', Rule::in(self::ALLOWED_SMOKING_STATUSES)],
            'occupation' => ['nullable', 'string', 'max:120'],
            'nationality' => ['nullable', 'string', 'max:64'],
            'country_of_residence' => ['nullable', 'string', 'max:64'],
            'region' => ['nullable', 'string', 'max:80'],
            'sort' => ['nullable', 'string', Rule::in(self::ALLOWED_SORTS)],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
            'page' => ['nullable', 'integer', 'min:1'],
            'save_preferences' => ['sometimes', 'boolean'],
        ];
    }

    public function messages(): array
    {
        return [
            'gender.in' => 'خيار النوع غير صالح.',
            'min_age.min' => 'الحد الأدنى للعمر يجب ألا يقل عن 18 سنة.',
            'max_age.min' => 'الحد الأقصى للعمر يجب ألا يقل عن 18 سنة.',
            'marital_statuses.*.in' => 'إحدى قيم الحالة الاجتماعية المختارة غير صالحة.',
            'education_level.in' => 'المؤهل الدراسي المختار غير صالح.',
            'smoking_status.in' => 'حالة التدخين المختارة غير صالحة.',
            'sort.in' => 'خيار الترتيب غير مدعوم.',
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator) {
                if ($validator->errors()->isNotEmpty()) {
                    return;
                }

                $minAge = $this->input('min_age');
                $maxAge = $this->input('max_age');

                if ($minAge !== null && $maxAge !== null && (int) $minAge > (int) $maxAge) {
                    $validator->errors()->add(
                        'min_age',
                        'الحد الأدنى للعمر يجب أن يكون أقل من أو يساوي الحد الأقصى للعمر.'
                    );
                }
            },
        ];
    }

    public function normalizedFilters(): array
    {
        $validated = $this->validated();

        $maritalStatuses = $validated['marital_statuses'] ?? [];
        if (empty($maritalStatuses) && !empty($validated['marital_status'])) {
            $maritalStatuses = [$validated['marital_status']];
        }

        $smokingStatus = $validated['smoking_status'] ?? null;
        if ($smokingStatus === 'all') {
            $smokingStatus = null;
        }

        return [
            'gender' => $validated['gender'] ?? null,
            'min_age' => isset($validated['min_age']) ? (int) $validated['min_age'] : null,
            'max_age' => isset($validated['max_age']) ? (int) $validated['max_age'] : null,
            'marital_statuses' => array_values(array_unique($maritalStatuses)),
            'education_level' => $validated['education_level'] ?? null,
            'smoking_status' => $smokingStatus,
            'occupation' => isset($validated['occupation']) && trim($validated['occupation']) !== ''
                ? trim($validated['occupation'])
                : null,
            'nationality' => isset($validated['nationality']) && trim($validated['nationality']) !== ''
                ? trim($validated['nationality'])
                : null,
            'country_of_residence' => isset($validated['country_of_residence']) && trim($validated['country_of_residence']) !== ''
                ? trim($validated['country_of_residence'])
                : null,
            'region' => isset($validated['region']) && trim($validated['region']) !== ''
                ? trim($validated['region'])
                : null,
            'sort' => $validated['sort'] ?? 'newest',
            'per_page' => isset($validated['per_page']) ? (int) $validated['per_page'] : 20,
        ];
    }
}
