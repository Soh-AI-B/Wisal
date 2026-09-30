import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/platform/native_bridge.dart';
import '../../core/providers.dart';
import '../../core/reminder/reminder_engine.dart';
import '../../core/ui.dart';
import '../contacts/contact_picker_screen.dart';
import 'lists_screen.dart';

class ListDetailScreen extends ConsumerWidget {
  const ListDetailScreen({super.key, required this.listId});
  final int listId;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => ContactPickerScreen(listId: listId)));
    if (ok == true) {
      await Native.request('notifications');
      await syncNow(ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsProvider).valueOrNull ?? const <ContactList>[];
    final list = lists.where((l) => l.id == listId).firstOrNull;
    if (list == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final now = DateTime.now();
    final members = (ref.watch(peopleProvider).valueOrNull ?? const <Person>[])
        .where((p) => p.listId == listId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: Text(list.name), actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final r = await showListDialog(context, ref, list: list);
            if (r != null) {
              await AppDatabase.instance.updateList(list.id, r.$1, r.$2, isKin: r.$3);
              await syncNow(ref);
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('${tr(ref, 'Delete', 'حذف')} "${list.name}"?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(ref, 'Cancel', 'إلغاء'))),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(ref, 'Delete', 'حذف'))),
                ],
              ),
            );
            if (ok == true) {
              await AppDatabase.instance.deleteList(list.id);
              await syncNow(ref);
              if (context.mounted) Navigator.pop(context);
            }
          },
        ),
      ]),
      body: ListView(children: [
        ListTile(
            title: Text(tr(ref, 'Remind me after', 'ذكرني بعد')),
            trailing: Text('${list.days} ${tr(ref, 'days', 'يوم')}')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
                onPressed: () => _add(context, ref),
                icon: const Icon(Icons.person_add),
                label: Text(tr(ref, 'Add people', 'إضافة أشخاص'))),
          ),
        ),
        for (final p in members)
          ListTile(
            leading: InitialAvatar(name: p.name, radius: 20),
            title: Text(p.name),
            subtitle:
                Text('${ReminderEngine.directionGlyph(p)}${ReminderEngine.statusText(p, now, ar: isArabic(ref))}'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                await AppDatabase.instance.removeMember(p.memberId);
                await syncNow(ref);
              },
            ),
          ),
      ]),
    );
  }
}
