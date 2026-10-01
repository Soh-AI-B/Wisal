import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/call_nudge.dart';
import '../../core/database/app_database.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/reminder/reminder_engine.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'snooze_sheet.dart';

class PersonDetailScreen extends ConsumerWidget {
  const PersonDetailScreen({super.key, required this.memberId});
  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = isArabic(ref);
    final people = ref.watch(peopleProvider).valueOrNull ?? const <Person>[];
    final p = people.where((e) => e.memberId == memberId).firstOrNull;
    if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final now = DateTime.now();
    final at = p.lastCallAt;

    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: ListView(
        padding: const EdgeInsets.all(WSpace.lg),
        children: [
          Center(
            child: Column(children: [
              InitialAvatar(name: p.name, radius: 40),
              const SizedBox(height: WSpace.sm),
              Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
              if (p.isKin) ...[
                const SizedBox(height: WSpace.xs),
                StatusBadge(label: tr(ref, 'Kin', 'الأرحام'), kind: BadgeKind.kin),
              ],
            ]),
          ),
          const SizedBox(height: WSpace.xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: WSpace.lg, vertical: WSpace.sm),
              child: Column(children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(ref, 'Last call', 'آخر مكالمة')),
                  subtitle: at == null
                      ? Text(tr(ref, 'No call found', 'لا يوجد اتصال'))
                      : Text(
                          '${DateTime.fromMillisecondsSinceEpoch(at).day}/${DateTime.fromMillisecondsSinceEpoch(at).month}/${DateTime.fromMillisecondsSinceEpoch(at).year} '
                          '• ${ReminderEngine.ago(ReminderEngine.daysSince(p, now), ar: ar)}'
                          '${p.direction != null ? ' • ${ReminderEngine.directionLabel(p, ar: ar)}' : ''}',
                        ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(ref, 'List', 'القائمة')),
                  trailing: Text(p.listName),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(ref, 'Remind after', 'التذكير بعد')),
                  trailing: Text('${p.days} ${tr(ref, 'days', 'يوم')}'),
                ),
              ]),
            ),
          ),
          const SizedBox(height: WSpace.lg),
          FilledButton.icon(
            onPressed: () => callWithNudge(context, ref, p),
            icon: const Icon(Icons.call),
            label: Text(tr(ref, 'Call', 'اتصال')),
          ),
          const SizedBox(height: WSpace.lg),
          Card(
            child: Column(children: [
              ListTile(
                leading: CircleAvatar(
                    backgroundColor: wisalSecondary.withValues(alpha: 0.15),
                    child: const Icon(Icons.snooze, color: wisalSecondary)),
                title: Text(tr(ref, 'Snooze reminder', 'تأجيل التذكير')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final until = await showSnoozeSheet(context, ref);
                  if (until == null) return;
                  await AppDatabase.instance.snooze(p.memberId, until);
                  await syncNow(ref);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: wisalPrimaryLight, child: Icon(Icons.notes_outlined, color: wisalPrimary)),
                title: Text(tr(ref, 'Notes', 'ملاحظات')),
                subtitle: p.notes?.isNotEmpty == true ? Text(p.notes!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final controller = TextEditingController(text: p.notes ?? '');
                  final saved = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(tr(ref, 'Notes', 'ملاحظات')),
                      content: SingleChildScrollView(
                        child: TextField(controller: controller, maxLines: 4, autofocus: true),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(ref, 'Cancel', 'إلغاء'))),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(ref, 'Save', 'حفظ'))),
                      ],
                    ),
                  );
                  if (saved == true) {
                    await AppDatabase.instance.setNote(p.memberId, controller.text.trim());
                    await syncNow(ref);
                  }
                },
              ),
            ]),
          ),
          const SizedBox(height: WSpace.lg),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: wisalWarning, side: const BorderSide(color: wisalWarning)),
            onPressed: () async {
              await AppDatabase.instance.removeMember(p.memberId);
              await syncNow(ref);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline),
            label: Text(tr(ref, 'Remove from list', 'إزالة من القائمة')),
          ),
        ],
      ),
    );
  }
}
