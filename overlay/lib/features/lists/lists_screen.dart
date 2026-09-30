import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../core/database/app_database.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import 'list_detail_screen.dart';

Future<(String, int, bool)?> showListDialog(BuildContext context, WidgetRef ref, {ContactList? list}) {
  final name = TextEditingController(text: list?.name ?? '');
  final days = TextEditingController(text: '${list?.days ?? 14}');
  final isKin = ValueNotifier<bool>(list?.isKin ?? false);
  return showDialog<(String, int, bool)>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(list == null ? tr(ref, 'New list', 'قائمة جديدة') : tr(ref, 'Edit list', 'تعديل القائمة')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: InputDecoration(labelText: tr(ref, 'Name', 'الاسم'))),
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
            subtitle: Text(tr(ref, 'Shorter default reminder, shown with a kin badge', 'تذكير أقصر افتراضياً، وتظهر بشارة خاصة')),
            onChanged: (v) => setState(() {
              isKin.value = v ?? false;
              if (v == true && list == null) days.text = '3';
            }),
          ),
        ]),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final r = await showListDialog(context, ref);
          if (r != null) {
            await AppDatabase.instance.addList(r.$1, r.$2, isKin: r.$3);
            ref.invalidate(listsProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: lists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (ls) => ListView(children: [
          for (final l in ls)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: l.isKin ? kinGold.withValues(alpha: 0.25) : Theme.of(context).colorScheme.primaryContainer,
                child: Icon(l.isKin ? Icons.family_restroom : Icons.group_outlined,
                    color: l.isKin ? kinGold : Theme.of(context).colorScheme.onPrimaryContainer),
              ),
              title: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text(l.name, overflow: TextOverflow.ellipsis)),
                if (l.isKin) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: kinGold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text(tr(ref, 'Kin', 'رحم'), style: TextStyle(fontSize: 11, color: kinGold, fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              subtitle: Text(
                  '${tr(ref, 'Every', 'كل')} ${l.days} ${tr(ref, 'days', 'يوم')} · ${l.count} ${l.count == 1 ? tr(ref, 'person', 'شخص') : tr(ref, 'people', 'أشخاص')}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ListDetailScreen(listId: l.id)));
                ref.invalidate(listsProvider);
              },
            ),
        ]),
      ),
    );
  }
}
