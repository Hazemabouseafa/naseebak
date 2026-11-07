import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../theme/app_theme.dart';

class CountryLocationEntry {
  final String country;
  final String flag;
  final String nationalityMale;
  final String nationalityFemale;
  final List<String> cities;

  const CountryLocationEntry({
    required this.country,
    required this.flag,
    required this.nationalityMale,
    required this.nationalityFemale,
    required this.cities,
  });
}

/// قاعدة البيانات الموحدة للدول والجنسيات والمحافظات/المدن في تطبيق نَصِيبُكَ
/// تمنع الإدخال النصي العشوائي وتضمن توحيد أسماء الدول والمدن والجنسيات في التسجيل والبحث
class ArabicLocationsData {
  ArabicLocationsData._();

  static const List<CountryLocationEntry> entries = [
    // الدول العربية (مرتبة حسب الأكثر استخداماً)
    CountryLocationEntry(
      country: 'مصر',
      flag: '🇪🇬',
      nationalityMale: 'مصري',
      nationalityFemale: 'مصرية',
      cities: [
        'القاهرة',
        'الجيزة',
        'الإسكندرية',
        'الدقهلية',
        'الشرقية',
        'القليوبية',
        'الغربية',
        'المنوفية',
        'البحيرة',
        'كفر الشيخ',
        'دمياط',
        'بورسعيد',
        'الإسماعيلية',
        'السويس',
        'الفيوم',
        'بني سويف',
        'المنيا',
        'أسيوط',
        'سوهاج',
        'قنا',
        'الأقصر',
        'أسوان',
        'البحر الأحمر',
        'مطروح',
        'الوادي الجديد',
        'شمال سيناء',
        'جنوب سيناء',
      ],
    ),
    CountryLocationEntry(
      country: 'المملكة العربية السعودية',
      flag: '🇸🇦',
      nationalityMale: 'سعودي',
      nationalityFemale: 'سعودية',
      cities: [
        'الرياض',
        'جدة',
        'مكة المكرمة',
        'المدينة المنورة',
        'الدمام',
        'الخبر',
        'الظهران',
        'الطائف',
        'تبوك',
        'بريدة (القصيم)',
        'أبها',
        'خميس مشيط',
        'حائل',
        'جازان',
        'نجران',
        'الأحساء',
        'ينبع',
        'الجبيل',
        'الباحة',
        'الجوف',
        'عرعر',
      ],
    ),
    CountryLocationEntry(
      country: 'الإمارات العربية المتحدة',
      flag: '🇦🇪',
      nationalityMale: 'إماراتي',
      nationalityFemale: 'إماراتية',
      cities: [
        'دبي',
        'أبوظبي',
        'الشارقة',
        'عجمان',
        'رأس الخيمة',
        'الفجيرة',
        'أم القيوين',
        'العين',
      ],
    ),
    CountryLocationEntry(
      country: 'الكويت',
      flag: '🇰🇼',
      nationalityMale: 'كويتي',
      nationalityFemale: 'كويتية',
      cities: [
        'مدينة الكويت',
        'حولي',
        'الفروانية',
        'الأحمدي',
        'الجهراء',
        'مبارك الكبير',
      ],
    ),
    CountryLocationEntry(
      country: 'قطر',
      flag: '🇶🇦',
      nationalityMale: 'قطري',
      nationalityFemale: 'قطرية',
      cities: [
        'الدوحة',
        'الريان',
        'الوكرة',
        'الخور',
        'أم صلال',
        'الشمال',
        'الظعاين',
      ],
    ),
    CountryLocationEntry(
      country: 'البحرين',
      flag: '🇧🇭',
      nationalityMale: 'بحريني',
      nationalityFemale: 'بحرينية',
      cities: [
        'المنامة',
        'المحرق',
        'الرفاع',
        'مدينة حمد',
        'مدينة عيسى',
        'سترة',
      ],
    ),
    CountryLocationEntry(
      country: 'سلطنة عمان',
      flag: '🇴🇲',
      nationalityMale: 'عماني',
      nationalityFemale: 'عمانية',
      cities: [
        'مسقط',
        'صلالة',
        'صحار',
        'نزوى',
        'صور',
        'البريمي',
        'عبري',
        'الرستاق',
      ],
    ),
    CountryLocationEntry(
      country: 'الأردن',
      flag: '🇯🇴',
      nationalityMale: 'أردني',
      nationalityFemale: 'أردنية',
      cities: [
        'عمّان',
        'إربد',
        'الزرقاء',
        'العقبة',
        'السلط',
        'المفرق',
        'جرش',
        'مادبا',
        'الكرك',
        'معان',
        'عجلون',
        'الطفيلة',
      ],
    ),
    CountryLocationEntry(
      country: 'فلسطين',
      flag: '🇵🇸',
      nationalityMale: 'فلسطيني',
      nationalityFemale: 'فلسطينية',
      cities: [
        'القدس',
        'رام الله',
        'غزة',
        'نابلس',
        'الخليل',
        'بيت لحم',
        'جنين',
        'طولكرم',
        'قلقيلية',
        'أريحا',
        'خان يونس',
        'رفح',
      ],
    ),
    CountryLocationEntry(
      country: 'لبنان',
      flag: '🇱🇧',
      nationalityMale: 'لبناني',
      nationalityFemale: 'لبنانية',
      cities: [
        'بيروت',
        'طرابلس',
        'صيدا',
        'صور',
        'جبل لبنان',
        'زحلة',
        'بعلبك',
        'النبطية',
        'جبيل',
      ],
    ),
    CountryLocationEntry(
      country: 'سوريا',
      flag: '🇸🇾',
      nationalityMale: 'سوري',
      nationalityFemale: 'سورية',
      cities: [
        'دمشق',
        'ريف دمشق',
        'حلب',
        'حمص',
        'حماة',
        'اللاذقية',
        'طرطوس',
        'إدلب',
        'درعا',
        'دير الزور',
        'الحسكة',
        'السويداء',
      ],
    ),
    CountryLocationEntry(
      country: 'العراق',
      flag: '🇮🇶',
      nationalityMale: 'عراقي',
      nationalityFemale: 'عراقية',
      cities: [
        'بغداد',
        'البصرة',
        'نينوى (الموصل)',
        'أربيل',
        'السليمانية',
        'دهوك',
        'النجف',
        'كربلاء',
        'كركوك',
        'الأنبار',
        'بابل',
        'ديالى',
        'ذي قار',
        'واسط',
      ],
    ),
    CountryLocationEntry(
      country: 'السودان',
      flag: '🇸🇩',
      nationalityMale: 'سوداني',
      nationalityFemale: 'سودانية',
      cities: [
        'الخرطوم',
        'أم درمان',
        'الخرطوم بحري',
        'بورتسودان',
        'ود مدني',
        'عطبرة',
        'الأبيض',
        'كسلا',
        'دنقلا',
      ],
    ),
    CountryLocationEntry(
      country: 'اليمن',
      flag: '🇾🇪',
      nationalityMale: 'يمني',
      nationalityFemale: 'يمنية',
      cities: [
        'صنعاء',
        'عدن',
        'تعز',
        'حضرموت (المكلا)',
        'الحديدة',
        'إب',
        'ذمار',
        'مأرب',
      ],
    ),
    CountryLocationEntry(
      country: 'ليبيا',
      flag: '🇱🇾',
      nationalityMale: 'ليبي',
      nationalityFemale: 'ليبية',
      cities: [
        'طرابلس',
        'بنغازي',
        'مصراتة',
        'الزاوية',
        'البيضاء',
        'طبرق',
        'سبها',
        'زليتن',
      ],
    ),
    CountryLocationEntry(
      country: 'تونس',
      flag: '🇹🇳',
      nationalityMale: 'تونسي',
      nationalityFemale: 'تونسية',
      cities: [
        'تونس العاصمة',
        'صفاقس',
        'سوسة',
        'القيروان',
        'بنزرت',
        'قابس',
        'أريانة',
        'المنستير',
        'نابل',
      ],
    ),
    CountryLocationEntry(
      country: 'الجزائر',
      flag: '🇩🇿',
      nationalityMale: 'جزائري',
      nationalityFemale: 'جزائرية',
      cities: [
        'الجزائر العاصمة',
        'وهران',
        'قسنطينة',
        'عنابة',
        'البليدة',
        'سطيف',
        'باتنة',
        'تلمسان',
        'بجاية',
        'بسكرة',
      ],
    ),
    CountryLocationEntry(
      country: 'المغرب',
      flag: '🇲🇦',
      nationalityMale: 'مغربي',
      nationalityFemale: 'مغربية',
      cities: [
        'الدار البيضاء',
        'الرباط',
        'مراكش',
        'فاس',
        'طنجة',
        'أغادير',
        'مكناس',
        'وجدة',
        'القنيطرة',
        'تطوان',
      ],
    ),
    CountryLocationEntry(
      country: 'موريتانيا',
      flag: '🇲🇷',
      nationalityMale: 'موريتاني',
      nationalityFemale: 'موريتانية',
      cities: ['نواكشوط', 'نواذيبو', 'كيفه', 'روصو'],
    ),
    CountryLocationEntry(
      country: 'الصومال',
      flag: '🇸🇴',
      nationalityMale: 'صومالي',
      nationalityFemale: 'صومالية',
      cities: ['مقديشو', 'هرجيسا', 'بوصاصو', 'كسمايو'],
    ),
    CountryLocationEntry(
      country: 'جيبوتي',
      flag: '🇩🇯',
      nationalityMale: 'جيبوتي',
      nationalityFemale: 'جيبوتية',
      cities: ['مدينة جيبوتي', 'علي صبيح', 'تاجورة'],
    ),
    CountryLocationEntry(
      country: 'جزر القمر',
      flag: '🇰🇲',
      nationalityMale: 'قمري',
      nationalityFemale: 'قمرية',
      cities: ['موروني', 'موتسامودو', 'فومبوني'],
    ),

    // دول العالم (تركيا، أوروبا، أمريكا، كندا، آسيا، أستراليا)
    CountryLocationEntry(
      country: 'تركيا',
      flag: '🇹🇷',
      nationalityMale: 'تركي',
      nationalityFemale: 'تركية',
      cities: ['إسطنبول', 'أنقرة', 'إزمير', 'بورصة', 'أنطاليا', 'غازي عنتاب', 'قونية'],
    ),
    CountryLocationEntry(
      country: 'ألمانيا',
      flag: '🇩🇪',
      nationalityMale: 'ألماني',
      nationalityFemale: 'ألمانية',
      cities: ['برلين', 'ميونخ', 'فرانكفورت', 'هامبورغ', 'كولونيا', 'دوسلدورف', 'شتوتغارت'],
    ),
    CountryLocationEntry(
      country: 'المملكة المتحدة',
      flag: '🇬🇧',
      nationalityMale: 'بريطاني',
      nationalityFemale: 'بريطانية',
      cities: ['لندن', 'مانشستر', 'برمنغهام', 'ليفربول', 'ليدز', 'إدنبرة', 'غلاسكو'],
    ),
    CountryLocationEntry(
      country: 'فرنسا',
      flag: '🇫🇷',
      nationalityMale: 'فرنسي',
      nationalityFemale: 'فرنسية',
      cities: ['باريس', 'مارسيليا', 'ليون', 'تولوز', 'نيس', 'ستراسبورغ'],
    ),
    CountryLocationEntry(
      country: 'إيطاليا',
      flag: '🇮🇹',
      nationalityMale: 'إيطالي',
      nationalityFemale: 'إيطالية',
      cities: ['روما', 'ميلانو', 'نابولي', 'تورينو', 'فلورنسا', 'بولونيا'],
    ),
    CountryLocationEntry(
      country: 'إسبانيا',
      flag: '🇪🇸',
      nationalityMale: 'إسباني',
      nationalityFemale: 'إسبانية',
      cities: ['مدريد', 'برشلونة', 'فالنسيا', 'إشبيلية', 'ملقا'],
    ),
    CountryLocationEntry(
      country: 'هولندا',
      flag: '🇳🇱',
      nationalityMale: 'هولندي',
      nationalityFemale: 'هولندية',
      cities: ['أمستردام', 'روتردام', 'لاهاي', 'أوتريخت', 'أيندهوفن'],
    ),
    CountryLocationEntry(
      country: 'السويد',
      flag: '🇸🇪',
      nationalityMale: 'سويدي',
      nationalityFemale: 'سويدية',
      cities: ['ستوكهولم', 'غوتنبرغ', 'مالمو', 'أوبسالا'],
    ),
    CountryLocationEntry(
      country: 'النمسا',
      flag: '🇦🇹',
      nationalityMale: 'نمساوي',
      nationalityFemale: 'نمساوية',
      cities: ['فيينا', 'غراتس', 'لينتس', 'سالزبورغ'],
    ),
    CountryLocationEntry(
      country: 'سويسرا',
      flag: '🇨🇭',
      nationalityMale: 'سويسري',
      nationalityFemale: 'سويسرية',
      cities: ['زيورخ', 'جنيف', 'بازل', 'برن'],
    ),
    CountryLocationEntry(
      country: 'بلجيكا',
      flag: '🇧🇪',
      nationalityMale: 'بلجيكي',
      nationalityFemale: 'بلجيكية',
      cities: ['بروكسل', 'أنتويرب', 'غنت', 'لييج'],
    ),
    CountryLocationEntry(
      country: 'الولايات المتحدة الأمريكية',
      flag: '🇺🇸',
      nationalityMale: 'أمريكي',
      nationalityFemale: 'أمريكية',
      cities: [
        'نيويورك',
        'لوس أنجلوس',
        'شيكاغو',
        'هيوستن',
        'واشنطن',
        'ميشيغان (ديربورن)',
        'نيوجيرسي',
        'تكساس',
        'فلوريدا',
        'كاليفورنيا',
      ],
    ),
    CountryLocationEntry(
      country: 'كندا',
      flag: '🇨🇦',
      nationalityMale: 'كندي',
      nationalityFemale: 'كندية',
      cities: ['تورونتو', 'مونتريال', 'أوتاوا', 'فانكوفر', 'كالغاري', 'ميسيساغا'],
    ),
    CountryLocationEntry(
      country: 'أستراليا',
      flag: '🇦🇺',
      nationalityMale: 'أسترالي',
      nationalityFemale: 'أسترالية',
      cities: ['سيدني', 'ملبورن', 'بريزبن', 'بيرث', 'أديلايد'],
    ),
    CountryLocationEntry(
      country: 'ماليزيا',
      flag: '🇲🇾',
      nationalityMale: 'ماليزي',
      nationalityFemale: 'ماليزية',
      cities: ['كوالالمبور', 'سيلانجور', 'بينانج', 'جوهور باهرو'],
    ),
    CountryLocationEntry(
      country: 'إندونيسيا',
      flag: '🇮🇩',
      nationalityMale: 'إندونيسي',
      nationalityFemale: 'إندونيسية',
      cities: ['جاكرتا', 'باندونغ', 'سورابايا', 'بالي'],
    ),
    CountryLocationEntry(
      country: 'باكستان',
      flag: '🇵🇰',
      nationalityMale: 'باكستاني',
      nationalityFemale: 'باكستانية',
      cities: ['إسلام آباد', 'كراتشي', 'لاهور'],
    ),
    CountryLocationEntry(
      country: 'الهند',
      flag: '🇮🇳',
      nationalityMale: 'هندي',
      nationalityFemale: 'هندية',
      cities: ['نيودلهي', 'مومباي', 'حيدر آباد', 'بنغالور'],
    ),
    CountryLocationEntry(
      country: 'روسيا',
      flag: '🇷🇺',
      nationalityMale: 'روسي',
      nationalityFemale: 'روسية',
      cities: ['موسكو', 'سانت بطرسبرغ', 'قازان'],
    ),
    CountryLocationEntry(
      country: 'البرازيل',
      flag: '🇧🇷',
      nationalityMale: 'برازيلي',
      nationalityFemale: 'برازيلية',
      cities: ['ساو باولو', 'ريو دي جانيرو', 'برازيليا'],
    ),
  ];

  /// قائمة جميع الدول المعتمدة
  static List<String> get allCountries =>
      entries.map((e) => e.country).toList(growable: false);

  /// قائمة الجنسيات حسب الجنس (أو شاملة للبحث)
  static List<String> nationalitiesForGender(String? gender, {bool includeBoth = false}) {
    final result = <String>[];
    for (final entry in entries) {
      if (includeBoth) {
        if (!result.contains(entry.nationalityMale)) {
          result.add(entry.nationalityMale);
        }
        if (!result.contains(entry.nationalityFemale)) {
          result.add(entry.nationalityFemale);
        }
      } else if (gender == 'female') {
        result.add(entry.nationalityFemale);
      } else {
        result.add(entry.nationalityMale);
      }
    }
    return result;
  }

  /// قائمة المدن / المحافظات التابعة لدولة محددة (أو كافة المدن الرئيسية إذا لم تحدد الدولة)
  static List<String> citiesForCountry(String? country) {
    final trimmed = (country ?? '').trim();
    if (trimmed.isNotEmpty) {
      for (final entry in entries) {
        if (entry.country == trimmed ||
            (trimmed == 'السعودية' &&
                entry.country == 'المملكة العربية السعودية') ||
            (trimmed == 'الإمارات' &&
                entry.country == 'الإمارات العربية المتحدة')) {
          return entry.cities;
        }
      }
    }

    // في حالة عدم تحديد دولة (مثلاً في البحث العام)، نعرض محافظات مصر + أبرز المدن العربية
    final all = <String>[];
    for (final entry in entries) {
      for (final city in entry.cities) {
        if (!all.contains(city)) {
          all.add(city);
        }
      }
    }
    return all;
  }

  /// استرجاع علم الدولة المقابل لاسم الدولة أو الجنسية
  static String flagFor(String value) {
    final trimmed = value.trim();
    for (final entry in entries) {
      if (entry.country == trimmed ||
          entry.nationalityMale == trimmed ||
          entry.nationalityFemale == trimmed ||
          entry.cities.contains(trimmed)) {
        return entry.flag;
      }
    }
    if (trimmed == 'السعودية') return '🇸🇦';
    if (trimmed == 'الإمارات') return '🇦🇪';
    return '🌍';
  }
}

/// حقل اختيار منسدل احترافي (Dropdown + Searchable Bottom Sheet) للجنسية والدولة والمحافظة
/// يمنع الكتابة اليدوية العشوائية ويوفر تجربة اختيار سريعة وأنيقة
class NaseebakLocationDropdownField extends StatelessWidget {
  final Key? fieldKey;
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final bool allowAllOption;
  final String allOptionLabel;
  final IconData leadingIcon;

  const NaseebakLocationDropdownField({
    super.key,
    this.fieldKey,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.placeholder = 'اختر من القائمة',
    this.allowAllOption = false,
    this.allOptionLabel = 'الكل',
    this.leadingIcon = Icons.public_rounded,
  });

  void _openPickerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return _SearchableLocationPickerSheet(
          title: label,
          selectedValue: value,
          options: options,
          allowAllOption: allowAllOption,
          allOptionLabel: allOptionLabel,
          onSelect: (chosen) {
            Navigator.of(sheetCtx).pop();
            onChanged(chosen);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmedValue = value.trim();
    final hasSelection = trimmedValue.isNotEmpty;
    final displayValue = hasSelection
        ? trimmedValue
        : (allowAllOption ? allOptionLabel : placeholder);
    final flag = hasSelection ? ArabicLocationsData.flagFor(trimmedValue) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
        ],
        InkWell(
          key: fieldKey,
          onTap: () => _openPickerSheet(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.softBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasSelection
                    ? AppColors.primaryBlue.withOpacity(0.35)
                    : AppColors.subtleBorder,
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                if (flag != null && flag != '🌍') ...[
                  Text(flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                ] else ...[
                  Icon(
                    leadingIcon,
                    size: 18,
                    color: hasSelection
                        ? AppColors.primaryBlue
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    displayValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight:
                          hasSelection ? FontWeight.w600 : FontWeight.w500,
                      color: hasSelection
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchableLocationPickerSheet extends StatefulWidget {
  final String title;
  final String selectedValue;
  final List<String> options;
  final bool allowAllOption;
  final String allOptionLabel;
  final ValueChanged<String> onSelect;

  const _SearchableLocationPickerSheet({
    required this.title,
    required this.selectedValue,
    required this.options,
    required this.allowAllOption,
    required this.allOptionLabel,
    required this.onSelect,
  });

  @override
  State<_SearchableLocationPickerSheet> createState() =>
      _SearchableLocationPickerSheetState();
}

class _SearchableLocationPickerSheetState
    extends State<_SearchableLocationPickerSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final q = _searchQuery.trim();
    final filtered = q.isEmpty
        ? widget.options
        : widget.options.where((item) => item.contains(q)).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.subtleBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'ابحث في القائمة...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  filled: true,
                  fillColor: AppColors.softBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.subtleBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.subtleBorder),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.subtleBorder),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                itemCount: filtered.length + (widget.allowAllOption && q.isEmpty ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  if (widget.allowAllOption && q.isEmpty && index == 0) {
                    final isAllSelected = widget.selectedValue.trim().isEmpty;
                    return InkWell(
                      onTap: () => widget.onSelect(''),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: isAllSelected
                              ? AppColors.surfaceSubtleBlue
                              : AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isAllSelected
                                ? AppColors.primaryBlue
                                : AppColors.subtleBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.public_rounded,
                              size: 20,
                              color: AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.allOptionLabel,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 15,
                                  fontWeight: isAllSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isAllSelected
                                      ? AppColors.primaryBlue
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isAllSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primaryBlue,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  }

                  final itemIndex =
                      widget.allowAllOption && q.isEmpty ? index - 1 : index;
                  final option = filtered[itemIndex];
                  final isSelected = widget.selectedValue.trim() == option;
                  final flag = ArabicLocationsData.flagFor(option);

                  return InkWell(
                    onTap: () => widget.onSelect(option),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.surfaceSubtleBlue
                            : AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryBlue
                              : AppColors.subtleBorder.withOpacity(0.7),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(flag, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primaryBlue,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
