import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/i18n.dart';
import '../../core/platform/native_bridge.dart';
import '../../core/providers.dart';
import '../onboarding/onboarding_screen.dart';

const _cadenceLabelsEn = {1: 'Every day', 2: 'Every 2 days', 7: 'Every week'};
const _cadenceLabelsAr = {1: 'كل يوم', 2: 'كل يومين', 7: 'كل أسبوع'};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _pickTime(BuildContext context, WidgetRef ref, String hourKey, String minuteKey, int hour, int minute) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: hour, minute: minute));
    if (picked == null) return;
    final db = AppDatabase.instance;
    await db.setSetting(hourKey, '${picked.hour}');
    await db.setSetting(minuteKey, '${picked.minute}');
    ref.invalidate(settingsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).valueOrNull ?? const {};
    String v(String k, String def) => s[k] ?? def;
    final db = AppDatabase.instance;
    final ar = isArabic(ref);
    final bgOn = v('backgroundEnabled', '1') == '1';
    final exactAlarmOk = ref.watch(exactAlarmPermProvider).valueOrNull ?? true;
    final notifOk = ref.watch(notifPermProvider).valueOrNull ?? true;

    final reminderOn = v('reminderEnabled', '1') == '1';
    final reminderCadence = int.tryParse(v('reminderCadenceDays', '1')) ?? 1;
    final reminderHour = int.tryParse(v('reminderHour', '18')) ?? 18;
    final reminderMinute = int.tryParse(v('reminderMinute', '0')) ?? 0;

    final sentenceOn = v('sentenceEnabled', '1') == '1';
    final sentenceHour = int.tryParse(v('sentenceHour', '8')) ?? 8;
    final sentenceMinute = int.tryParse(v('sentenceMinute', '0')) ?? 0;

    String hhmm(int h, int m) => TimeOfDay(hour: h, minute: m).format(context);

    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'Settings', 'الإعدادات'))),
      body: ListView(children: [
        ListTile(
          title: Text(tr(ref, 'Language', 'اللغة')),
          trailing: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'ar', label: Text('العربية')),
            ],
            selected: {v('language', 'ar')},
            onSelectionChanged: (sel) async {
              await db.setSetting('language', sel.first);
              ref.invalidate(languageProvider);
              ref.invalidate(settingsProvider);
            },
          ),
        ),
        const Divider(),
        if (!notifOk)
          ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: Text(tr(ref, 'Notifications are blocked', 'الإشعارات محظورة')),
            subtitle: Text(tr(ref, 'Allow notifications for this app in Android settings to receive either reminder below.',
                'اسمح بالإشعارات لهذا التطبيق من إعدادات أندرويد لتصلك التذكيرات أدناه.')),
          ),
        ListTile(
          title: Text(tr(ref, 'Reminder', 'التذكير'), style: Theme.of(context).textTheme.titleSmall),
        ),
        SwitchListTile(
          title: Text(tr(ref, 'Overdue people reminder', 'تذكير بالأشخاص المتأخرين')),
          subtitle: Text(!bgOn
              ? tr(ref, 'Requires background updates', 'يتطلب تفعيل التحديث في الخلفية')
              : tr(ref, 'Notifies you who to call, on your schedule', 'يذكرك بمن تتصل به حسب الجدول الذي تحدده')),
          value: reminderOn && bgOn,
          onChanged: !bgOn
              ? null
              : (val) async {
                  if (val) await Native.request('notifications');
                  await db.setSetting('reminderEnabled', val ? '1' : '0');
                  ref.invalidate(settingsProvider);
                },
        ),
        ListTile(
          enabled: reminderOn && bgOn,
          title: Text(tr(ref, 'Repeats', 'التكرار')),
          trailing: DropdownButton<int>(
            value: reminderCadence,
            items: [1, 2, 7]
                .map((d) => DropdownMenuItem(value: d, child: Text(ar ? _cadenceLabelsAr[d]! : _cadenceLabelsEn[d]!)))
                .toList(),
            onChanged: !(reminderOn && bgOn)
                ? null
                : (d) async {
                    if (d == null) return;
                    await db.setSetting('reminderCadenceDays', '$d');
                    ref.invalidate(settingsProvider);
                  },
          ),
        ),
        ListTile(
          enabled: reminderOn && bgOn,
          title: Text(tr(ref, 'At', 'في تمام')),
          trailing: Text(hhmm(reminderHour, reminderMinute)),
          onTap: !(reminderOn && bgOn)
              ? null
              : () => _pickTime(context, ref, 'reminderHour', 'reminderMinute', reminderHour, reminderMinute),
        ),
        const Divider(),
        ListTile(
          title: Text(tr(ref, 'Daily sentence', 'تذكير اليوم'), style: Theme.of(context).textTheme.titleSmall),
        ),
        SwitchListTile(
          title: Text(tr(ref, 'صلة الرحم sentence of the day', 'رسالة صلة الرحم اليومية')),
          subtitle: Text(!bgOn
              ? tr(ref, 'Requires background updates', 'يتطلب تفعيل التحديث في الخلفية')
              : tr(ref, 'A motivational sentence, once a day', 'رسالة تحفيزية مرة كل يوم')),
          value: sentenceOn && bgOn,
          onChanged: !bgOn
              ? null
              : (val) async {
                  if (val) await Native.request('notifications');
                  await db.setSetting('sentenceEnabled', val ? '1' : '0');
                  ref.invalidate(settingsProvider);
                },
        ),
        ListTile(
          enabled: sentenceOn && bgOn,
          title: Text(tr(ref, 'At', 'في تمام')),
          trailing: Text(hhmm(sentenceHour, sentenceMinute)),
          onTap: !(sentenceOn && bgOn)
              ? null
              : () => _pickTime(context, ref, 'sentenceHour', 'sentenceMinute', sentenceHour, sentenceMinute),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(tr(ref, 'Send test notification', 'إرسال إشعار تجريبي')),
          subtitle: Text(tr(ref, "Posts one right now, ignoring schedule — checks whether notifications can show at all",
              'يرسل إشعاراً فورياً بغض النظر عن الجدول، للتحقق من عمل الإشعارات')),
          onTap: () async {
            final r = await Native.testNotification();
            if (!context.mounted) return;
            final msg = switch (r) {
              'posted' => tr(ref, 'Sent — check your notification shade', 'تم الإرسال — تحقق من شريط الإشعارات'),
              'blocked_by_os' =>
                tr(ref, 'Blocked: allow notifications for this app in Android settings', 'محظور: فعّل الإشعارات لهذا التطبيق من إعدادات أندرويد'),
              _ => '${tr(ref, 'Failed', 'فشل')}: $r',
            };
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          },
        ),
        const Divider(),
        SwitchListTile(
          title: Text(tr(ref, 'Background updates', 'التحديث في الخلفية')),
          subtitle: Text(tr(ref, "Android decides when they run; timing is not exact",
              'يحدد النظام موعد تشغيلها؛ التوقيت غير دقيق')),
          value: bgOn,
          onChanged: (val) async {
            await db.setSetting('backgroundEnabled', val ? '1' : '0');
            await Native.schedule(val);
            ref.invalidate(settingsProvider);
          },
        ),
        if (!exactAlarmOk)
          ListTile(
            title: Text(tr(ref, 'Exact alarms', 'التنبيهات الدقيقة')),
            subtitle: Text(tr(ref, 'Allow this app to trigger notifications at the exact time you chose',
                'اسمح لهذا التطبيق بإطلاق الإشعارات في الوقت الذي حددته بالضبط')),
            onTap: () async {
              await Native.openExactAlarmSettings();
              ref.invalidate(exactAlarmPermProvider);
            },
          ),
        ListTile(
          title: Text(tr(ref, 'Battery optimization', 'تحسين البطارية')),
          subtitle: Text(tr(ref,
              'Your phone may restrict background activity. Allowing it can make reminders more reliable.',
              'قد يقيّد هاتفك النشاط في الخلفية. السماح به يجعل التذكيرات أكثر موثوقية.')),
          onTap: Native.openBatterySettings,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text(tr(ref, 'How to use Wisal', 'كيفية استخدام وصال')),
          subtitle: Text(tr(ref, 'Replay the setup walkthrough', 'إعادة عرض دليل الإعداد')),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => OnboardingScreen(onDone: () => Navigator.pop(context)))),
        ),
        ListTile(
          title: Text(tr(ref, 'Privacy', 'الخصوصية')),
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(tr(ref, 'Privacy', 'الخصوصية')),
              content: Text(tr(
                  ref,
                  'Everything stays on your phone. Contacts and call history are read locally. '
                      'No account, no server, no uploads.',
                  'كل شيء يبقى على هاتفك. تتم قراءة جهات الاتصال وسجل المكالمات محلياً. '
                      'لا حساب، لا خادم، لا رفع بيانات.')),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(ref, 'OK', 'حسناً')))],
            ),
          ),
        ),
        ListTile(
          title: Text(tr(ref, 'About', 'حول التطبيق')),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'Wisal',
            applicationVersion: '1.0.0',
            children: [
              Text(tr(ref, "Encourages صلة الرحم by reminding you to call people you haven't talked to in a while.",
                  'يشجّع على صلة الرحم بتذكيرك بالاتصال بمن لم تتحدث معهم منذ فترة.'))
            ],
          ),
        ),
      ]),
    );
  }
}
