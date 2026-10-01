import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/platform/native_bridge.dart';
import '../../core/providers.dart';
import '../../core/reminder/reminder_engine.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../contacts/contact_picker_screen.dart';
import 'person_detail_screen.dart';

class ListDetailScreen extends ConsumerStatefulWidget {
  const ListDetailScreen({super.key, required this.listId});
  final int listId;

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => ContactPickerScreen(listId: widget.listId)));
    if (ok == true) {
      await Native.request('notifications');
      await syncNow(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsProvider).valueOrNull ?? const <ContactList>[];
    final list = lists.where((l) => l.id == widget.listId).firstOrNull;
    if (list == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final now = DateTime.now();
    final members = (ref.watch(peopleProvider).valueOrNull ?? const <Person>[])
        .where((p) => p.listId == widget.listId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        bottom: TabBar(controller: _tabs, tabs: [
          Tab(text: '${tr(ref, 'Members', 'الأشخاص')} (${members.length})'),
          Tab(text: tr(ref, 'Settings', 'الإعدادات')),
        ]),
      ),
      body: TabBarView(controller: _tabs, children: [
        Column(children: [
          Padding(
            padding: const EdgeInsets.all(WSpace.md),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                  onPressed: () => _add(context, ref),
                  icon: const Icon(Icons.person_add),
                  label: Text(tr(ref, 'Add people', 'إضافة أشخاص'))),
            ),
          ),
          Expanded(
            child: members.isEmpty
                ? Center(child: Text(tr(ref, 'No one here yet', 'لا يوجد أحد هنا بعد')))
                : ListView(children: [
                    for (final p in members)
                      ListTile(
                        leading: InitialAvatar(name: p.name, radius: 20),
                        title: Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                        ]),
                        subtitle: Text(
                            '${ReminderEngine.directionGlyph(p)}${ReminderEngine.statusText(p, now, ar: isArabic(ref))}'),
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => PersonDetailScreen(memberId: p.memberId))),
                      ),
                  ]),
          ),
        ]),
        _ListSettingsTab(list: list),
      ]),
    );
  }
}

class _ListSettingsTab extends ConsumerWidget {
  const _ListSettingsTab({required this.list});
  final ContactList list;

  static const _presets = [
    ('people', 'green'),
    ('heart', 'purple'),
    ('star', 'orange'),
    ('briefcase', 'warm'),
    ('home', 'green'),
  ];

  Future<void> _apply(WidgetRef ref,
      {String? name, int? days, bool? isKin, String? color, String? icon}) async {
    await AppDatabase.instance.updateList(
      list.id,
      name ?? list.name,
      days ?? list.days,
      isKin: isKin ?? list.isKin,
      color: color ?? list.color,
      icon: icon ?? list.icon,
    );
    await syncNow(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(padding: const EdgeInsets.all(WSpace.lg), children: [
      Center(
        child: Column(children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: listColorFor(list).withValues(alpha: 0.15),
            child: Icon(listIconFor(list), color: listColorFor(list), size: 28),
          ),
          const SizedBox(height: WSpace.sm),
          Text(list.name, style: Theme.of(context).textTheme.titleLarge),
          if (list.isKin) ...[
            const SizedBox(height: WSpace.xs),
            StatusBadge(label: tr(ref, 'Kin', 'الأرحام'), kind: BadgeKind.kin),
          ],
        ]),
      ),
      const SizedBox(height: WSpace.xl),
      Card(
        child: Column(children: [
          SwitchListTile(
            title: Text(tr(ref, 'Mark as kin list (صلة الرحم)', 'وضع كقائمة أرحام (صلة الرحم)')),
            value: list.isKin,
            onChanged: (v) => _apply(ref, isKin: v),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(tr(ref, 'Remind after', 'مدة التذكير')),
            trailing: Text('${list.days} ${tr(ref, 'days', 'يوم')}'),
            onTap: () async {
              final controller = TextEditingController(text: '${list.days}');
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(tr(ref, 'Remind after', 'مدة التذكير')),
                  content: SingleChildScrollView(
                    child: TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(suffixText: tr(ref, 'days', 'يوم'))),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(ref, 'Cancel', 'إلغاء'))),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(ref, 'Save', 'حفظ'))),
                  ],
                ),
              );
              final d = int.tryParse(controller.text.trim());
              if (ok == true && d != null && d > 0) await _apply(ref, days: d);
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(tr(ref, 'List name', 'الاسم')),
            trailing: Text(list.name),
            onTap: () async {
              final controller = TextEditingController(text: list.name);
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(tr(ref, 'List name', 'الاسم')),
                  content: SingleChildScrollView(child: TextField(controller: controller, autofocus: true)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(ref, 'Cancel', 'إلغاء'))),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(ref, 'Save', 'حفظ'))),
                  ],
                ),
              );
              final n = controller.text.trim();
              if (ok == true && n.isNotEmpty) await _apply(ref, name: n);
            },
          ),
        ]),
      ),
      const SizedBox(height: WSpace.lg),
      Text(tr(ref, 'Color & icon', 'اللون والأيقونة'), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: WSpace.sm),
      Wrap(spacing: WSpace.sm, runSpacing: WSpace.sm, children: [
        for (final preset in _presets)
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _apply(ref, icon: preset.$1, color: preset.$2),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: (listColors[preset.$2] ?? wisalPrimary).withValues(alpha: 0.15),
              child: Icon(listIcons[preset.$1], color: listColors[preset.$2] ?? wisalPrimary),
            ),
          ),
      ]),
      const SizedBox(height: WSpace.xl),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: wisalWarning, side: const BorderSide(color: wisalWarning)),
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
        icon: const Icon(Icons.delete_outline),
        label: Text(tr(ref, 'Delete list', 'حذف القائمة')),
      ),
    ]);
  }
}
