import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/providers.dart';
import '../features/home/home_screen.dart';
import '../features/lists/lists_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';

// Clean Material 3 look: Google Contacts layout (avatars, flat lists) with a deep-emerald صلة الرحم accent.
ThemeData _theme(Brightness b) {
  final cs = ColorScheme.fromSeed(seedColor: const Color(0xFF0F6B4C), brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: cs.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: cs.primaryContainer,
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
  );
}

/// Warm gold accent for kin badges and the daily-quote card, alongside the emerald seed above.
const kinGold = Color(0xFFD4A657);

class WisalApp extends ConsumerWidget {
  const WisalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = isArabic(ref);
    return MaterialApp(
      title: 'Wisal',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
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

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _i, children: [
          HomeScreen(onOpenLists: () => setState(() => _i = 1)),
          const ListsScreen(),
          const SettingsScreen(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: tr(ref, 'Home', 'الرئيسية')),
            NavigationDestination(
                icon: const Icon(Icons.list_alt_outlined),
                selectedIcon: const Icon(Icons.list_alt),
                label: tr(ref, 'Lists', 'القوائم')),
            NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: tr(ref, 'Settings', 'الإعدادات')),
          ],
        ),
      );
}
