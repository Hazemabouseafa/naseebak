import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/profile_registration_draft.dart';
import '../providers/profile_management_provider.dart';
import '../widgets/profile_photo_uploader.dart';
import '../widgets/step_progress_header.dart';

/// 19. Edit Profile Screen (تعديل الملف الشخصي)
/// تتيح تعديل كافة حقول الملف الشخصي مع تعبئة مسبقة ببيانات العضو الحالية،
/// وتتحقق من التغييرات غير المحفوظة، وتمنع من هم دون 18 عاماً، وتتحقق من اتساق الحالة الاجتماعية،
/// وترسل التعديلات عبر PATCH /api/v1/profile.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const List<String> _availableHobbies = [
    'القراءة',
    'السفر',
    'الرياضة',
    'الطبخ',
    'الفنون والتصميم',
    'العمل التطوعي',
    'التصوير',
    'المشي والطبيعة',
  ];

  late ProfileRegistrationDraft _initialDraft;
  late ProfileRegistrationDraft _workingDraft;

  late final TextEditingController _fullNameController;
  late final TextEditingController _occupationController;
  late final TextEditingController _nationalityController;
  late final TextEditingController _countryController;
  late final TextEditingController _regionController;
  late final TextEditingController _bioController;
  late final TextEditingController _childrenCountController;

  String? _localError;

  @override
  void initState() {
    super.initState();
    final existingProfile = ref.read(profileManagementProvider).profile;
    _initialDraft = existingProfile?.toRegistrationDraft() ??
        ProfileRegistrationDraft(dateOfBirth: DateTime(1992, 6, 15));
    _workingDraft = _initialDraft;

    _fullNameController = TextEditingController(text: _workingDraft.fullName);
    _occupationController =
        TextEditingController(text: _workingDraft.occupation);
    _nationalityController =
        TextEditingController(text: _workingDraft.nationality);
    _countryController =
        TextEditingController(text: _workingDraft.countryOfResidence);
    _regionController = TextEditingController(text: _workingDraft.region);
    _bioController = TextEditingController(text: _workingDraft.bio);
    _childrenCountController = TextEditingController(
      text: _workingDraft.childrenCount.toString(),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _occupationController.dispose();
    _nationalityController.dispose();
    _countryController.dispose();
    _regionController.dispose();
    _bioController.dispose();
    _childrenCountController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    return _workingDraft.fullName.trim() != _initialDraft.fullName.trim() ||
        _workingDraft.gender != _initialDraft.gender ||
        _workingDraft.dateOfBirth != _initialDraft.dateOfBirth ||
        _workingDraft.maritalStatus != _initialDraft.maritalStatus ||
        _workingDraft.previouslyMarried != _initialDraft.previouslyMarried ||
        _workingDraft.hasChildren != _initialDraft.hasChildren ||
        _workingDraft.childrenCount != _initialDraft.childrenCount ||
        _workingDraft.educationLevel != _initialDraft.educationLevel ||
        _workingDraft.occupation.trim() != _initialDraft.occupation.trim() ||
        _workingDraft.heightCm != _initialDraft.heightCm ||
        _workingDraft.smokingStatus != _initialDraft.smokingStatus ||
        _workingDraft.homeOwnership != _initialDraft.homeOwnership ||
        _workingDraft.nationality.trim() != _initialDraft.nationality.trim() ||
        _workingDraft.countryOfResidence.trim() !=
            _initialDraft.countryOfResidence.trim() ||
        _workingDraft.region.trim() != _initialDraft.region.trim() ||
        _workingDraft.bio.trim() != _initialDraft.bio.trim() ||
        _workingDraft.hobbies.join(',') != _initialDraft.hobbies.join(',');
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_hasUnsavedChanges) return true;

    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.backgroundPrimary,
          title: const Text(
            'تغييرات غير محفوظة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'لديك تعديلات لم يتم حفظها بعد. هل ترغب في تجاهل هذه التعديلات والخروج؟',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('البقاء في الصفحة'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size(110, 40),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('تجاهل التغييرات'),
            ),
          ],
        ),
      ),
    );

    return discard ?? false;
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final maxAdultDate = DateTime(now.year - 18, now.month, now.day);
    final initial = _workingDraft.dateOfBirth ?? DateTime(1992, 6, 15);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(maxAdultDate) ? maxAdultDate : initial,
      firstDate: DateTime(1940, 1, 1),
      lastDate: now,
      helpText: 'تاريخ الميلاد (18 عاماً فأكثر)',
      confirmText: 'تأكيد',
      cancelText: 'إلغاء',
    );

    if (picked != null) {
      setState(() {
        _workingDraft = _workingDraft.copyWith(dateOfBirth: picked);
        _localError = null;
      });
    }
  }

  Future<void> _handleSave() async {
    setState(() => _localError = null);

    final validationError =
        ProfileManagementNotifier.validateProfileDraft(_workingDraft);
    if (validationError != null) {
      setState(() => _localError = validationError);
      return;
    }

    final success = await ref
        .read(profileManagementProvider.notifier)
        .saveEditedProfile(_workingDraft);

    if (!mounted) return;

    if (success) {
      _initialDraft = _workingDraft;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryBlue,
          content: Text('تم حفظ التعديلات على ملفك الشخصي بنجاح.'),
        ),
      );
      Navigator.of(context).pop();
    } else {
      final apiErr = ref.read(profileManagementProvider).errorMessage;
      setState(() => _localError = apiErr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mgmtState = ref.watch(profileManagementProvider);
    final dob = _workingDraft.dateOfBirth;
    final ageYears = _workingDraft.calculatedAgeYears;
    final initialLetter = _workingDraft.fullName.trim().isNotEmpty
        ? _workingDraft.fullName.trim().substring(0, 1)
        : 'ن';

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldDiscard = await _confirmDiscardIfNeeded();
        if (shouldDiscard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            onPressed: () async {
              final shouldDiscard = await _confirmDiscardIfNeeded();
              if (shouldDiscard && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            tooltip: 'رجوع',
          ),
          title: const Text('تعديل الملف الشخصي'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.borderLight),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_localError != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.error.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _localError!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profile Photo Section
                      Center(
                        child: ProfilePhotoUploader(
                          fallbackInitial: initialLetter,
                          radius: 44,
                          showChangeButton: true,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Full Name
                      const _FieldLabel('الاسم الكامل'),
                      TextField(
                        key: const Key('edit_full_name_input'),
                        controller: _fullNameController,
                        onChanged: (val) => setState(() {
                          _workingDraft =
                              _workingDraft.copyWith(fullName: val);
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Gender
                      const _FieldLabel('النوع'),
                      NaseebakSegmentedControl<String>(
                        options: const {
                          'female': 'أنثى',
                          'male': 'ذكر',
                        },
                        selectedValue: _workingDraft.gender,
                        onChanged: (val) => setState(() {
                          _workingDraft = _workingDraft.copyWith(gender: val);
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Date of Birth & Auto-calculated Age/Zodiac
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _FieldLabel('تاريخ الميلاد'),
                          if (ageYears != null)
                            Text(
                              'العمر: $ageYears سنة • البرج: ${_workingDraft.calculatedZodiacSignAr}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: ageYears >= 18
                                    ? AppColors.primaryBlue
                                    : AppColors.error,
                              ),
                            ),
                        ],
                      ),
                      InkWell(
                        key: const Key('edit_dob_picker'),
                        onTap: _selectDateOfBirth,
                        borderRadius: BorderRadius.circular(11),
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dob != null
                                    ? '${dob.day.toString().padLeft(2, '0')} / ${dob.month.toString().padLeft(2, '0')} / ${dob.year}'
                                    : 'اختر تاريخ الميلاد',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: AppColors.primaryBlue,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Marital Status
                      const _FieldLabel('الحالة الاجتماعية'),
                      NaseebakSegmentedControl<String>(
                        options: _workingDraft.gender == 'male'
                            ? const {
                                'single': 'أعزب',
                                'divorced': 'مطلق',
                                'widowed': 'أرمل',
                              }
                            : const {
                                'single': 'عزباء',
                                'divorced': 'مطلقة',
                                'widowed': 'أرملة',
                              },
                        selectedValue: _workingDraft.maritalStatus,
                        onChanged: (status) => setState(() {
                          _workingDraft = _workingDraft.copyWith(
                            maritalStatus: status,
                            previouslyMarried:
                                status == 'single' ? false : true,
                            hasChildren: status == 'single'
                                ? false
                                : _workingDraft.hasChildren,
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Previous Marriage
                      const _FieldLabel('هل سبق لك الزواج؟'),
                      NaseebakSegmentedControl<bool>(
                        options: const {
                          true: 'نعم',
                          false: 'لا',
                        },
                        selectedValue: _workingDraft.previouslyMarried,
                        onChanged: (val) => setState(() {
                          _workingDraft =
                              _workingDraft.copyWith(previouslyMarried: val);
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Children
                      const _FieldLabel('هل لديك أطفال؟'),
                      NaseebakSegmentedControl<bool>(
                        options: const {
                          true: 'نعم',
                          false: 'لا',
                        },
                        selectedValue: _workingDraft.hasChildren,
                        onChanged: (val) => setState(() {
                          _workingDraft = _workingDraft.copyWith(
                            hasChildren: val,
                            childrenCount: val
                                ? (_workingDraft.childrenCount > 0
                                    ? _workingDraft.childrenCount
                                    : 1)
                                : 0,
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Educational Qualification
                      const _FieldLabel('المؤهل الدراسي'),
                      DropdownButtonFormField<String>(
                        value: _workingDraft.educationLevel,
                        items: const [
                          DropdownMenuItem(
                            value: 'bachelor',
                            child: Text('بكالوريوس / ليسانس'),
                          ),
                          DropdownMenuItem(
                            value: 'master',
                            child: Text('ماجستير'),
                          ),
                          DropdownMenuItem(
                            value: 'doctorate',
                            child: Text('دكتوراه'),
                          ),
                          DropdownMenuItem(
                            value: 'diploma',
                            child: Text('دبلوم متوسط / فوق متوسط'),
                          ),
                          DropdownMenuItem(
                            value: 'high_school',
                            child: Text('ثانوية عامة أو ما يعادلها'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('مؤهل آخر'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _workingDraft = _workingDraft.copyWith(
                                educationLevel: val,
                              );
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Occupation
                      const _FieldLabel('المهنة / العمل'),
                      TextField(
                        key: const Key('edit_occupation_input'),
                        controller: _occupationController,
                        onChanged: (val) => setState(() {
                          _workingDraft =
                              _workingDraft.copyWith(occupation: val);
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Height Slider
                      _FieldLabel('الطول: ${_workingDraft.heightCm} سم'),
                      Slider(
                        value: _workingDraft.heightCm.toDouble(),
                        min: 140,
                        max: 210,
                        divisions: 70,
                        activeColor: AppColors.primaryBlue,
                        onChanged: (val) => setState(() {
                          _workingDraft =
                              _workingDraft.copyWith(heightCm: val.round());
                        }),
                      ),
                      const SizedBox(height: 12),

                      // Smoking Status
                      const _FieldLabel('حالة التدخين'),
                      NaseebakSegmentedControl<String>(
                        options: const {
                          'non_smoker': 'غير مدخن',
                          'occasional': 'أحياناً',
                          'smoker': 'مدخن',
                        },
                        selectedValue: _workingDraft.smokingStatus,
                        onChanged: (val) => setState(() {
                          _workingDraft =
                              _workingDraft.copyWith(smokingStatus: val);
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Home Ownership
                      const _FieldLabel('حالة السكن / المنزل'),
                      NaseebakSegmentedControl<String>(
                        options: const {
                          'owned': 'تمليك',
                          'rented': 'إيجار',
                          'family_home': 'مع الأسرة',
                        },
                        selectedValue: _workingDraft.homeOwnership,
                        onChanged: (val) => setState(() {
                          _workingDraft =
                              _workingDraft.copyWith(homeOwnership: val);
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Nationality, Country, Region
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('الجنسية'),
                                TextField(
                                  controller: _nationalityController,
                                  onChanged: (val) => setState(() {
                                    _workingDraft = _workingDraft.copyWith(
                                      nationality: val,
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('بلد الإقامة'),
                                TextField(
                                  controller: _countryController,
                                  onChanged: (val) => setState(() {
                                    _workingDraft = _workingDraft.copyWith(
                                      countryOfResidence: val,
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      const _FieldLabel('المحافظة / المنطقة'),
                      TextField(
                        controller: _regionController,
                        onChanged: (val) => setState(() {
                          _workingDraft = _workingDraft.copyWith(region: val);
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Hobbies
                      const _FieldLabel('الهوايات والاهتمامات'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableHobbies.map((hobby) {
                          final isSelected =
                              _workingDraft.hobbies.contains(hobby);
                          return FilterChip(
                            label: Text(hobby),
                            selected: isSelected,
                            selectedColor: AppColors.surfaceSubtleBlue,
                            checkmarkColor: AppColors.primaryBlue,
                            onSelected: (selected) {
                              final updated =
                                  List<String>.from(_workingDraft.hobbies);
                              if (selected) {
                                updated.add(hobby);
                              } else {
                                updated.remove(hobby);
                              }
                              setState(() {
                                _workingDraft =
                                    _workingDraft.copyWith(hobbies: updated);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Biography
                      const _FieldLabel('النبذة الشخصية (اختياري)'),
                      TextField(
                        key: const Key('edit_bio_input'),
                        controller: _bioController,
                        maxLines: 3,
                        onChanged: (val) => setState(() {
                          _workingDraft = _workingDraft.copyWith(bio: val);
                        }),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Save Button Bar
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                decoration: const BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  border: Border(top: BorderSide(color: AppColors.borderLight)),
                ),
                child: ElevatedButton.icon(
                  key: const Key('save_edited_profile_btn'),
                  onPressed: mgmtState.isSaving ? null : _handleSave,
                  icon: mgmtState.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 19),
                  label: Text(
                    mgmtState.isSaving
                        ? 'جارٍ حفظ التعديلات...'
                        : 'حفظ التعديلات',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
