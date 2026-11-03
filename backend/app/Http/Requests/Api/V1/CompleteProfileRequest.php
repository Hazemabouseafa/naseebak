<?php

namespace App\Http\Requests\Api\V1;

use App\Models\UserProfile;
use Carbon\Carbon;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class CompleteProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null && $this->user()->account_status === 'active';
    }

    public function rules(): array
    {
        return [
            'full_name' => ['required', 'string', 'min:3', 'max:120'],
            'gender' => ['required', Rule::in(['male', 'female'])],
            'date_of_birth' => [
                'required',
                'date_format:Y-m-d',
                'before_or_equal:' . Carbon::now()->subYears(18)->format('Y-m-d'),
                'after_or_equal:' . Carbon::now()->subYears(95)->format('Y-m-d'),
            ],
            'marital_status' => ['required', Rule::in(['single', 'divorced', 'widowed'])],
            'previously_married' => ['required', 'boolean'],
            'has_children' => ['required', 'boolean'],
            'children_count' => ['nullable', 'integer', 'min:0', 'max:20'],
            'education_level' => [
                'required',
                Rule::in(['high_school', 'diploma', 'bachelor', 'master', 'doctorate', 'other']),
            ],
            'occupation' => ['required', 'string', 'min:2', 'max:120'],
            'height_cm' => ['required', 'integer', 'min:120', 'max:230'],
            'zodiac_sign' => ['nullable', 'string', 'max:32'],
            'smoking_status' => ['required', Rule::in(['non_smoker', 'smoker', 'occasional'])],
            'home_ownership' => ['required', Rule::in(['owned', 'rented', 'family_home', 'not_specified'])],
            'hobbies' => ['required', 'array', 'min:1', 'max:10'],
            'hobbies.*' => ['required', 'string', 'max:50'],
            'nationality' => ['required', 'string', 'min:2', 'max:64'],
            'country_of_residence' => ['required', 'string', 'min:2', 'max:64'],
            'region' => ['required', 'string', 'min:2', 'max:80'],
            'bio' => ['nullable', 'string', 'max:1000'],
            'is_visible' => ['sometimes', 'boolean'],
            'photo_privacy' => ['sometimes', Rule::in(['public', 'subscribers_only', 'accepted_matches_only'])],
        ];
    }

    public function messages(): array
    {
        return [
            'full_name.required' => 'يرجى إدخال الاسم الكامل.',
            'gender.required' => 'يرجى تحديد النوع.',
            'date_of_birth.required' => 'يرجى إدخال تاريخ الميلاد.',
            'date_of_birth.before_or_equal' => 'تطبيق نصيبك مخصص للبالغين من عمر 18 عاماً فأكثر فقط.',
            'marital_status.required' => 'يرجى تحديد الحالة الاجتماعية.',
            'education_level.required' => 'يرجى اختيار المؤهل الدراسي.',
            'occupation.required' => 'يرجى إدخال المهنة أو مجال العمل.',
            'height_cm.required' => 'يرجى إدخال الطول بالسنتيمتر.',
            'height_cm.min' => 'يرجى إدخال طول صحيح (بين 120 و 230 سم).',
            'smoking_status.required' => 'يرجى تحديد حالة التدخين.',
            'home_ownership.required' => 'يرجى تحديد حالة السكن.',
            'hobbies.required' => 'يرجى اختيار هواية واحدة على الأقل.',
            'nationality.required' => 'يرجى تحديد الجنسية.',
            'country_of_residence.required' => 'يرجى تحديد بلد الإقامة.',
            'region.required' => 'يرجى تحديد المحافظة أو المنطقة.',
        ];
    }

    /**
     * Validate logically inconsistent answers:
     * 1. Minimum age 18 double-check.
     * 2. If marital_status is 'single' (أعزب / عزباء), previously_married MUST be false and has_children MUST be false.
     * 3. If marital_status is 'divorced' or 'widowed', previously_married MUST be true.
     * 4. If has_children is false, children_count must be 0.
     */
    public function after(): array
    {
        return [
            function (Validator $validator) {
                if ($validator->errors()->isNotEmpty()) {
                    return;
                }

                $dob = (string) $this->input('date_of_birth');
                $age = UserProfile::calculateAgeYears($dob);
                if ($age < 18) {
                    $validator->errors()->add(
                        'date_of_birth',
                        'تطبيق نصيبك مخصص للبالغين بعمر 18 سنة فأكثر فقط.'
                    );
                }

                $maritalStatus = (string) $this->input('marital_status');
                $previouslyMarried = filter_var($this->input('previously_married'), FILTER_VALIDATE_BOOLEAN);
                $hasChildren = filter_var($this->input('has_children'), FILTER_VALIDATE_BOOLEAN);
                $childrenCount = (int) $this->input('children_count', 0);

                if ($maritalStatus === 'single' && $previouslyMarried) {
                    $validator->errors()->add(
                        'previously_married',
                        'لا يمكن اختيار "سبق الزواج" عندما تكون الحالة الاجتماعية أعزب/عزباء.'
                    );
                }

                if ($maritalStatus === 'single' && $hasChildren) {
                    $validator->errors()->add(
                        'has_children',
                        'يرجى مراجعة الحالة الاجتماعية؛ لا يتوافق وجود أطفال مع الحالة الاجتماعية أعزب/عزباء.'
                    );
                }

                if (in_array($maritalStatus, ['divorced', 'widowed'], true) && !$previouslyMarried) {
                    $validator->errors()->add(
                        'previously_married',
                        'الحالة الاجتماعية (مطلق/أرمل) تتطلب أن تكون الإجابة على "هل سبق لك الزواج؟" هي نعم.'
                    );
                }

                if (!$hasChildren && $childrenCount > 0) {
                    $validator->errors()->add(
                        'children_count',
                        'عدد الأطفال يجب أن يكون صفراً عند اختيار عدم وجود أطفال.'
                    );
                }
            },
        ];
    }
}
