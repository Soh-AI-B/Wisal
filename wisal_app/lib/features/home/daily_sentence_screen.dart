import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';

class DailySentenceScreen extends ConsumerWidget {
  const DailySentenceScreen({super.key, required this.sentence});
  final String sentence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, "Today's reminder", 'تذكير اليوم'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(WSpace.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.eco, size: 48, color: wisalPrimary),
            const SizedBox(height: WSpace.lg),
            Text(sentence, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: WSpace.xxl),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              OutlinedButton.icon(
                onPressed: () => Share.share(sentence),
                icon: const Icon(Icons.share_outlined),
                label: Text(tr(ref, 'Share', 'مشاركة')),
              ),
              const SizedBox(width: WSpace.md),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: sentence));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(tr(ref, 'Copied', 'تم النسخ'))));
                },
                icon: const Icon(Icons.copy_outlined),
                label: Text(tr(ref, 'Copy', 'نسخ')),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
