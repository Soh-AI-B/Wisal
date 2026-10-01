import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/i18n.dart';
import '../../core/platform/native_bridge.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../onboarding/onboarding_screen.dart';

const _cadenceLabelsEn = {1: 'Every day', 2: 'Every 2 days', 7: 'Every week'};
const _cadenceLabelsAr = {1: 'كل يوم', 2: 'كل يومين', 7: 'كل أسبوع'};

Widget _sectionTitle(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(WSpace.xs, WSpace.lg, WSpace.xs, WSpace.sm),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );

Widget _circleIcon(IconData icon, Color color) =>
    CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color));

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _pickTime(
      BuildContext context, WidgetRef ref, String hourKey, String minuteKey, int hour, int minute) async {
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
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: WSpace.lg), children: [
        _sectionTitle(context, tr(ref, 'General', 'عام')),
        Card(
          child: Column(children: [
            ListTile(
              title: Text(tr(ref, 'Language', 'اللغة')),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ar', label: Text('العربية')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {v('language', 'ar')},
                onSelectionChanged: (sel) async {
                  await db.setSetting('language', sel.first);
                  ref.invalidate(languageProvider);
                  ref.invalidate(settingsProvider);
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: _circleIcon(Icons.help_outline, wisalPrimary),
              title: Text(tr(ref, 'How to use Wisal', 'كيفية استخدام وصال')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => OnboardingScreen(onDone: () => Navigator.pop(context)))),
            ),
          ]),
        ),
        _sectionTitle(context, tr(ref, 'Notifications', 'الإشعارات')),
        if (!notifOk)
          Card(
            color: wisalWarning.withValues(alpha: 0.1),
            child: ListTile(
              leading: const Icon(Icons.notifications_off_outlined, color: wisalWarning),
              title: Text(tr(ref, 'Notifications are blocked', 'الإشعارات محظورة')),
              subtitle: Text(
                  tr(ref, 'Allow notifications for this app in Android settings to receive either reminder below.',
                      'اسمح بالإشعارات لهذا التطبيق من إعدادات أندرويد لتصلك التذكيرات أدناه.')),
            ),
          ),
        Card(
          child: Column(children: [
            SwitchListTile(
              secondary: _circleIcon(Icons.notifications_active_outlined, wisalSecondary),
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
            if (reminderOn && bgOn) ...[
              const Divider(height: 1),
              ListTile(
                title: Text(tr(ref, 'Time', 'الوقت')),
                trailing: Text(hhmm(reminderHour, reminderMinute)),
                onTap: () => _pickTime(context, ref, 'reminderHour', 'reminderMinute', reminderHour, reminderMinute),
              ),
              const Divider(height: 1),
              ListTile(
                title: Text(tr(ref, 'Repeat', 'التكرار')),
                trailing: DropdownButton<int>(
                  value: reminderCadence,
                  items: [1, 2, 7]
                      .map((d) => DropdownMenuItem(value: d, child: Text(ar ? _cadenceLabelsAr[d]! : _cadenceLabelsEn[d]!)))
                      .toList(),
                  onChanged: (d) async {
                    if (d == null) return;
                    await db.setSetting('reminderCadenceDays', '$d');
                    ref.invalidate(settingsProvider);
                  },
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: WSpace.sm),
        Card(
          child: Column(children: [
            SwitchListTile(
              secondary: _circleIcon(Icons.format_quote, wisalSecondary),
              title: Text(tr(ref, 'Daily sentence', 'الجملة اليومية')),
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
            if (sentenceOn && bgOn) ...[
              const Divider(height: 1),
              ListTile(
                title: Text(tr(ref, 'Time', 'الوقت')),
                trailing: Text(hhmm(sentenceHour, sentenceMinute)),
                onTap: () => _pickTime(context, ref, 'sentenceHour', 'sentenceMinute', sentenceHour, sentenceMinute),
              ),
            ],
          ]),
        ),
        const SizedBox(height: WSpace.sm),
        Card(
          child: ListTile(
            leading: const Icon(Icons.send_outlined),
            title: Text(tr(ref, 'Send test notification', 'إرسال إشعار تجريبي')),
            subtitle: Text(tr(ref, 'Posts one right now, ignoring schedule',
                'يرسل إشعاراً فورياً بغض النظر عن الجدول')),
            onTap: () async {
              final r = await Native.testNotification();
              if (!context.mounted) return;
              final msg = switch (r) {
                'posted' => tr(ref, 'Sent — check your notification shade', 'تم الإرسال — تحقق من شريط الإشعارات'),
                'blocked_by_os' => tr(ref, 'Blocked: allow notifications for this app in Android settings',
                    'محظور: فعّل الإشعارات لهذا التطبيق من إعدادات أندرويد'),
                _ => '${tr(ref, 'Failed', 'فشل')}: $r',
              };
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            },
          ),
        ),
        _sectionTitle(context, tr(ref, 'System', 'النظام')),
        Card(
          child: Column(children: [
            SwitchListTile(
              title: Text(tr(ref, 'Background updates', 'التحديث في الخلفية')),
              subtitle: Text(
                  tr(ref, 'Android decides when they run; timing is not exact', 'يحدد النظام موعد تشغيلها؛ التوقيت غير دقيق')),
              value: bgOn,
              onChanged: (val) async {
                await db.setSetting('backgroundEnabled', val ? '1' : '0');
                await Native.schedule(val);
                ref.invalidate(settingsProvider);
              },
            ),
            if (!exactAlarmOk) ...[
              const Divider(height: 1),
              ListTile(
                title: Text(tr(ref, 'Exact alarms', 'التنبيهات الدقيقة')),
                subtitle: Text(tr(ref, 'Allow this app to trigger notifications at the exact time you chose',
                    'اسمح لهذا التطبيق بإطلاق الإشعارات في الوقت الذي حددته بالضبط')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Native.openExactAlarmSettings();
                  ref.invalidate(exactAlarmPermProvider);
                },
              ),
            ],
            const Divider(height: 1),
            ListTile(
              title: Text(tr(ref, 'Battery optimization', 'تحسين البطارية')),
              subtitle: Text(tr(ref,
                  'Your phone may restrict background activity. Allowing it can make reminders more reliable.',
                  'قد يقيّد هاتفك النشاط في الخلفية. السماح به يجعل التذكيرات أكثر موثوقية.')),
              trailing: const Icon(Icons.chevron_right),
              onTap: Native.openBatterySettings,
            ),
          ]),
        ),
        _sectionTitle(context, tr(ref, 'About', 'حول التطبيق')),
        Card(
          child: Column(children: [
            ListTile(
              title: Text(tr(ref, 'Privacy', 'الخصوصية')),
              trailing: const Icon(Icons.chevron_right),
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
            const Divider(height: 1),
            ListTile(
              title: Text(tr(ref, 'About', 'حول التطبيق')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Wisal',
                applicationVersion: '1.0.0',
                applicationIcon: Image.asset('assets/wisal_logo.png', width: 56, height: 56),
                children: [
                  Text(tr(ref, "Encourages صلة الرحم by reminding you to call people you haven't talked to in a while.",
                      'يشجّع على صلة الرحم بتذكيرك بالاتصال بمن لم تتحدث معهم منذ فترة.'))
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: WSpace.xl),
        Center(
          child: Text(tr(ref, 'Your data stays on this phone only', 'بياناتك محفوظة على هذا الهاتف فقط'),
              style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(height: WSpace.lg),
      ]),
    );
  }
}
