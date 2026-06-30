import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WaCategory {
  final String id, label, labelEn, emoji;
  final List<WaSubCategory> subs;
  const WaCategory({
    required this.id,
    required this.label,
    required this.labelEn,
    required this.emoji,
    required this.subs,
  });
  Color get color => WaColors.catColor(id);

  /// Returns the label based on locale language code
  String localizedLabel(String langCode) => langCode == 'en' ? labelEn : label;
}

class WaSubCategory {
  final String emoji, label, labelEn;
  const WaSubCategory(this.emoji, this.label, [this.labelEn = '']);

  String localizedLabel(String langCode) =>
      langCode == 'en' && labelEn.isNotEmpty ? labelEn : label;
}

const kExpenseCategories = <WaCategory>[
  WaCategory(id:'food',          label:'طعام',      labelEn:'Food',           emoji:'🍽️', subs:[
    WaSubCategory('🍽️','مطاعم',       'Restaurants'),
    WaSubCategory('🛒','بقالة',         'Grocery'),
    WaSubCategory('☕','مقاهي',         'Cafes'),
    WaSubCategory('🥐','مخابز',         'Bakeries'),
    WaSubCategory('🛵','توصيل',         'Delivery'),
    WaSubCategory('🍱','أخرى',          'Other'),
  ]),
  WaCategory(id:'transport',     label:'مواصلات',   labelEn:'Transport',      emoji:'🚗', subs:[
    WaSubCategory('⛽','وقود',           'Fuel'),
    WaSubCategory('🚕','تاكسي',         'Taxi'),
    WaSubCategory('🔧','صيانة',         'Maintenance'),
    WaSubCategory('📋','تأمين',         'Insurance'),
    WaSubCategory('🚌','نقل عام',       'Public Transport'),
    WaSubCategory('✈️','سفر',           'Travel'),
  ]),
  WaCategory(id:'health',        label:'صحة',       labelEn:'Health',         emoji:'❤️', subs:[
    WaSubCategory('💊','أدوية',         'Medicines'),
    WaSubCategory('🏥','طبيب',          'Doctor'),
    WaSubCategory('🏋️','رياضة',        'Gym'),
    WaSubCategory('💉','صيدلية',        'Pharmacy'),
    WaSubCategory('🪥','عناية',         'Personal Care'),
    WaSubCategory('🦷','أسنان',         'Dental'),
  ]),
  WaCategory(id:'bills',         label:'فواتير',    labelEn:'Bills',          emoji:'🏠', subs:[
    WaSubCategory('🏠','إيجار',         'Rent'),
    WaSubCategory('💡','كهرباء/ماء',    'Electricity/Water'),
    WaSubCategory('📶','إنترنت',        'Internet'),
    WaSubCategory('📱','هاتف',          'Phone'),
    WaSubCategory('🔨','صيانة منزل',   'Home Maintenance'),
    WaSubCategory('🔐','تأمين منزل',   'Home Insurance'),
  ]),
  WaCategory(id:'entertainment', label:'ترفيه',     labelEn:'Entertainment',  emoji:'🎬', subs:[
    WaSubCategory('🎬','سينما',         'Cinema'),
    WaSubCategory('📺','اشتراكات',      'Subscriptions'),
    WaSubCategory('🎮','ألعاب',         'Games'),
    WaSubCategory('🏖️','سياحة',        'Tourism'),
    WaSubCategory('📚','كتب',           'Books'),
    WaSubCategory('⚽','رياضة',         'Sports'),
  ]),
  WaCategory(id:'shopping',      label:'تسوق',      labelEn:'Shopping',       emoji:'🛍️', subs:[
    WaSubCategory('👔','ملابس',         'Clothes'),
    WaSubCategory('👟','أحذية',         'Shoes'),
    WaSubCategory('💻','إلكترونيات',    'Electronics'),
    WaSubCategory('🪴','أدوات منزل',   'Home Tools'),
    WaSubCategory('🎁','هدايا',         'Gifts'),
    WaSubCategory('🛍️','أخرى',         'Other'),
  ]),
  WaCategory(id:'education',     label:'تعليم',     labelEn:'Education',      emoji:'🎓', subs:[
    WaSubCategory('🎓','دورات',         'Courses'),
    WaSubCategory('🏫','مدرسة/جامعة',  'School/University'),
    WaSubCategory('📖','كتب دراسية',   'Textbooks'),
    WaSubCategory('💾','برامج',         'Software'),
    WaSubCategory('✏️','قرطاسية',      'Stationery'),
    WaSubCategory('🏅','امتحانات',      'Exams'),
  ]),
  WaCategory(id:'family',        label:'عائلة',     labelEn:'Family',         emoji:'👨‍👩‍👧', subs:[
    WaSubCategory('🧒','مصروف أطفال',  'Child Allowance'),
    WaSubCategory('🎂','مناسبات',       'Occasions'),
    WaSubCategory('🍼','رعاية أطفال',  'Childcare'),
    WaSubCategory('🧓','رعاية أهل',    'Parent Care'),
    WaSubCategory('🎀','هدايا عائلية', 'Family Gifts'),
    WaSubCategory('🏡','نفقات منزلية', 'Household'),
  ]),
];

const kIncomeCategories = <WaCategory>[
  WaCategory(id:'salary',      label:'راتب',     labelEn:'Salary',       emoji:'💼', subs:[
    WaSubCategory('💼','راتب شهري',   'Monthly Salary'),
    WaSubCategory('🏅','مكافأة',       'Bonus'),
    WaSubCategory('⏰','عمل إضافي',   'Overtime'),
    WaSubCategory('💻','عمل حر',       'Freelance'),
    WaSubCategory('📊','عمولة',        'Commission'),
    WaSubCategory('🎖️','علاوة',       'Allowance'),
  ]),
  WaCategory(id:'business',   label:'أعمال',    labelEn:'Business',     emoji:'🏢', subs:[
    WaSubCategory('🏢','أرباح مشروع', 'Business Profit'),
    WaSubCategory('🛒','مبيعات',       'Sales'),
    WaSubCategory('🤝','خدمات',        'Services'),
    WaSubCategory('💡','استشارات',     'Consulting'),
    WaSubCategory('📦','بضاعة',        'Goods'),
    WaSubCategory('🔑','امتياز',       'Franchise'),
  ]),
  WaCategory(id:'investment',  label:'استثمار', labelEn:'Investment',   emoji:'📈', subs:[
    WaSubCategory('📈','أسهم',          'Stocks'),
    WaSubCategory('🏘️','عقارات',       'Real Estate'),
    WaSubCategory('🏦','فوائد بنكية',  'Bank Interest'),
    WaSubCategory('₿','عملات رقمية',   'Cryptocurrency'),
    WaSubCategory('🪙','ذهب',           'Gold'),
    WaSubCategory('💹','صناديق',        'Funds'),
  ]),
  WaCategory(id:'rental',      label:'إيجارات', labelEn:'Rentals',      emoji:'🏠', subs:[
    WaSubCategory('🏠','إيجار شقة',    'Apartment Rent'),
    WaSubCategory('🏪','إيجار محل',    'Shop Rent'),
    WaSubCategory('🚗','إيجار سيارة', 'Car Rent'),
    WaSubCategory('📦','إيجار مستودع', 'Warehouse Rent'),
    WaSubCategory('🌐','إيجار رقمي',  'Digital Rent'),
  ]),
  WaCategory(id:'other_income',label:'دخل آخر', labelEn:'Other Income', emoji:'💰', subs:[
    WaSubCategory('🎁','هدية',          'Gift'),
    WaSubCategory('🏛️','ميراث',        'Inheritance'),
    WaSubCategory('💰','بيع أصل',      'Asset Sale'),
    WaSubCategory('🔄','استرداد',       'Refund'),
    WaSubCategory('🤲','تبرع مُستلم',  'Donation Received'),
    WaSubCategory('➕','أخرى',          'Other'),
  ]),
];

WaCategory? findCategory(String id, String type) {
  final list = type == 'income' ? kIncomeCategories : kExpenseCategories;
  try { return list.firstWhere((c) => c.id == id); } catch (_) { return null; }
}

const kMonthsAr = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
const kDaysAr   = ['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];
const kMonthsEn = ['January','February','March','April','May','June','July','August','September','October','November','December'];
const kDaysEn   = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
