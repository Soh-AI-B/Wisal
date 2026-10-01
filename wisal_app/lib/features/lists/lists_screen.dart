import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'list_detail_screen.dart';

/// Create-only dialog (editing an existing list now happens on its "Settings" tab, see
/// [ListDetailScreen]). Returns (name, days, isKin) on save.
Future<(String, int, bool)?> showListDialog(BuildContext context, WidgetRef ref) {
  final name = TextEditingController();
  final days = TextEditingController(text: '14');
  final isKin = ValueNotifier<bool>(false);
  return showDialog<(String, int, bool)>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(tr(ref, 'New list', 'قائمة جديدة')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, autofocus: true, decoration: InputDecoration(labelText: tr(ref, 'Name', 'الاسم'))),
            TextField(
              controller: days,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr(ref, 'Remind after (days)', 'التذكير بعد (أيام)')),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: isKin.value,
              title: Text(tr(ref, 'Kin list (الأرحام)', 'قائمة أرحام')),
              subtitle: Text(
                  tr(ref, 'Shorter default reminder, shown with a kin badge', 'تذكير أقصر افتراضياً، وتظهر بشارة خاصة')),
              onChanged: (v) => setState(() {
                isKin.value = v ?? false;
                if (v == true) days.text = '3';
              }),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(ref, 'Cancel', 'إلغاء'))),
          FilledButton(
            onPressed: () {
              final n = name.text.trim();
              final d = int.tryParse(days.text.trim()) ?? 0;
              if (n.isEmpty || d < 1) return;
              Navigator.pop(ctx, (n, d, isKin.value));
            },
            child: Text(tr(ref, 'Save', 'حفظ')),
          ),
        ],
      );
    }),
  );
}

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'My Lists', 'قوائمي'))),
      body: lists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (ls) => ls.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(WSpace.xl),
                  child: Text(tr(ref, 'No lists yet — tap + to create one', 'لا توجد قوائم بعد — اضغط + لإنشاء واحدة'),
                      textAlign: TextAlign.center),
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: WSpace.sm),
                children: [
                  for (final l in ls)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: listColorFor(l).withValues(alpha: 0.15),
                        child: Icon(listIconFor(l), color: listColorFor(l)),
                      ),
                      title: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(child: Text(l.name, overflow: TextOverflow.ellipsis)),
                        if (l.isKin) ...[
                          const SizedBox(width: WSpace.xs),
                          Flexible(child: StatusBadge(label: tr(ref, 'Kin', 'الأرحام'), kind: BadgeKind.kin)),
                        ],
                      ]),
                      subtitle: Text(
                          '${tr(ref, 'Every', 'كل')} ${l.days} ${tr(ref, 'days', 'يوم')} · ${l.count} ${l.count == 1 ? tr(ref, 'person', 'شخص') : tr(ref, 'people', 'أشخاص')}'),
                      trailing: CircleAvatar(
                        radius: 14,
                        backgroundColor: listColorFor(l).withValues(alpha: 0.15),
                        child: Text('${l.count}', style: TextStyle(color: listColorFor(l), fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => ListDetailScreen(listId: l.id)));
                        ref.invalidate(listsProvider);
                      },
                    ),
                ],
              ),
      ),
    );
  }
}
