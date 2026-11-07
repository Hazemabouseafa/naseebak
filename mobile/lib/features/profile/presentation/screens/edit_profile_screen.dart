import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../domain/profile_registration_draft.dart';
import '../providers/profile_management_provider.dart';
import '../widgets/profile_photo_uploader.dart';
import '../widgets/step_progress_header.dart';

/// Screen 08 (Batch 2B) — Edit Profile Screen (`تعديل الملف الشخصي`)
/// تتيح تعديل كافة حقول الملف الشخصي بتصميم نَصِيبُكَ الفاخر (Astra Design System)
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
          backgroundColor: NaseebakColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: NaseebakColors.borderLight),
          ),
          title: const Text(
            'تغييرات غير محفوظة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: NaseebakColors.textDarkNavy,
            ),
          ),
          content: const Text(
            'لديك تعديلات لم يتم حفظها بعد. هل ترغب في تجاهل هذه التعديلات والخروج؟',
            style: TextStyle(
              fontSize: 13,
              color: NaseebakColors.textWarmGray,
              height: 1.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('البقاء في الصفحة'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: NaseebakColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
          backgroundColor: NaseebakColors.primaryNavy,
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
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.cardWhite,
          appBar: AppBar(
            backgroundColor: AppColors.cardWhite,
            elevation: 0,
            centerTitle: true,
            leading: Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 14),
                child: NaseebakCircleButton(
                  icon: Icons.arrow_forward_rounded,
                  size: 40,
                  iconSize: 20,
                  onTap: () async {
                    final shouldDiscard = await _confirmDiscardIfNeeded();
                    if (shouldDiscard && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  tooltip: 'رجوع',
                ),
              ),
            ),
            title: const Text(
              'تعديل الملف الشخصي',
              style: TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    if (_localError != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: NaseebakColors.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: NaseebakColors.error.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: NaseebakColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _localError!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: NaseebakColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Profile Photo Section
                            Center(
                              child: ProfilePhotoUploader(
                                fallbackInitial: initialLetter,
                                radius: 46,
                                showChangeButton: true,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Personal Info Card
                            _FormSectionContainer(
                              title: 'البيانات الشخصية الأساسية',
                              children: [
                                const _FieldLabel('الاسم الكامل'),
                                TextField(
                                  key: const Key('edit_full_name_input'),
                                  controller: _fullNameController,
                                  decoration: const InputDecoration(
                                    hintText: 'الاسم الكامل أو الكنية المحترمة',
                                  ),
                                  onChanged: (val) => setState(() {
                                    _workingDraft =
                                        _workingDraft.copyWith(fullName: val);
                                  }),
                                ),
                                const SizedBox(height: 14),

                                const _FieldLabel('النوع'),
                                NaseebakSegmentedControl<String>(
                                  options: const {
                                    'female': 'أنثى',
                                    'male': 'ذكر',
                                  },
                                  selectedValue: _workingDraft.gender,
                                  onChanged: (val) => setState(() {
                                    _workingDraft =
                                        _workingDraft.copyWith(gender: val);
                                  }),
                                ),
                                const SizedBox(height: 14),

                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const _FieldLabel('تاريخ الميلاد'),
                                    if (ageYears != null)
                                      Text(
                                        'العمر: $ageYears سنة • البرج: ${_workingDraft.calculatedZodiacSignAr}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: ageYears >= 18
                                              ? NaseebakColors.accentGoldDark
                                              : NaseebakColors.error,
                                        ),
                                      ),
                                  ],
                                ),
                                InkWell(
                                  key: const Key('edit_dob_picker'),
                                  onTap: _selectDateOfBirth,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: NaseebakColors.backgroundBeige,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: NaseebakColors.borderLight,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          dob != null
                                              ? '${dob.day.toString().padLeft(2, '0')} / ${dob.month.toString().padLeft(2, '0')} / ${dob.year}'
                                              : 'اختر تاريخ الميلاد',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: NaseebakColors.textDarkNavy,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 18,
                                          color: NaseebakColors.accentGoldDark,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Family & Marital Status Card
                            _FormSectionContainer(
                              title: 'الحالة الاجتماعية والأسرية',
                              children: [
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
                                const SizedBox(height: 14),

                                const _FieldLabel('هل سبق لك الزواج؟'),
                                NaseebakSegmentedControl<bool>(
                                  options: const {
                                    true: 'نعم',
                                    false: 'لا',
                                  },
                                  selectedValue: _workingDraft.previouslyMarried,
                                  onChanged: (val) => setState(() {
                                    _workingDraft = _workingDraft.copyWith(
                                      previouslyMarried: val,
                                    );
                                  }),
                                ),
                                const SizedBox(height: 14),

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
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Education & Work Card
                            _FormSectionContainer(
                              title: 'المؤهل العلمي والعمل',
                              children: [
                                const _FieldLabel('المؤهل الدراسي'),
                                DropdownButtonFormField<String>(
                                  value: _workingDraft.educationLevel,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: NaseebakColors.backgroundBeige,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 11,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: NaseebakColors.borderLight,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: NaseebakColors.borderLight,
                                      ),
                                    ),
                                  ),
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
                                const SizedBox(height: 14),

                                const _FieldLabel('المهنة / العمل'),
                                TextField(
                                  key: const Key('edit_occupation_input'),
                                  controller: _occupationController,
                                  decoration: const InputDecoration(
                                    hintText: 'مثال: مهندس برمجيات، معلم، محاسب...',
                                  ),
                                  onChanged: (val) => setState(() {
                                    _workingDraft =
                                        _workingDraft.copyWith(occupation: val);
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Physical & Lifestyle Card
                            _FormSectionContainer(
                              title: 'المواصفات ونمط الحياة',
                              children: [
                                _FieldLabel('الطول: ${_workingDraft.heightCm} سم'),
                                Slider(
                                  value: _workingDraft.heightCm.toDouble(),
                                  min: 140,
                                  max: 210,
                                  divisions: 70,
                                  activeColor: NaseebakColors.accentGoldDark,
                                  inactiveColor: NaseebakColors.borderLight,
                                  onChanged: (val) => setState(() {
                                    _workingDraft = _workingDraft.copyWith(
                                      heightCm: val.round(),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 10),

                                const _FieldLabel('حالة التدخين'),
                                NaseebakSegmentedControl<String>(
                                  options: const {
                                    'non_smoker': 'غير مدخن',
                                    'occasional': 'أحياناً',
                                    'smoker': 'مدخن',
                                  },
                                  selectedValue: _workingDraft.smokingStatus,
                                  onChanged: (val) => setState(() {
                                    _workingDraft = _workingDraft.copyWith(
                                      smokingStatus: val,
                                    );
                                  }),
                                ),
                                const SizedBox(height: 14),

                                const _FieldLabel('حالة السكن / المنزل'),
                                NaseebakSegmentedControl<String>(
                                  options: const {
                                    'owned': 'تمليك',
                                    'rented': 'إيجار',
                                    'family_home': 'مع الأسرة',
                                  },
                                  selectedValue: _workingDraft.homeOwnership,
                                  onChanged: (val) => setState(() {
                                    _workingDraft = _workingDraft.copyWith(
                                      homeOwnership: val,
                                    );
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Location Card
                            _FormSectionContainer(
                              title: 'الإقامة والجنسية',
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const _FieldLabel('الجنسية'),
                                          TextField(
                                            controller: _nationalityController,
                                            onChanged: (val) => setState(() {
                                              _workingDraft =
                                                  _workingDraft.copyWith(
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const _FieldLabel('بلد الإقامة'),
                                          TextField(
                                            controller: _countryController,
                                            onChanged: (val) => setState(() {
                                              _workingDraft =
                                                  _workingDraft.copyWith(
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
                                    _workingDraft =
                                        _workingDraft.copyWith(region: val);
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Hobbies Card
                            _FormSectionContainer(
                              title: 'الهوايات والاهتمامات',
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _availableHobbies.map((hobby) {
                                    final isSelected =
                                        _workingDraft.hobbies.contains(hobby);
                                    return FilterChip(
                                      label: Text(hobby),
                                      selected: isSelected,
                                      selectedColor: NaseebakColors.accentGoldMuted
                                          .withOpacity(0.4),
                                      checkmarkColor:
                                          NaseebakColors.accentGoldDark,
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? NaseebakColors.primaryNavyDark
                                            : NaseebakColors.textDarkNavy,
                                      ),
                                      onSelected: (selected) {
                                        final updated = List<String>.from(
                                          _workingDraft.hobbies,
                                        );
                                        if (selected) {
                                          updated.add(hobby);
                                        } else {
                                          updated.remove(hobby);
                                        }
                                        setState(() {
                                          _workingDraft = _workingDraft
                                              .copyWith(hobbies: updated);
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Biography Card
                            _FormSectionContainer(
                              title: 'النبذة الشخصية (اختياري)',
                              children: [
                                TextField(
                                  key: const Key('edit_bio_input'),
                                  controller: _bioController,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'اكتب بصدق عن شخصيتك وتطلعاتك في شريك الحياة...',
                                  ),
                                  onChanged: (val) => setState(() {
                                    _workingDraft =
                                        _workingDraft.copyWith(bio: val);
                                  }),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Save Button Bar (UX Pilot Style)
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        border: const Border(
                          top: BorderSide(color: AppColors.subtleBorder),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        key: const Key('save_edited_profile_btn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
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
                            : const Icon(Icons.check_rounded, size: 20),
                        label: Text(
                          mgmtState.isSaving
                              ? 'جارٍ حفظ التعديلات...'
                              : 'حفظ التعديلات',
                          style: const TextStyle(
                            fontFamily: NaseebakTypography.fontFamily,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormSectionContainer extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FormSectionContainer({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: NaseebakTypography.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Divider(height: 20, color: AppColors.subtleBorder),
          ...children,
        ],
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
          fontWeight: FontWeight.w700,
          color: NaseebakColors.textDarkNavy,
        ),
      ),
    );
  }
}
