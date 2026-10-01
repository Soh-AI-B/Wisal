import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/i18n.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../features/home/home_screen.dart';
import '../features/lists/lists_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/stats_screen.dart';

class WisalApp extends ConsumerWidget {
  const WisalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = isArabic(ref);
    return MaterialApp(
      title: 'Wisal',
      debugShowCheckedModeBanner: false,
      theme: wisalTheme(Brightness.light, ar),
      darkTheme: wisalTheme(Brightness.dark, ar),
      locale: Locale(ar ? 'ar' : 'en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ref.watch(onboardingCompleteProvider).when(
            data: (done) => done
                ? const Shell()
                : OnboardingScreen(onDone: () => ref.invalidate(onboardingCompleteProvider)),
            loading: () => const Scaffold(body: SizedBox.shrink()),
            error: (_, __) => const Shell(),
          ),
    );
  }
}

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  int _i = 0;

  Future<void> _addList() async {
    final r = await showListDialog(context, ref);
    if (r != null) {
      await AppDatabase.instance.addList(r.$1, r.$2, isKin: r.$3);
      ref.invalidate(listsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget navIcon(int index, IconData outline, IconData filled, String label) {
      final selected = _i == index;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _i = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: WSpace.xs),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(selected ? filled : outline, size: 22, color: selected ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(fontSize: 11, color: selected ? cs.primary : cs.onSurfaceVariant)),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _i, children: [
        HomeScreen(onOpenLists: () => setState(() => _i = 1)),
        const ListsScreen(),
        const StatsScreen(),
        const SettingsScreen(),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _addList,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        child: Row(children: [
          navIcon(0, Icons.home_outlined, Icons.home, tr(ref, 'Home', 'الرئيسية')),
          navIcon(1, Icons.list_alt_outlined, Icons.list_alt, tr(ref, 'Lists', 'القوائم')),
          const Spacer(), // notch for the docked Add FAB
          navIcon(2, Icons.bar_chart_outlined, Icons.bar_chart, tr(ref, 'Stats', 'الإحصائيات')),
          navIcon(3, Icons.settings_outlined, Icons.settings, tr(ref, 'Settings', 'الإعدادات')),
        ]),
      ),
    );
  }
}
