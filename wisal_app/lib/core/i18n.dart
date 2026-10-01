import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/app_database.dart';

/// In-app language toggle, independent of the phone's system language.
final languageProvider = FutureProvider<String>((ref) => AppDatabase.instance.setting('language', 'ar'));

bool isArabic(WidgetRef ref) => ref.watch(languageProvider).valueOrNull == 'ar';

/// `tr(ref, 'Home', 'الرئيسية')` — pick the Arabic string when the app's language setting is Arabic.
String tr(WidgetRef ref, String en, String ar) => isArabic(ref) ? ar : en;
