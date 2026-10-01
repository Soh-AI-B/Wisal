import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/call_nudge.dart';
import '../../core/database/app_database.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/platform/native_bridge.dart';
import '../../core/providers.dart';
import '../../core/reminder/reminder_engine.dart';
import '../../core/sentences.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../lists/person_detail_screen.dart';
import '../lists/snooze_sheet.dart';
import 'daily_sentence_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.onOpenLists});
  final VoidCallback onOpenLists;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bg = await AppDatabase.instance.setting('backgroundEnabled', '1') == '1';
      await Native.schedule(bg);
      if (mounted) await syncNow(ref);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) syncNow(ref);
  }

  String _greeting(bool ar) {
    final h = DateTime.now().hour;
    if (h < 12) return ar ? 'صباح الخير 👋' : 'Good morning 👋';
    if (h < 18) return ar ? 'مساء الخير 👋' : 'Good afternoon 👋';
    return ar ? 'مساء الخير 👋' : 'Good evening 👋';
  }

  Future<void> _snooze(Person p) async {
    final until = await showSnoozeSheet(context, ref);
    if (until == null) return;
    await AppDatabase.instance.snooze(p.memberId, until);
    await syncNow(ref);
  }

  void _openPerson(Person p) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetailScreen(memberId: p.memberId)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ar = isArabic(ref);
    final people = ref.watch(peopleProvider);
    final lists = ref.watch(listsProvider).valueOrNull ?? const <ContactList>[];
    final permOk = ref.watch(permissionsProvider).valueOrNull ?? true;
    final syncStatus = ref.watch(syncStatusProvider);
    final filter = ref.watch(filterProvider);
    final active = lists.any((l) => l.id == filter) ? filter : null;
    final muted = tt.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final sentences = ref.watch(sentencesProvider).valueOrNull ?? const <String>[];
    final stats = ref.watch(statsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'Wisal', 'وصال'))),
      body: people.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final now = DateTime.now();
          final visible = active == null ? all : all.where((p) => p.listId == active).toList();
          final overdue = ReminderEngine.overdue(visible, now);
          final rest = visible.where((p) => !overdue.contains(p)).toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          return RefreshIndicator(
            onRefresh: () => syncNow(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(WSpace.lg, 0, WSpace.lg, WSpace.xl),
              children: [
                if (!permOk)
                  Card(
                    color: cs.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(WSpace.md),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr(ref, 'Allow contacts and call history access', 'اسمح بالوصول لجهات الاتصال وسجل المكالمات'),
                            style: tt.titleMedium),
                        const SizedBox(height: WSpace.xs),
                        Text(tr(ref, 'Needed to find your last call with each person.', 'مطلوب لمعرفة آخر اتصال بكل شخص.')),
                        const SizedBox(height: WSpace.sm),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton(
                            onPressed: () async {
                              if (!await Native.granted('contacts')) await Native.request('contacts');
                              if (!await Native.granted('callLog')) await Native.request('callLog');
                              await syncNow(ref);
                            },
                            child: Text(tr(ref, 'Allow', 'سماح')),
                          ),
                        ),
                      ]),
                    ),
                  ),
                const SizedBox(height: WSpace.sm),
                Text(_greeting(ar), style: tt.headlineSmall),
                const SizedBox(height: WSpace.xs),
                Text(
                  all.isEmpty
                      ? tr(ref, 'Add people to a list to get started', 'أضف أشخاصاً إلى قائمة للبدء')
                      : overdue.isEmpty
                          ? tr(ref, "You're all caught up", 'أنت على تواصل مع الجميع')
                          : ar
                              ? '${overdue.length} قد يكون هذا وقتاً مناسباً للسؤال عنهم'
                              : "${overdue.length} ${overdue.length == 1 ? 'person' : 'people'} — maybe it's a good time to check in",
                  style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (syncStatus.isNotEmpty) Text(syncStatus, style: muted),
                ValueListenableBuilder<bool>(
                  valueListenable: AppDatabase.instance.configDirty,
                  builder: (_, dirty, __) => dirty
                      ? Text(tr(ref, 'Reminders may be out of date. Retrying…', 'قد تكون التذكيرات قديمة. جارٍ إعادة المحاولة…'),
                          style: muted)
                      : const SizedBox.shrink(),
                ),
                if (sentences.isNotEmpty) ...[
                  const SizedBox(height: WSpace.md),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => DailySentenceScreen(sentence: QuoteOfDay.forToday(sentences)))),
                    child: Card(
                      color: wisalPrimaryLight,
                      child: Padding(
                        padding: const EdgeInsets.all(WSpace.md),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.eco, size: 22, color: wisalPrimary),
                          const SizedBox(width: WSpace.sm),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(tr(ref, "Today's reminder", 'تذكير اليوم'),
                                  style: tt.labelLarge?.copyWith(color: wisalPrimary, fontWeight: FontWeight.w600)),
                              const SizedBox(height: WSpace.xs),
                              Text(QuoteOfDay.forToday(sentences), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ],
                if (stats != null) ...[
                  const SizedBox(height: WSpace.md),
                  Row(children: [
                    Expanded(
                      child: _StatTile(
                          value: '${stats.last7}', label: tr(ref, 'Reached out', 'تم التواصل'), color: wisalPrimary),
                    ),
                    const SizedBox(width: WSpace.sm),
                    Expanded(
                      child: _StatTile(
                          value: '${overdue.length}', label: tr(ref, 'Overdue', 'متأخرون'), color: wisalWarning),
                    ),
                    const SizedBox(width: WSpace.sm),
                    Expanded(
                      child: _StatTile(
                          value: '${stats.last30}', label: tr(ref, 'This month', 'هذا الشهر'), color: wisalSecondary),
                    ),
                  ]),
                ],
                const SizedBox(height: WSpace.md),
                if (lists.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      ChoiceChip(
                        label: Text(tr(ref, 'All', 'الكل')),
                        selected: active == null,
                        onSelected: (_) => ref.read(filterProvider.notifier).state = null,
                      ),
                      for (final l in lists)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: WSpace.sm),
                          child: ChoiceChip(
                            label: Text(l.name),
                            selected: active == l.id,
                            onSelected: (_) => ref.read(filterProvider.notifier).state = l.id,
                          ),
                        ),
                    ]),
                  ),
                const SizedBox(height: WSpace.md),
                if (all.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: WSpace.xxl),
                    child: Column(children: [
                      Icon(Icons.group_add_outlined, size: 56, color: cs.outline),
                      const SizedBox(height: WSpace.md),
                      FilledButton.tonal(onPressed: widget.onOpenLists, child: Text(tr(ref, 'Open lists', 'فتح القوائم'))),
                    ]),
                  )
                else if (overdue.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: WSpace.xl),
                    child: Column(children: [
                      const Icon(Icons.check_circle_outline, size: 48, color: wisalPrimary),
                      const SizedBox(height: WSpace.md),
                      Text(tr(ref, "You're all caught up today", 'أمورك تمام اليوم'), style: tt.titleMedium),
                      const SizedBox(height: WSpace.xs),
                      Text(
                          tr(ref, "You've recently reached out to everyone you're keeping up with.",
                              'لقد تواصلت مؤخراً مع كل الأشخاص الذين تتابعهم.'),
                          textAlign: TextAlign.center,
                          style: muted),
                      const SizedBox(height: WSpace.md),
                      OutlinedButton(onPressed: widget.onOpenLists, child: Text(tr(ref, 'View lists', 'عرض القوائم'))),
                    ]),
                  ),
                for (final p in overdue)
                  Card(
                    margin: const EdgeInsets.only(bottom: WSpace.sm),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openPerson(p),
                      child: Padding(
                        padding: const EdgeInsets.all(WSpace.md),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            InitialAvatar(name: p.name),
                            const SizedBox(width: WSpace.md),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Flexible(
                                    child: Text(p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: tt.titleMedium),
                                  ),
                                  if (p.isKin) ...[
                                    const SizedBox(width: WSpace.xs),
                                    StatusBadge(label: tr(ref, 'Kin', 'الأرحام'), kind: BadgeKind.kin),
                                  ],
                                ]),
                                const SizedBox(height: 2),
                                Text(
                                  '${ReminderEngine.directionGlyph(p)}${ReminderEngine.ago(ReminderEngine.daysSince(p, now), ar: ar)} · ${p.listName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: muted,
                                ),
                              ]),
                            ),
                            const SizedBox(width: WSpace.sm),
                            StatusBadge(
                                label:
                                    '${ReminderEngine.daysSince(p, now) ?? p.days} ${tr(ref, 'd', 'يوم')}',
                                kind: BadgeKind.overdue),
                          ]),
                          const SizedBox(height: WSpace.sm),
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            OutlinedButton.icon(
                              onPressed: () => _snooze(p),
                              icon: const Icon(Icons.snooze, size: 18),
                              label: Text(tr(ref, 'Snooze', 'تأجيل')),
                            ),
                            const SizedBox(width: WSpace.sm),
                            FilledButton.icon(
                              onPressed: () => callWithNudge(context, ref, p),
                              icon: const Icon(Icons.call, size: 18),
                              label: Text(tr(ref, 'Call', 'اتصال')),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                if (rest.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text('${tr(ref, 'Everyone else', 'البقية')} (${rest.length})',
                        style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant)),
                    children: [
                      for (final p in rest)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: InitialAvatar(name: p.name, radius: 18),
                          title: Row(children: [
                            Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                            if (p.isKin) ...[
                              const SizedBox(width: WSpace.xs),
                              StatusBadge(label: tr(ref, 'Kin', 'الأرحام'), kind: BadgeKind.kin),
                            ],
                          ]),
                          subtitle: Text(
                            '${ReminderEngine.directionGlyph(p)}${ReminderEngine.statusText(p, now, ar: ar)} · ${p.listName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _openPerson(p),
                        ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: WSpace.md, horizontal: WSpace.xs),
        child: Column(children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}
