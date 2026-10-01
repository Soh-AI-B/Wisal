import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/app_database.dart';
import 'i18n.dart';
import 'models.dart';
import 'platform/native_bridge.dart';

final peopleProvider = FutureProvider<List<Person>>((ref) => AppDatabase.instance.people());
final listsProvider = FutureProvider<List<ContactList>>((ref) => AppDatabase.instance.lists());
final settingsProvider = FutureProvider<Map<String, String>>((ref) => AppDatabase.instance.settings());
final statsProvider = FutureProvider((ref) => AppDatabase.instance.stats());
final statsDetailedProvider = FutureProvider((ref) => AppDatabase.instance.statsDetailed());
final onboardingCompleteProvider =
    FutureProvider<bool>((ref) async => await AppDatabase.instance.setting('onboardingComplete', '0') == '1');
final permissionsProvider = FutureProvider<bool>(
    (ref) async => await Native.granted('callLog') && await Native.granted('contacts'));
final notifPermProvider = FutureProvider<bool>((ref) => Native.granted('notifications'));
final exactAlarmPermProvider = FutureProvider<bool>((ref) => Native.granted('exactAlarm'));
final filterProvider = StateProvider<int?>((ref) => null);
final syncStatusProvider = StateProvider<String>((ref) => '');

String _hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Reads the call log natively, refreshes the cache and the UI, and records the outcome.
Future<void> syncNow(WidgetRef ref) async {
  final ar = isArabic(ref);
  String status;
  try {
    if (await Native.granted('callLog') && await Native.granted('contacts')) {
      await AppDatabase.instance.pushConfig();
      final res = await Native.sync();
      if (res['ok'] == true) {
        await AppDatabase.instance.saveLast(Map<String, dynamic>.from(res['calls'] as Map));
        status = ar ? 'آخر تزامن ${_hhmm(DateTime.now())}' : 'Last synced ${_hhmm(DateTime.now())}';
      } else {
        status = res['reason'] == 'provider_unavailable'
            ? (ar ? 'فشل التزامن: بيانات الهاتف غير متاحة. اسحب للمحاولة مجدداً.' : 'Sync failed: phone data unavailable. Pull to retry.')
            : (ar ? 'بانتظار الأذونات' : 'Waiting for permissions');
      }
    } else {
      status = ar ? 'بانتظار الأذونات' : 'Waiting for permissions';
    }
  } catch (e) {
    debugPrint('sync failed: $e');
    status = ar ? 'فشل التزامن: $e' : 'Sync failed: $e';
  }
  ref.read(syncStatusProvider.notifier).state = status;
  ref.invalidate(peopleProvider);
  ref.invalidate(listsProvider);
  ref.invalidate(statsProvider);
  ref.invalidate(statsDetailedProvider);
  ref.invalidate(permissionsProvider);
  ref.invalidate(notifPermProvider);
  ref.invalidate(exactAlarmPermProvider);
}
