import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'i18n.dart';
import 'models.dart';
import 'sentences.dart';

/// Shows a short motivational sentence before dialing — the "gentle nudge" — then places the call
/// if confirmed. Shared by the Home overdue cards and the Person Details screen.
Future<void> callWithNudge(BuildContext context, WidgetRef ref, Person p) async {
  final n = p.phone?.replaceAll(RegExp(r'[^0-9+]'), '');
  if (n == null || n.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'No number found for this contact', 'لم يتم العثور على رقم لهذا الشخص'))));
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
