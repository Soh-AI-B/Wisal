import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../core/database/app_database.dart';
import '../../core/i18n.dart';
import '../../core/platform/native_bridge.dart';

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
  bool _notifOk = false;
  bool _exactOk = true;

  static const _pageCount = 6;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final contacts = await Native.granted('contacts') && await Native.granted('callLog');
    final notif = await Native.granted('notifications');
    final exact = await Native.granted('exactAlarm');
    if (!mounted) return;
    setState(() {
      _contactsOk = contacts;
      _notifOk = notif;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget page({required IconData icon, required String title, required String body, Widget? extra}) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(icon, size: 72, color: kinGold),
          const SizedBox(height: 24),
          Text(title, textAlign: TextAlign.center, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(body, textAlign: TextAlign.center, style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          if (extra != null) ...[const SizedBox(height: 20), extra],
        ]),
      );
    }

    final pages = <Widget>[
      page(
        icon: Icons.volunteer_activism,
        title: tr(ref, 'Welcome to Wisal', 'مرحباً بك في وصال'),
        body: tr(
            ref,
            "Wisal helps you keep صلة الرحم: it reminds you who you haven't called in a while, and sends you a motivational sentence every day.",
            'وصال يساعدك على صلة الرحم: يذكرك بمن لم تتصل به منذ فترة، ويرسل لك جملة تحفيزية كل يوم.'),
        extra: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'en', label: Text('English')),
            ButtonSegment(value: 'ar', label: Text('العربية')),
          ],
          selected: {isArabic(ref) ? 'ar' : 'en'},
          onSelectionChanged: (sel) async {
            await AppDatabase.instance.setSetting('language', sel.first);
            ref.invalidate(languageProvider);
          },
        ),
      ),
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
            label: Text(_contactsOk
                ? tr(ref, 'Access granted', 'تم منح الإذن')
                : tr(ref, 'Allow access', 'السماح بالوصول')),
            onPressed: _contactsOk
                ? null
                : () async {
                    await Native.request('contacts');
                    await Native.request('callLog');
                    await _refreshStatus();
                  },
          ),
          const SizedBox(height: 8),
          Text(
            tr(ref, "If you already denied it, enable it from your phone's Settings → Apps → Wisal → Permissions.",
                'إذا رفضته سابقاً، فعّله من إعدادات الهاتف ← التطبيقات ← وصال ← الأذونات.'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ]),
      ),
      page(
        icon: Icons.notifications_active_outlined,
        title: tr(ref, 'Turn on notifications', 'فعّل الإشعارات'),
        body: tr(
            ref,
            'Two notifications keep you on track: a reminder about who to call, and a daily صلة الرحم sentence — each on its own schedule (set the days and exact time later in Settings).',
            'إشعاران يساعدانك على المتابعة: تذكير بمن تتصل به، وجملة صلة الرحم يومياً — لكل منهما جدوله الخاص (حدد الأيام والوقت لاحقاً من الإعدادات).'),
        extra: Column(children: [
          FilledButton.icon(
            icon: Icon(_notifOk ? Icons.check : Icons.notifications_outlined),
            label: Text(
                _notifOk ? tr(ref, 'Notifications on', 'الإشعارات مفعّلة') : tr(ref, 'Enable notifications', 'تفعيل الإشعارات')),
            onPressed: _notifOk
                ? null
                : () async {
                    await Native.request('notifications');
                    await _refreshStatus();
                  },
          ),
          const SizedBox(height: 8),
          if (!_exactOk)
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text(tr(ref, 'Allow exact timing', 'السماح بالتوقيت الدقيق')),
              onPressed: () async {
                await Native.openExactAlarmSettings();
                await _refreshStatus();
              },
            ),
          const SizedBox(height: 8),
          Text(
            tr(ref, 'Exact timing keeps notifications on the minute you choose instead of "sometime around" it.',
                'التوقيت الدقيق يجعل الإشعارات تصل في الوقت الذي تحدده بالضبط بدلاً من "وقت تقريبي".'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ]),
      ),
      page(
        icon: Icons.schedule_outlined,
        title: tr(ref, 'Set your schedule', 'حدد جدولك'),
        body: tr(
            ref,
            'In Settings → Reminder / Daily sentence, choose how often (every day, every 2 days, or weekly) and at what exact time each notification should arrive.',
            'من الإعدادات ← التذكير / تذكير اليوم، اختر التكرار (كل يوم، كل يومين، أو أسبوعياً) والوقت الدقيق لوصول كل إشعار.'),
      ),
      page(
        icon: Icons.widgets_outlined,
        title: tr(ref, 'Add the home-screen widget', 'أضف الودجت إلى الشاشة الرئيسية'),
        body: tr(
            ref,
            'Long-press an empty spot on your home screen → Widgets → find "Wisal" → drag it onto your home screen. It shows a scrollable list of everyone you\'re overdue to call.',
            'اضغط مطولاً على مكان فارغ في الشاشة الرئيسية ← الودجت ← ابحث عن "وصال" ← اسحبه إلى الشاشة الرئيسية. يعرض قائمة قابلة للتمرير بكل من تأخرت في الاتصال بهم.'),
      ),
      page(
        icon: Icons.check_circle_outline,
        title: tr(ref, "You're all set", 'كل شيء جاهز'),
        body: tr(ref, 'Add your first list of people, and Wisal will take it from here.',
            'أضف أول قائمة أشخاص، وسيتولى وصال الباقي.'),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 8, left: 8),
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
            padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_page == _pageCount - 1 ? tr(ref, 'Get started', 'ابدأ الآن') : tr(ref, 'Next', 'التالي')),
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
