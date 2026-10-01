import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/reminder/reminder_engine.dart';
import '../../core/theme.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  Widget _tile(BuildContext context, String value, String label, Color color) {
    return Expanded(
      child: Card(
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WSpace.lg, horizontal: WSpace.sm),
          child: Column(children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: WSpace.xs),
            Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = isArabic(ref);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final detailed = ref.watch(statsDetailedProvider).valueOrNull;
    final people = ref.watch(peopleProvider).valueOrNull ?? const <Person>[];
    final now = DateTime.now();

    final total = people.length;
    final overdue = ReminderEngine.overdue(people, now).length;
    final snoozed = people.where((p) => ReminderEngine.status(p, now) == ReminderStatus.snoozed).length;
    final caughtUp = total - overdue;
    final caughtUpPct = total == 0 ? 0 : (caughtUp * 100 / total).round();

    // Best list: highest caught-up percentage among lists with at least one person.
    final byList = <String, List<Person>>{};
    for (final p in people) {
      byList.putIfAbsent(p.listName, () => []).add(p);
    }
    String? bestList;
    var bestPct = -1;
    for (final entry in byList.entries) {
      final list = entry.value;
      final od = ReminderEngine.overdue(list, now).length;
      final pct = list.isEmpty ? 0 : ((list.length - od) * 100 / list.length).round();
      if (pct > bestPct) {
        bestPct = pct;
        bestList = entry.key;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'Reconnect stats', 'إحصائياتك'))),
      body: ListView(padding: const EdgeInsets.all(WSpace.lg), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(WSpace.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(ref, 'This week', 'هذا الأسبوع'), style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: WSpace.xs),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${detailed?.last7 ?? 0}', style: tt.headlineSmall?.copyWith(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(width: WSpace.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(tr(ref, 'people reconnected with', 'شخصاً تم التواصل معهم')),
                ),
              ]),
              if (detailed != null) ...[
                const SizedBox(height: WSpace.xs),
                Builder(builder: (context) {
                  final delta = detailed.last7 - detailed.prevWeek;
                  if (delta == 0) return const SizedBox.shrink();
                  final up = delta > 0;
                  return Row(children: [
                    Icon(up ? Icons.trending_up : Icons.trending_down, size: 16, color: up ? wisalPrimary : wisalWarning),
                    const SizedBox(width: 4),
                    Text(
                        ar ? '${up ? '+' : ''}$delta مقارنة بالأسبوع الماضي' : '${up ? '+' : ''}$delta vs. last week',
                        style: tt.bodySmall),
                  ]);
                }),
              ],
            ]),
          ),
        ),
        const SizedBox(height: WSpace.lg),
        Row(children: [
          _tile(context, '$caughtUpPct%', tr(ref, 'Committed', 'ملتزم بالتواصل'), wisalPrimary),
          const SizedBox(width: WSpace.sm),
          _tile(context, '$overdue', tr(ref, 'Due now', 'حان وقت التواصل'), wisalWarning),
          const SizedBox(width: WSpace.sm),
          _tile(context, '$snoozed', tr(ref, 'Snoozed', 'مؤجل'), wisalSecondary),
        ]),
        const SizedBox(height: WSpace.xl),
        Text(tr(ref, 'Last 7 days', 'آخر 7 أيام'), style: tt.titleMedium),
        const SizedBox(height: WSpace.md),
        if (detailed != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final c in detailed.dailyCounts)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('$c', style: tt.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Container(
                        height: 8.0 + (c.clamp(0, 10)) * 6,
                        decoration:
                            BoxDecoration(color: wisalPrimary.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4)),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        if (bestList != null && bestPct > 0) ...[
          const SizedBox(height: WSpace.xl),
          Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events_outlined, color: wisalSecondary),
              title: Text(tr(ref, 'Best list', 'أفضل قائمة تواصل')),
              subtitle: Text('$bestList — $bestPct%'),
            ),
          ),
        ],
      ]),
    );
  }
}
