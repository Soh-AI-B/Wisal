import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app.dart';
import '../../core/database/app_database.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/platform/native_bridge.dart';
import '../../core/providers.dart';
import '../../core/reminder/reminder_engine.dart';
import '../../core/sentences.dart';
import '../../core/ui.dart';

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

  Future<void> _call(Person p) async {
    final n = p.phone?.replaceAll(RegExp(r'[^0-9+]'), '');
    if (n == null || n.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(ref, 'No number found for this contact', 'لم يتم العثور على رقم لهذا الشخص'))));
      return;
    }
    final sentences = ref.read(sentencesProvider).valueOrNull ?? const <String>[];
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${tr(ref, 'Call', 'اتصال بـ')} ${p.name}'),
        content: sentences.isEmpty ? null : Text(QuoteOfDay.random(sentences), textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(ref, 'Cancel', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(ref, 'Call now', 'اتصل الآن'))),
        ],
      ),
    );
    if (go == true) await launchUrl(Uri(scheme: 'tel', path: n));
  }

  Future<void> _snooze(Person p, int days) async {
    await AppDatabase.instance.snooze(p.memberId, DateTime.now().add(Duration(days: days)));
    await syncNow(ref);
  }

  Widget _kinBadge(WidgetRef ref) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: kinGold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
        child: Text(tr(ref, 'Kin', 'رحم'), style: const TextStyle(fontSize: 11, color: kinGold, fontWeight: FontWeight.w600)),
      );

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
          final caughtUp = visible.length - overdue.length;

          return RefreshIndicator(
            onRefresh: () => syncNow(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (!permOk)
                  Card(
                    elevation: 0,
                    color: cs.secondaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      title: Text(tr(ref, 'Allow contacts and call history access', 'اسمح بالوصول لجهات الاتصال وسجل المكالمات')),
                      subtitle: Text(tr(ref, 'Needed to find your last call with each person.', 'مطلوب لمعرفة آخر اتصال بكل شخص.')),
                      trailing: FilledButton(
                        onPressed: () async {
                          if (!await Native.granted('contacts')) await Native.request('contacts');
                          if (!await Native.granted('callLog')) await Native.request('callLog');
                          await syncNow(ref);
                        },
                        child: Text(tr(ref, 'Allow', 'سماح')),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(_greeting(ar), style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  all.isEmpty
                      ? tr(ref, 'Add people to a list to get started', 'أضف أشخاصاً إلى قائمة للبدء')
                      : overdue.isEmpty
                          ? tr(ref, "You're all caught up", 'أنت على تواصل مع الجميع')
                          : '${overdue.length} ${tr(ref, overdue.length == 1 ? 'person' : 'people', 'أشخاص')} ${tr(ref, 'to reconnect with', 'بانتظار تواصلك')}',
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
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: kinGold.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.volunteer_activism, size: 18, color: kinGold),
                          const SizedBox(width: 6),
                          Text(tr(ref, "Today's reminder", 'تذكير اليوم'),
                              style: tt.labelLarge?.copyWith(color: kinGold, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 8),
                        Text(QuoteOfDay.forToday(sentences), textAlign: TextAlign.start),
                      ]),
                    ),
                  ),
                ],
                if (stats != null && (stats.last7 > 0 || stats.last30 > 0 || visible.isNotEmpty)) ...[
                  const SizedBox(height: 10),
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerLow,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Icon(Icons.favorite_outline, size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ar
                                ? '$caughtUp من ${visible.length} على تواصل · ${stats.last7} تواصل هذا الأسبوع · ${stats.last30} هذا الشهر'
                                : '$caughtUp/${visible.length} caught up · ${stats.last7} reconnected this week · ${stats.last30} this month',
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
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
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(l.name),
                            selected: active == l.id,
                            onSelected: (_) => ref.read(filterProvider.notifier).state = l.id,
                          ),
                        ),
                    ]),
                  ),
                const SizedBox(height: 12),
                if (all.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Column(children: [
                      Icon(Icons.group_add_outlined, size: 56, color: cs.outline),
                      const SizedBox(height: 12),
                      FilledButton.tonal(onPressed: widget.onOpenLists, child: Text(tr(ref, 'Open lists', 'فتح القوائم'))),
                    ]),
                  ),
                for (final p in overdue)
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerLow,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                      leading: InitialAvatar(name: p.name),
                      title: Row(children: [
                        Flexible(
                          child: Text(p.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        if (p.isKin) _kinBadge(ref),
                      ]),
                      subtitle: Text.rich(TextSpan(children: [
                        TextSpan(
                            text:
                                '${ReminderEngine.directionGlyph(p)}${ReminderEngine.ago(ReminderEngine.daysSince(p, now), ar: ar)}',
                            style: TextStyle(color: cs.error, fontWeight: FontWeight.w500)),
                        TextSpan(text: ' · ${p.listName}'),
                      ])),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton.filledTonal(
                            tooltip: tr(ref, 'Call', 'اتصال'), onPressed: () => _call(p), icon: const Icon(Icons.call)),
                        PopupMenuButton<int>(
                          tooltip: tr(ref, 'Snooze', 'تأجيل'),
                          icon: const Icon(Icons.snooze),
                          onSelected: (d) => _snooze(p, d),
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 1, child: Text(tr(ref, 'Tomorrow', 'غداً'))),
                            PopupMenuItem(value: 7, child: Text(tr(ref, '1 week', 'أسبوع'))),
                            PopupMenuItem(value: 30, child: Text(tr(ref, '1 month', 'شهر'))),
                          ],
                        ),
                      ]),
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
                            if (p.isKin) _kinBadge(ref),
                          ]),
                          subtitle: Text(
                              '${ReminderEngine.directionGlyph(p)}${ReminderEngine.statusText(p, now, ar: ar)} · ${p.listName}'),
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
