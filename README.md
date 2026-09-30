# Wisal (وصال)

Local-first bilingual (English/Arabic) Android app that encourages صلة الرحم:
lists of people, per-list reminder days, last answered call from your real
call log, snooze, two independently-scheduled notifications (an overdue-
people reminder and a daily صلة الرحم sentence), a scrollable home-screen
widget, a daily quote and reconnect-stats card, and a "kin" list tier. No
account, no backend.

## Setup
```
./setup.sh
cd reconnect_app && flutter run
```
Release APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`

## Architecture
- Flutter (Riverpod + sqflite): UI, lists, snooze, reminder status, language
  toggle (`core/i18n.dart` — no ARB/codegen, just `tr(ref, en, ar)`).
- Kotlin, one MethodChannel (`wisal/native`): permissions, contacts, call-log
  read, number matching, WorkManager (every ~6h, data refresh only),
  `AlarmManager`-scheduled notifications, widget. Alarms and the worker run
  without the Flutter engine.
- Flutter mirrors lists/members/settings to native storage after every change
  (`AppDatabase.pushConfig`); native re-arms its alarms from that same config
  right after every save (`Alarms.rescheduleFromConfig`).
- صلة الرحم sentences (`sentences.md`) are bundled identically as a Flutter
  asset (`assets/sentences.txt`) and an Android raw resource
  (`res/raw/sentences.txt`) so the home card and the day's notification
  always pick the same sentence (`epochDay % count`).

## Tests
- Dart: `cd reconnect_app && flutter test`
- Kotlin (phone normalization): `cd reconnect_app/android && ./gradlew :app:testDebugUnitTest`

## Notes
- Android backup is disabled (`allowBackup=false` + extraction rules), so data stays on the device.
- Sync only overwrites the cache after a successful scan with both Contacts and Call log permissions; otherwise Home shows a permission banner and keeps the cached values.
- Answered calls = incoming/outgoing with duration ≥ 10s (`MIN_CALL_SECONDS` in `Sync.kt`). Shorter connects (missed pickup, voicemail bounce) don't count as a real conversation.
- The widget list scrolls (backed by `ReconnectWidgetService`/`RemoteViewsFactory`) and shows every overdue member, not just the first few.
- Each entry shows who called last: ↙ they called you, ↗ you called them (same in the widget and the Home screen).
- Contact names are always rendered left-to-right in the widget (`textDirection="ltr"`), so Arabic names don't flip to right alignment.
- Default country code for local numbers is 213 (Algeria): `PhoneNormalizer` in `Sync.kt`.
- WhatsApp/Telegram calls are not in the Android call log on virtually any device today, so they can't be included. (Android 16.1 introduces an OS-level unified call log that could someday expose them, but it needs both that OS version and WhatsApp's opt-in — not available in practice yet.)
- **Notifications** (Settings → Reminder / Daily sentence): each is independently toggleable, with its own time-of-day; the reminder also has a cadence (every day / 2 days / week). Both are scheduled with `AlarmManager` (`Alarms.kt`) so they fire at the exact chosen time — not tied to WorkManager's ~6h data-refresh cycle. On Android 12+, exact scheduling needs the "Exact alarms" permission (Settings screen surfaces this when it's missing); without it, the OS may deliver the notification a little late. A `BootReceiver` re-arms both alarms after a reboot, since `AlarmManager` alarms don't survive one.
- **Language**: defaults to Arabic on first install; an in-app toggle (Settings → Language, also offered on the first onboarding page) switches it, independent of the phone's system language. The one exception is the home-screen launcher label under the app icon, which Android always draws from the *phone's* system locale (`values-ar/strings.xml`), not this in-app setting.
- **First-run walkthrough** (`features/onboarding/onboarding_screen.dart`): shown once before the main app, walking through the language choice, the contacts/call-log and notification/exact-alarm permissions, how to set the notification schedule, and how to add the home-screen widget; gated on the `onboardingComplete` setting. Replayable any time from Settings → "How to use Wisal".
- **Kin lists**: marking a list "Kin (الأرحام)" only changes its UI treatment (badge, icon) and prefills a shorter default reminder threshold for *new* lists — it's not a separate native code path, it rides the same per-list `remindAfterDays` the sync already uses.
- Some phones (Xiaomi, Oppo, Samsung) restrict background work: Settings → Battery optimization.
- Installing outside Google Play is required: Play restricts READ_CALL_LOG to default dialer apps.
- Renaming to Wisal changed the Android package id (`com.wisal.app`), so this is a fresh install — any existing "Reconnect" install's local lists need to be re-added (your actual contacts/call history are untouched; they live in Android's own providers, not this app).
