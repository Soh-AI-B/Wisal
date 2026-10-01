import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/i18n.dart';
import '../../core/platform/native_bridge.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

const _cadenceLabelsEn = {1: 'Every day', 2: 'Every 2 days', 7: 'Every week'};
const _cadenceLabelsAr = {1: 'كل يوم', 2: 'كل يومين', 7: 'كل أسبوع'};

/// First-run walkthrough: what the app does, and how to set it up (permissions, notification
/// schedule, the home-screen widget). Also reachable later from Settings → "How to use Wisal".
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _contactsOk = false;
  bool _exactOk = true;

  static const _pageCount = 7;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final contacts = await Native.granted('contacts') && await Native.granted('callLog');
    final exact = await Native.granted('exactAlarm');
    if (!mounted) return;
    setState(() {
      _contactsOk = contacts;
      _exactOk = exact;
    });
  }

  Future<void> _finish() async {
    await AppDatabase.instance.setSetting('onboardingComplete', '1');
    widget.onDone();
  }

  void _next() {
    if (_page == _pageCount - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _pickTime(String hourKey, String minuteKey, int hour, int minute) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: hour, minute: minute));
    if (picked == null) return;
    final db = AppDatabase.instance;
    await db.setSetting(hourKey, '${picked.hour}');
    await db.setSetting(minuteKey, '${picked.minute}');
    ref.invalidate(settingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ar = isArabic(ref);

    Widget page({required IconData icon, required String title, String? body, Widget? extra}) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(icon, size: 64, color: kinGold),
          const SizedBox(height: WSpace.lg),
          Text(title, textAlign: TextAlign.center, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          if (body != null) ...[
            const SizedBox(height: WSpace.md),
            Text(body, textAlign: TextAlign.center, style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          ],
          if (extra != null) ...[const SizedBox(height: WSpace.lg), extra],
        ]),
      );
    }

    final pages = <Widget>[
      // 1. Welcome
      page(
        icon: Icons.volunteer_activism,
        title: tr(ref, 'Welcome to Wisal', 'مرحباً بك في وصال'),
        body: tr(
            ref,
            "Wisal helps you keep صلة الرحم: it reminds you who you haven't called in a while, and sends you a motivational sentence every day.",
            'وصال يساعدك على صلة الرحم: يذكرك بمن لم تتصل به منذ فترة، ويرسل لك جملة تحفيزية كل يوم.'),
      ),
      // 2. Language
      page(
        icon: Icons.translate,
        title: tr(ref, 'Choose your language', 'اختر لغتك'),
        extra: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ar', label: Text('العربية')),
            ButtonSegment(value: 'en', label: Text('English')),
          ],
          selected: {ar ? 'ar' : 'en'},
          onSelectionChanged: (sel) async {
            await AppDatabase.instance.setSetting('language', sel.first);
            ref.invalidate(languageProvider);
          },
        ),
      ),
      // 3. Permissions
      page(
        icon: Icons.contact_phone_outlined,
        title: tr(ref, 'Allow contacts & call history', 'اسمح بجهات الاتصال وسجل المكالمات'),
        body: tr(
            ref,
            'Wisal reads your contacts and call log locally on your phone to find your last call with each person — nothing ever leaves your device.',
            'يقرأ وصال جهات اتصالك وسجل مكالماتك محلياً على هاتفك لمعرفة آخر اتصال بكل شخص — لا تغادر بياناتك جهازك أبداً.'),
        extra: Column(children: [
          FilledButton.icon(
            icon: Icon(_contactsOk ? Icons.check : Icons.lock_open),
            label:
                Text(_contactsOk ? tr(ref, 'Access granted', 'تم منح الإذن') : tr(ref, 'Allow access', 'السماح بالوصول')),
            onPressed: _contactsOk
                ? null
                : () async {
                    await Native.request('contacts');
                    await Native.request('callLog');
                    await _refreshStatus();
                  },
          ),
          const SizedBox(height: WSpace.sm),
          Text(
            tr(ref, "If you already denied it, enable it from your phone's Settings → Apps → Wisal → Permissions.",
                'إذا رفضته سابقاً، فعّله من إعدادات الهاتف ← التطبيقات ← وصال ← الأذونات.'),
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ]),
      ),
      // 4. Notifications (live controls)
      page(
        icon: Icons.notifications_active_outlined,
        title: tr(ref, 'Notifications', 'الإشعارات'),
        extra: Consumer(builder: (context, ref, _) {
          final s = ref.watch(settingsProvider).valueOrNull ?? const {};
          String v(String k, String def) => s[k] ?? def;
          final reminderOn = v('reminderEnabled', '1') == '1';
          final reminderCadence = int.tryParse(v('reminderCadenceDays', '1')) ?? 1;
          final reminderHour = int.tryParse(v('reminderHour', '18')) ?? 18;
          final reminderMinute = int.tryParse(v('reminderMinute', '0')) ?? 0;
          final sentenceOn = v('sentenceEnabled', '1') == '1';
          final sentenceHour = int.tryParse(v('sentenceHour', '8')) ?? 8;
          final sentenceMinute = int.tryParse(v('sentenceMinute', '0')) ?? 0;
          String hhmm(int h, int m) => TimeOfDay(hour: h, minute: m).format(context);

          return Card(
            child: Column(children: [
              SwitchListTile(
                title: Text(tr(ref, 'Overdue people reminder', 'تذكير بالأشخاص المتأخرين')),
                subtitle: Text('${hhmm(reminderHour, reminderMinute)} · ${ar ? _cadenceLabelsAr[reminderCadence] : _cadenceLabelsEn[reminderCadence]}'),
                value: reminderOn,
                onChanged: (val) async {
                  if (val) await Native.request('notifications');
                  await AppDatabase.instance.setSetting('reminderEnabled', val ? '1' : '0');
                  ref.invalidate(settingsProvider);
                  await _refreshStatus();
                },
              ),
              if (reminderOn) ...[
                ListTile(
                  dense: true,
                  title: Text(tr(ref, 'Time', 'الوقت')),
                  trailing: Text(hhmm(reminderHour, reminderMinute)),
                  onTap: () => _pickTime('reminderHour', 'reminderMinute', reminderHour, reminderMinute),
                ),
                ListTile(
                  dense: true,
                  title: Text(tr(ref, 'Repeat', 'التكرار')),
                  trailing: DropdownButton<int>(
                    value: reminderCadence,
                    items: [1, 2, 7]
                        .map((d) => DropdownMenuItem(value: d, child: Text(ar ? _cadenceLabelsAr[d]! : _cadenceLabelsEn[d]!)))
                        .toList(),
                    onChanged: (d) async {
                      if (d == null) return;
                      await AppDatabase.instance.setSetting('reminderCadenceDays', '$d');
                      ref.invalidate(settingsProvider);
                    },
                  ),
                ),
              ],
              const Divider(height: 1),
              SwitchListTile(
                title: Text(tr(ref, 'Daily sentence', 'الجملة اليومية')),
                subtitle: Text(hhmm(sentenceHour, sentenceMinute)),
                value: sentenceOn,
                onChanged: (val) async {
                  if (val) await Native.request('notifications');
                  await AppDatabase.instance.setSetting('sentenceEnabled', val ? '1' : '0');
                  ref.invalidate(settingsProvider);
                  await _refreshStatus();
                },
              ),
              if (sentenceOn)
                ListTile(
                  dense: true,
                  title: Text(tr(ref, 'Time', 'الوقت')),
                  trailing: Text(hhmm(sentenceHour, sentenceMinute)),
                  onTap: () => _pickTime('sentenceHour', 'sentenceMinute', sentenceHour, sentenceMinute),
                ),
            ]),
          );
        }),
      ),
      // 5. Exact alarms
      page(
        icon: Icons.schedule_outlined,
        title: tr(ref, 'Exact timing', 'إذن التنبيهات الدقيقة'),
        body: tr(
            ref,
            'Required so notifications arrive at the exact time you choose, instead of "sometime around" it.',
            'مطلوب لضمان وصول الإشعارات في الوقت المحدد بالضبط، بدلاً من "وقت تقريبي".'),
        extra: _exactOk
            ? const Icon(Icons.check_circle, color: wisalPrimary, size: 32)
            : Column(children: [
                FilledButton.icon(
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(tr(ref, 'Open settings', 'فتح الإعدادات')),
                  onPressed: () async {
                    await Native.openExactAlarmSettings();
                    await _refreshStatus();
                  },
                ),
                const SizedBox(height: WSpace.sm),
                TextButton(onPressed: _next, child: Text(tr(ref, "I'll do this later", 'سأتجاوز الآن'))),
              ]),
      ),
      // 6. Widget
      page(
        icon: Icons.widgets_outlined,
        title: tr(ref, 'Add the home screen widget', 'أضف الويدجت إلى شاشتك الرئيسية'),
        body: tr(
            ref,
            'Long-press an empty spot on your home screen → Widgets → find "Wisal" → drag it onto your home screen. It shows a scrollable list of everyone you\'re overdue to call.',
            'اضغط مطولاً على مكان فارغ في الشاشة الرئيسية ← الودجت ← ابحث عن "وصال" ← اسحبه إلى الشاشة الرئيسية. يعرض قائمة قابلة للتمرير بكل من تأخرت في الاتصال بهم.'),
      ),
      // 7. Complete
      page(
        icon: Icons.check_circle_outline,
        title: tr(ref, "You're all set!", 'تم!'),
        body: tr(ref, 'You can now create your lists and start keeping in touch.',
            'الآن يمكنك إضافة قوائم ومتابعة تواصلك مع من تحب.'),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: WSpace.sm),
              child: TextButton(onPressed: _finish, child: Text(tr(ref, 'Skip', 'تخطي'))),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) {
                setState(() => _page = i);
                _refreshStatus();
              },
              children: pages,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(WSpace.xl),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _pageCount; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? cs.primary : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ]),
              const SizedBox(height: WSpace.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_page == _pageCount - 1 ? tr(ref, 'Get started', 'ابدأ الآن') : tr(ref, 'Continue', 'متابعة')),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
