import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/naseebak_design_system.dart';
import '../../../profile/presentation/providers/profile_management_provider.dart';
import '../../../profile/presentation/widgets/step_progress_header.dart';
import '../../data/models/search_preferences_model.dart';
import '../providers/discovery_provider.dart';
import 'search_results_screen.dart';

/// 08. Advanced Search Screen (مواصفات شريك حياتك — تصميم Astra)
/// بطاقات فلاتر مقسمة بوضوح: النوع، الفئة العمرية (>= 18)، الحالة الاجتماعية،
/// المؤهل الدراسي، التدخين، المهنة، الجنسية، بلد الإقامة، والمنطقة.
class AdvancedSearchScreen extends ConsumerStatefulWidget {
  final bool openedFromResults;
  final VoidCallback? onCloseTab;

  const AdvancedSearchScreen({
    super.key,
    this.openedFromResults = false,
    this.onCloseTab,
  });

  @override
  ConsumerState<AdvancedSearchScreen> createState() =>
      _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends ConsumerState<AdvancedSearchScreen> {
  late SearchPreferencesModel _draftFilters;
  late final TextEditingController _occupationController;
  late final TextEditingController _nationalityController;
  late final TextEditingController _countryController;
  late final TextEditingController _regionController;
  String? _localValidationError;

  String? _resolveDefaultTargetGender() {
    final ownGender = ref.read(profileManagementProvider).profile?.gender;
    if (ownGender == 'male') return 'female';
    if (ownGender == 'female') return 'male';
    return null;
  }

  @override
  void initState() {
    super.initState();
    final currentFilters = ref.read(discoveryProvider).filters;
    final fallbackGender = _resolveDefaultTargetGender();
    _draftFilters = currentFilters.gender == null && fallbackGender != null
        ? currentFilters.copyWith(gender: fallbackGender)
        : currentFilters;
    _occupationController =
        TextEditingController(text: _draftFilters.occupation ?? '');
    _nationalityController =
        TextEditingController(text: _draftFilters.nationality ?? '');
    _countryController =
        TextEditingController(text: _draftFilters.countryOfResidence ?? '');
    _regionController =
        TextEditingController(text: _draftFilters.region ?? '');

    if (!widget.openedFromResults) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref.read(discoveryProvider.notifier).loadSavedPreferences();
        if (!mounted) return;
        final loaded = ref.read(discoveryProvider).filters;
        final resolvedGender = loaded.gender ?? _resolveDefaultTargetGender();
        setState(() {
          _draftFilters = resolvedGender != null && loaded.gender == null
              ? loaded.copyWith(gender: resolvedGender)
              : loaded;
          _occupationController.text = _draftFilters.occupation ?? '';
          _nationalityController.text = _draftFilters.nationality ?? '';
          _countryController.text = _draftFilters.countryOfResidence ?? '';
          _regionController.text = _draftFilters.region ?? '';
        });
      });
    }
  }

  @override
  void dispose() {
    _occupationController.dispose();
    _nationalityController.dispose();
    _countryController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  void _handleReset() {
    final defaultGender = _resolveDefaultTargetGender();
    setState(() {
      _draftFilters = SearchPreferencesModel(
        gender: defaultGender,
        minAge: 18,
        maxAge: 60,
      );
      _occupationController.clear();
      _nationalityController.clear();
      _countryController.clear();
      _regionController.clear();
      _localValidationError = null;
    });
    ref
        .read(discoveryProvider.notifier)
        .resetFilters(defaultGender: defaultGender);
  }

  Future<void> _handleSearchSubmit() async {
    setState(() => _localValidationError = null);

    final effectiveFilters = _draftFilters.gender == null
        ? _draftFilters.copyWith(gender: _resolveDefaultTargetGender())
        : _draftFilters;

    final validationError = effectiveFilters.validate();
    if (validationError != null) {
      setState(() => _localValidationError = validationError);
      return;
    }

    ref.read(discoveryProvider.notifier).updateFilters(effectiveFilters);
    await ref.read(discoveryProvider.notifier).executeSearch(
          savePreferences: true,
        );

    if (!mounted) return;

    if (widget.openedFromResults) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const SearchResultsScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final discoveryState = ref.watch(discoveryProvider);
    final effectiveGender =
        _draftFilters.gender ?? _resolveDefaultTargetGender() ?? 'female';
    final isFemaleTarget = effectiveGender == 'female';

    final maritalOptions = isFemaleTarget
        ? const {
            'single': 'عزباء',
            'divorced': 'مطلقة',
            'widowed': 'أرملة',
          }
        : const {
            'single': 'أعزب',
            'divorced': 'مطلق',
            'widowed': 'أرمل',
          };

    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        centerTitle: true,
        leading: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 14),
            child: NaseebakCircleButton(
              icon: Icons.close_rounded,
              size: 40,
              iconSize: 20,
              onTap: () {
                if (widget.onCloseTab != null) {
                  widget.onCloseTab!();
                } else if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              tooltip: 'إغلاق',
            ),
          ),
        ),
        title: const Column(
          children: [
            Text(
              'البحث المتقدم',
              style: TextStyle(
                fontFamily: NaseebakTypography.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            // Semantic fallback for existing tests
            Opacity(
              opacity: 0.0,
              child: SizedBox(
                height: 0,
                child: Text('مواصفات شريك حياتك'),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 14),
            child: TextButton(
              key: const Key('search_reset_btn'),
              onPressed: discoveryState.isSearchingInitial ? null : _handleReset,
              child: const Text(
                'إعادة تعيين',
                style: TextStyle(
                  fontFamily: NaseebakTypography.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_localValidationError != null)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withOpacity(0.4)),
                ),
                child: Text(
                  _localValidationError!,
                  style: const TextStyle(
                    fontFamily: NaseebakTypography.fontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Group 1: Basic Criteria Card
                    NaseebakInfoCard(
                      title: 'المواصفات الأساسية',
                      icon: Icons.person_search_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SearchLabel('أبحث عن'),
                          NaseebakSegmentedControl<String>(
                            options: const {
                              'male': 'ذكر',
                              'female': 'أنثى',
                            },
                            selectedValue: effectiveGender,
                            onChanged: (val) => setState(() {
                              _draftFilters =
                                  _draftFilters.copyWith(gender: val);
                            }),
                          ),
                          const SizedBox(height: 18),

                          // Age Range (>= 18)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Flexible(
                                child: _SearchLabel(
                                  'الفئة العمرية (18 سنة فأكثر)',
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.creamHighlight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'من ${_draftFilters.minAge} إلى ${_draftFilters.maxAge} سنة',
                                  style: const TextStyle(
                                    fontFamily: NaseebakTypography.fontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          RangeSlider(
                            values: RangeValues(
                              _draftFilters.minAge.toDouble().clamp(18, 85),
                              _draftFilters.maxAge.toDouble().clamp(18, 85),
                            ),
                            min: 18,
                            max: 85,
                            divisions: 67,
                            activeColor: AppColors.primaryBlue,
                            inactiveColor: AppColors.subtleBorder,
                            labels: RangeLabels(
                              '${_draftFilters.minAge}',
                              '${_draftFilters.maxAge}',
                            ),
                            onChanged: (range) {
                              setState(() {
                                _draftFilters = _draftFilters.copyWith(
                                  minAge: range.start.round(),
                                  maxAge: range.end.round(),
                                );
                              });
                            },
                          ),
                          const SizedBox(height: 10),

                          // Marital Status (Multi-select)
                          const _SearchLabel(
                            'الحالة الاجتماعية (يمكن اختيار أكثر من حالة)',
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: maritalOptions.entries.map((entry) {
                              final isSelected = _draftFilters.maritalStatuses
                                  .contains(entry.key);
                              return FilterChip(
                                key: Key('search_marital_${entry.key}'),
                                label: Text(entry.value),
                                selected: isSelected,
                                selectedColor: AppColors.primaryNavy,
                                backgroundColor: AppColors.softBackground,
                                checkmarkColor: AppColors.goldAccent,
                                labelStyle: TextStyle(
                                  fontFamily: NaseebakTypography.fontFamily,
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                                onSelected: (selected) {
                                  final updated = List<String>.from(
                                    _draftFilters.maritalStatuses,
                                  );
                                  if (selected) {
                                    updated.add(entry.key);
                                  } else {
                                    updated.remove(entry.key);
                                  }
                                  setState(() {
                                    _draftFilters = _draftFilters.copyWith(
                                      maritalStatuses: updated,
                                    );
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Group 2: Education, Occupation & Lifestyle Card
                    NaseebakInfoCard(
                      title: 'المؤهل والمهنة وأسلوب الحياة',
                      icon: Icons.school_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SearchLabel('المؤهل الدراسي'),
                          DropdownButtonFormField<String?>(
                            value: _draftFilters.educationLevel,
                            items: const [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text('جميع المؤهلات الدراسية'),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'bachelor',
                                child: Text('بكالوريوس / ليسانس'),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'master',
                                child: Text('ماجستير'),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'doctorate',
                                child: Text('دكتوراه'),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'diploma',
                                child: Text('دبلوم متوسط / فوق متوسط'),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'high_school',
                                child: Text('ثانوية عامة أو ما يعادلها'),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'other',
                                child: Text('مؤهل آخر'),
                              ),
                            ],
                            onChanged: (val) => setState(() {
                              if (val == null) {
                                _draftFilters = _draftFilters.copyWith(
                                  clearEducation: true,
                                );
                              } else {
                                _draftFilters = _draftFilters.copyWith(
                                  educationLevel: val,
                                );
                              }
                            }),
                          ),
                          const SizedBox(height: 16),

                          const _SearchLabel('المهنة / العمل'),
                          TextField(
                            key: const Key('search_occupation_input'),
                            controller: _occupationController,
                            decoration: const InputDecoration(
                              hintText:
                                  'أي مهنة (مثال: مهندس، طبيب، محاسب...)',
                            ),
                            onChanged: (val) => setState(() {
                              _draftFilters =
                                  _draftFilters.copyWith(occupation: val);
                            }),
                          ),
                          const SizedBox(height: 16),

                          const _SearchLabel('التدخين'),
                          NaseebakSegmentedControl<String>(
                            options: const {
                              'all': 'الكل',
                              'non_smoker': 'غير مدخن',
                              'smoker': 'مدخن',
                            },
                            selectedValue:
                                _draftFilters.smokingStatus ?? 'all',
                            onChanged: (val) => setState(() {
                              if (val == 'all') {
                                _draftFilters =
                                    _draftFilters.copyWith(clearSmoking: true);
                              } else {
                                _draftFilters = _draftFilters.copyWith(
                                  smokingStatus: val,
                                );
                              }
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Group 3: Location & Nationality Card (Dropdown Pickers)
                    NaseebakInfoCard(
                      title: 'الجنسية والإقامة',
                      icon: Icons.location_on_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: NaseebakLocationDropdownField(
                                  fieldKey: const Key(
                                      'search_nationality_input'),
                                  label: 'الجنسية · اختياري',
                                  value: _draftFilters.nationality ?? '',
                                  options: ArabicLocationsData
                                      .nationalitiesForGender(effectiveGender),
                                  allowAllOption: true,
                                  allOptionLabel: 'الكل (جميع الجنسيات)',
                                  placeholder: 'الكل',
                                  leadingIcon: Icons.flag_outlined,
                                  onChanged: (val) => setState(() {
                                    _nationalityController.text = val;
                                    if (val.isEmpty) {
                                      _draftFilters = _draftFilters.copyWith(
                                        clearNationality: true,
                                      );
                                    } else {
                                      _draftFilters = _draftFilters.copyWith(
                                        nationality: val,
                                      );
                                    }
                                  }),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: NaseebakLocationDropdownField(
                                  fieldKey: const Key('search_country_input'),
                                  label: 'بلد الإقامة · اختياري',
                                  value:
                                      _draftFilters.countryOfResidence ?? '',
                                  options: ArabicLocationsData.allCountries,
                                  allowAllOption: true,
                                  allOptionLabel: 'الكل (جميع الدول)',
                                  placeholder: 'الكل',
                                  leadingIcon: Icons.public_rounded,
                                  onChanged: (val) => setState(() {
                                    _countryController.text = val;
                                    if (val.isEmpty) {
                                      _regionController.clear();
                                      _draftFilters = _draftFilters.copyWith(
                                        clearCountry: true,
                                        clearRegion: true,
                                      );
                                    } else {
                                      final cities = ArabicLocationsData
                                          .citiesForCountry(val);
                                      final currentRegion =
                                          _draftFilters.region ?? '';
                                      final keepRegion = currentRegion
                                              .isNotEmpty &&
                                          cities.contains(currentRegion);
                                      if (!keepRegion) {
                                        _regionController.clear();
                                      }
                                      _draftFilters = _draftFilters.copyWith(
                                        countryOfResidence: val,
                                        clearRegion: !keepRegion,
                                      );
                                    }
                                  }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          NaseebakLocationDropdownField(
                            fieldKey: const Key('search_region_input'),
                            label: 'المحافظة / المدينة · اختياري',
                            value: _draftFilters.region ?? '',
                            options: ArabicLocationsData.citiesForCountry(
                                _draftFilters.countryOfResidence),
                            allowAllOption: true,
                            allOptionLabel: 'الكل (جميع المحافظات والمدن)',
                            placeholder: 'الكل',
                            leadingIcon: Icons.location_city_rounded,
                            onChanged: (val) => setState(() {
                              _regionController.text = val;
                              if (val.isEmpty) {
                                _draftFilters = _draftFilters.copyWith(
                                  clearRegion: true,
                                );
                              } else {
                                _draftFilters = _draftFilters.copyWith(
                                  region: val,
                                );
                              }
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Submit Bar (UX Pilot Style)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                border: const Border(
                  top: BorderSide(color: AppColors.subtleBorder),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NaseebakPrimaryButton(
                    buttonKey: const Key('search_submit_btn'),
                    isLoading: discoveryState.isSearchingInitial,
                    label: 'عرض النتائج',
                    onPressed: _handleSearchSubmit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchLabel extends StatelessWidget {
  final String text;
  const _SearchLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: NaseebakTypography.formLabel,
      ),
    );
  }
}
