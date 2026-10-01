import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';

/// "ذكّرني لاحقاً" bottom sheet: quick presets plus a custom date. Returns the chosen
/// [DateTime] (snooze-until), or null if dismissed.
Future<DateTime?> showSnoozeSheet(BuildContext context, WidgetRef ref) {
  DateTime? picked;
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(tr(ref, 'Remind me later', 'ذكّرني لاحقاً'),
                style: Theme.of(ctx).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            for (final choice in [
              (tr(ref, 'Tomorrow', 'غداً'), 1),
              (tr(ref, 'After 3 days', 'بعد 3 أيام'), 3),
              (tr(ref, 'After a week', 'بعد أسبوع'), 7),
            ])
              ListTile(
                title: Text(choice.$1),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(ctx, DateTime.now().add(Duration(days: choice.$2))),
              ),
            ListTile(
              title: Text(tr(ref, 'Pick a date', 'اختيار تاريخ')),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                picked = d;
                if (ctx.mounted && d != null) Navigator.pop(ctx, d);
              },
            ),
          ]),
        ),
      ),
    ),
  ).then((v) => v ?? picked);
}
