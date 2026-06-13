import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WaCategory {
  final String id, label, emoji;
  final List<WaSubCategory> subs;
  const WaCategory({required this.id, required this.label, required this.emoji, required this.subs});
  Color get color => WaColors.catColor(id);
}

class WaSubCategory {
  final String emoji, label;
  const WaSubCategory(this.emoji, this.label);
}

const kExpenseCategories = <WaCategory>[
  WaCategory(id:'food',          label:'طعام',      emoji:'🍽️', subs:[WaSubCategory('🍽️','مطاعم'),WaSubCategory('🛒','بقالة'),WaSubCategory('☕','مقاهي'),WaSubCategory('🥐','مخابز'),WaSubCategory('🛵','توصيل'),WaSubCategory('🍱','أخرى')]),
  WaCategory(id:'transport',     label:'مواصلات',   emoji:'🚗', subs:[WaSubCategory('⛽','وقود'),WaSubCategory('🚕','تاكسي'),WaSubCategory('🔧','صيانة'),WaSubCategory('📋','تأمين'),WaSubCategory('🚌','نقل عام'),WaSubCategory('✈️','سفر')]),
  WaCategory(id:'health',        label:'صحة',       emoji:'❤️', subs:[WaSubCategory('💊','أدوية'),WaSubCategory('🏥','طبيب'),WaSubCategory('🏋️','رياضة'),WaSubCategory('💉','صيدلية'),WaSubCategory('🪥','عناية'),WaSubCategory('🦷','أسنان')]),
  WaCategory(id:'bills',         label:'فواتير',    emoji:'🏠', subs:[WaSubCategory('🏠','إيجار'),WaSubCategory('💡','كهرباء/ماء'),WaSubCategory('📶','إنترنت'),WaSubCategory('📱','هاتف'),WaSubCategory('🔨','صيانة منزل'),WaSubCategory('🔐','تأمين منزل')]),
  WaCategory(id:'entertainment', label:'ترفيه',     emoji:'🎬', subs:[WaSubCategory('🎬','سينما'),WaSubCategory('📺','اشتراكات'),WaSubCategory('🎮','ألعاب'),WaSubCategory('🏖️','سياحة'),WaSubCategory('📚','كتب'),WaSubCategory('⚽','رياضة')]),
  WaCategory(id:'shopping',      label:'تسوق',      emoji:'🛍️', subs:[WaSubCategory('👔','ملابس'),WaSubCategory('👟','أحذية'),WaSubCategory('💻','إلكترونيات'),WaSubCategory('🪴','أدوات منزل'),WaSubCategory('🎁','هدايا'),WaSubCategory('🛍️','أخرى')]),
  WaCategory(id:'education',     label:'تعليم',     emoji:'🎓', subs:[WaSubCategory('🎓','دورات'),WaSubCategory('🏫','مدرسة/جامعة'),WaSubCategory('📖','كتب دراسية'),WaSubCategory('💾','برامج'),WaSubCategory('✏️','قرطاسية'),WaSubCategory('🏅','امتحانات')]),
  WaCategory(id:'family',        label:'عائلة',     emoji:'👨‍👩‍👧', subs:[WaSubCategory('🧒','مصروف أطفال'),WaSubCategory('🎂','مناسبات'),WaSubCategory('🍼','رعاية أطفال'),WaSubCategory('🧓','رعاية أهل'),WaSubCategory('🎀','هدايا عائلية'),WaSubCategory('🏡','نفقات منزلية')]),
];

const kIncomeCategories = <WaCategory>[
  WaCategory(id:'salary',      label:'راتب',     emoji:'💼', subs:[WaSubCategory('💼','راتب شهري'),WaSubCategory('🏅','مكافأة'),WaSubCategory('⏰','عمل إضافي'),WaSubCategory('💻','عمل حر'),WaSubCategory('📊','عمولة'),WaSubCategory('🎖️','علاوة')]),
  WaCategory(id:'business',   label:'أعمال',    emoji:'🏢', subs:[WaSubCategory('🏢','أرباح مشروع'),WaSubCategory('🛒','مبيعات'),WaSubCategory('🤝','خدمات'),WaSubCategory('💡','استشارات'),WaSubCategory('📦','بضاعة'),WaSubCategory('🔑','امتياز')]),
  WaCategory(id:'investment',  label:'استثمار', emoji:'📈', subs:[WaSubCategory('📈','أسهم'),WaSubCategory('🏘️','عقارات'),WaSubCategory('🏦','فوائد بنكية'),WaSubCategory('₿','عملات رقمية'),WaSubCategory('🪙','ذهب'),WaSubCategory('💹','صناديق')]),
  WaCategory(id:'rental',      label:'إيجارات', emoji:'🏠', subs:[WaSubCategory('🏠','إيجار شقة'),WaSubCategory('🏪','إيجار محل'),WaSubCategory('🚗','إيجار سيارة'),WaSubCategory('📦','إيجار مستودع'),WaSubCategory('🌐','إيجار رقمي')]),
  WaCategory(id:'other_income',label:'دخل آخر', emoji:'💰', subs:[WaSubCategory('🎁','هدية'),WaSubCategory('🏛️','ميراث'),WaSubCategory('💰','بيع أصل'),WaSubCategory('🔄','استرداد'),WaSubCategory('🤲','تبرع مُستلم'),WaSubCategory('➕','أخرى')]),
];

WaCategory? findCategory(String id, String type) {
  final list = type == 'income' ? kIncomeCategories : kExpenseCategories;
  try { return list.firstWhere((c) => c.id == id); } catch (_) { return null; }
}

const kMonthsAr = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
const kDaysAr   = ['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];
