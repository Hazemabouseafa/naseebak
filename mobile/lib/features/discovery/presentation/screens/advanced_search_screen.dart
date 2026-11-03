import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../profile/presentation/widgets/step_progress_header.dart';
import '../../data/models/search_preferences_model.dart';
import '../providers/discovery_provider.dart';
import 'search_results_screen.dart';

/// 08. Advanced Search Screen (مواصفات شريك حياتك)
/// تدعم الفلاتر المطلوبة: النوع، الفئة العمرية (>= 18)، الحالة الاجتماعية (اختيار واحد أو متعدد)،
/// المؤهل الدراسي، التدخين (غير مدخن / مدخن / الكل)، المهنة، الجنسية، بلد الإقامة، والمنطقة.
/// تحفظ التفضيلات في PostgreSQL وتنفذ البحث بالكامل على الخادم.
class AdvancedSearchScreen extends ConsumerStatefulWidget {
  final bool openedFromResults;

  const AdvancedSearchScreen({
    super.key,
    this.openedFromResults = false,
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

  @override
  void initState() {
    super.initState();
    _draftFilters = ref.read(discoveryProvider).filters;
    _occupationController =
        TextEditingController(text: _draftFilters.occupation ?? '');
    _nationalityController =
        TextEditingController(text: _draftFilters.nationality ?? '');
    _countryController =
        TextEditingController(text: _draftFilters.countryOfResidence ?? '');
    _regionController =
        TextEditingController(text: _draftFilters.region ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(discoveryProvider.notifier).loadSavedPreferences();
      if (!mounted) return;
      final loaded = ref.read(discoveryProvider).filters;
      setState(() {
        _draftFilters = loaded;
        _occupationController.text = loaded.occupation ?? '';
        _nationalityController.text = loaded.nationality ?? '';
        _countryController.text = loaded.countryOfResidence ?? '';
        _regionController.text = loaded.region ?? '';
      });
    });
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
    setState(() {
      _draftFilters = const SearchPreferencesModel(
        minAge: 18,
        maxAge: 60,
      );
      _occupationController.clear();
      _nationalityController.clear();
      _countryController.clear();
      _regionController.clear();
      _localValidationError = null;
    });
    ref.read(discoveryProvider.notifier).resetFilters();
  }

  Future<void> _handleSearchSubmit() async {
    setState(() => _localValidationError = null);

    final validationError = _draftFilters.validate();
    if (validationError != null) {
      setState(() => _localValidationError = validationError);
      return;
    }

    ref.read(discoveryProvider.notifier).updateFilters(_draftFilters);
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
    final isFemaleTarget = _draftFilters.gender == 'female';

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
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'رجوع',
        ),
        title: const Text('مواصفات شريك حياتك'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_localValidationError != null)
              Container(
                margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.error.withOpacity(0.4)),
                ),
                child: Text(
                  _localValidationError!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'حدّد أولوياتك للوصول إلى نتائج أقرب لما تبحث عنه.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Gender
                    const _SearchLabel('أبحث عن'),
                    NaseebakSegmentedControl<String>(
                      options: const {
                        'male': 'ذكر',
                        'female': 'أنثى',
                      },
                      selectedValue: _draftFilters.gender ?? 'male',
                      onChanged: (val) => setState(() {
                        _draftFilters = _draftFilters.copyWith(gender: val);
                      }),
                    ),
                    const SizedBox(height: 18),

                    // 2. Age Range (>= 18 and minAge <= maxAge)
                    const _SearchLabel('الفئة العمرية (18 سنة فأكثر)'),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'من ${_draftFilters.minAge} إلى ${_draftFilters.maxAge} سنة',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryBlue,
                            ),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 3. Marital Status (Multi-select supported)
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
                          selectedColor: AppColors.surfaceSubtleBlue,
                          checkmarkColor: AppColors.primaryBlue,
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primaryBlue
                                : AppColors.textSecondary,
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
                    const SizedBox(height: 18),

                    // 4. Educational Qualification
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
                          _draftFilters =
                              _draftFilters.copyWith(clearEducation: true);
                        } else {
                          _draftFilters =
                              _draftFilters.copyWith(educationLevel: val);
                        }
                      }),
                    ),
                    const SizedBox(height: 18),

                    // 5. Smoking Status
                    const _SearchLabel('التدخين'),
                    NaseebakSegmentedControl<String>(
                      options: const {
                        'all': 'الكل',
                        'non_smoker': 'غير مدخن',
                        'smoker': 'مدخن',
                      },
                      selectedValue: _draftFilters.smokingStatus ?? 'all',
                      onChanged: (val) => setState(() {
                        if (val == 'all') {
                          _draftFilters =
                              _draftFilters.copyWith(clearSmoking: true);
                        } else {
                          _draftFilters =
                              _draftFilters.copyWith(smokingStatus: val);
                        }
                      }),
                    ),
                    const SizedBox(height: 18),

                    // 6. Occupation
                    const _SearchLabel('المهنة / العمل'),
                    TextField(
                      key: const Key('search_occupation_input'),
                      controller: _occupationController,
                      decoration: const InputDecoration(
                        hintText: 'أي مهنة (مثال: مهندس، طبيب، محاسب...)',
                      ),
                      onChanged: (val) => setState(() {
                        _draftFilters = _draftFilters.copyWith(occupation: val);
                      }),
                    ),
                    const SizedBox(height: 18),

                    // 7. Optional Nationality, Country of Residence, Region
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SearchLabel('الجنسية · اختياري'),
                              TextField(
                                key: const Key('search_nationality_input'),
                                controller: _nationalityController,
                                decoration: const InputDecoration(
                                  hintText: 'الكل (مثال: مصري)',
                                ),
                                onChanged: (val) => setState(() {
                                  _draftFilters = _draftFilters.copyWith(
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
                              const _SearchLabel('بلد الإقامة · اختياري'),
                              TextField(
                                key: const Key('search_country_input'),
                                controller: _countryController,
                                decoration: const InputDecoration(
                                  hintText: 'الكل (مثال: مصر)',
                                ),
                                onChanged: (val) => setState(() {
                                  _draftFilters = _draftFilters.copyWith(
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

                    const _SearchLabel('المحافظة / المنطقة · اختياري'),
                    TextField(
                      key: const Key('search_region_input'),
                      controller: _regionController,
                      decoration: const InputDecoration(
                        hintText: 'الكل (مثال: القاهرة، الجيزة، الإسكندرية...)',
                      ),
                      onChanged: (val) => setState(() {
                        _draftFilters = _draftFilters.copyWith(region: val);
                      }),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Primary & Secondary Action Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: const BoxDecoration(
                color: AppColors.backgroundPrimary,
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      key: const Key('search_reset_btn'),
                      onPressed:
                          discoveryState.isSearchingInitial ? null : _handleReset,
                      child: const Text('إعادة تعيين'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: ElevatedButton.icon(
                      key: const Key('search_submit_btn'),
                      onPressed: discoveryState.isSearchingInitial
                          ? null
                          : _handleSearchSubmit,
                      icon: discoveryState.isSearchingInitial
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search_rounded, size: 19),
                      label: const Text('عرض النتائج'),
                    ),
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
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
