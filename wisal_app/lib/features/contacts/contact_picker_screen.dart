import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/platform/native_bridge.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

class ContactPickerScreen extends ConsumerStatefulWidget {
  const ContactPickerScreen({super.key, required this.listId});
  final int listId;

  @override
  ConsumerState<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends ConsumerState<ContactPickerScreen> {
  List<PhoneContact> _all = [];
  Map<String, String> _sel = {};
  String _q = '';
  bool _loading = true;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ok = await Native.granted('contacts') || await Native.request('contacts');
    if (!ok) {
      if (mounted) {
        setState(() {
          _denied = true;
          _loading = false;
        });
      }
      return;
    }
    final contacts = await Native.listContacts();
    final sel = await AppDatabase.instance.membersOf(widget.listId);
    final names = {for (final c in contacts) c.key: c.name};
    sel.updateAll((k, old) => names[k] ?? old);
    if (!mounted) return;
    setState(() {
      _all = contacts;
      _sel = sel;
      _loading = false;
    });
  }

  Future<void> _done() async {
    await AppDatabase.instance.setMembers(widget.listId, _sel);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _q.isEmpty ? _all : _all.where((c) => c.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'Add people', 'إضافة أشخاص')), actions: [
        TextButton(onPressed: _loading || _denied ? null : _done, child: Text(tr(ref, 'Done', 'تم'))),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _denied
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                        tr(ref, 'Contacts permission is needed to pick people. Allow it in the phone settings.',
                            'إذن جهات الاتصال مطلوب لاختيار الأشخاص. فعّله من إعدادات الهاتف.'),
                        textAlign: TextAlign.center),
                  ),
                )
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: tr(ref, 'Search...', 'بحث...'),
                          border: const OutlineInputBorder()),
                      onChanged: (v) => setState(() => _q = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final c = shown[i];
                        final selected = _sel.containsKey(c.key);
                        return ListTile(
                          leading: InitialAvatar(name: c.name, radius: 20),
                          title: Text(c.name, overflow: TextOverflow.ellipsis),
                          trailing: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() {
                              if (selected) {
                                _sel.remove(c.key);
                              } else {
                                _sel[c.key] = c.name;
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: wisalPrimaryLight, borderRadius: BorderRadius.circular(10)),
                              child: Icon(selected ? Icons.check : Icons.add, color: wisalPrimary, size: 20),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
    );
  }
}
