# Wisal (وصال)

[العربية](README.md) | English

![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)
![License](https://img.shields.io/badge/license-GPL--3.0-blue)
![Internet](https://img.shields.io/badge/internet%20access-none-success)

**Wisal** ("وصال" — connection) is a local-first, bilingual (Arabic/English)
Android app that helps you keep صلة الرحم — staying in touch with family and
loved ones. It reads your phone's own call log to work out who you haven't
actually spoken to in a while, reminds you on a schedule you control, and
sends a daily motivational sentence. There is no account, no server, and no
internet connection involved anywhere in how the app works.

## Features

- **Smart reminders** — reads your real call log to find your last answered
  call with each person (≥10s, so a missed pickup doesn't count), and tells
  you who's overdue based on a per-list reminder interval you set.
- **Lists** — group people (family, friends, …) with their own reminder
  cadence; a "Kin" tier for صلة الرحم-specific lists gets a shorter default
  and a distinct badge.
- **Two independent, exact-time notifications** — an overdue-people reminder
  and a daily صلة الرحم sentence, each with its own on/off switch, cadence
  (daily / every 2 days / weekly), and exact time of day.
- **Home-screen widget** — a scrollable list of everyone you're overdue to
  call, updated in the background, with no need to open the app.
- **Call direction & notes** — see at a glance whether you called them or
  they called you last, snooze a reminder, and keep a private note per
  person.
- **Reconnect stats** — a weekly/monthly view of how many people you've
  actually reached out to, and which list you're keeping up with best.
- **Fully bilingual** — Arabic (default) and English, with complete
  right-to-left layout support, switchable anytime in Settings.
- **Guided onboarding** — a first-run walkthrough for permissions,
  notification setup, and adding the widget, replayable anytime from
  Settings.

## Why Android only

This isn't a resourcing shortcut — the app's entire premise depends on an
Android-only capability. Wisal works by reading your device's **call log**
(`android.provider.CallLog`) to find out when you last actually spoke to
someone. iOS has no equivalent API, public or otherwise: Apple does not let
any third-party app, even with the user's explicit permission, read the
device's call history. The closest iOS facility (CallKit) only lets an app
*supply* caller-ID/blocking data or act as a VoIP dialer — it cannot *read*
past calls. Without that one capability, the core feature ("who haven't I
actually called in a while?") can't be built at all, so there's no reduced
version of this app that would make sense on iPhone.

## Privacy & security

This is the part that matters most, so here it is in full, backed by things
you can verify yourself in this repository:

- **No internet connection, period.** The app requests zero network
  permissions in release builds. (Android *debug* builds get a Flutter
  tooling-injected `INTERNET` permission purely so `flutter run`'s hot
  reload can talk to the running app over localhost — this is standard
  Flutter behavior, not app code, and it is absent from release builds. You
  can confirm this yourself: build both variants and diff
  `android/app/build/intermediates/merged_manifest/*/**/AndroidManifest.xml`.)
- **No analytics, no crash reporting, no third-party SDKs.** Check
  `pubspec.yaml` and `android/app/build.gradle.kts`: every dependency is a
  local-functionality library (local database, local notifications,
  background scheduling, the OS share sheet, URL/dialer launching). None of
  them talk to a server.
- **Your data never leaves your phone.** Contacts and call-log data are read
  directly from Android's own content providers and written only to this
  app's private, sandboxed SQLite database and `SharedPreferences` — never
  anywhere else. `android:allowBackup="false"` plus an explicit
  `data_extraction_rules.xml` excludes the database, shared preferences, and
  files from *both* Android's cloud backup and its device-to-device transfer
  — so the data isn't even copied when you back up or switch phones.
- **Read-only where it counts.** The app never requests `WRITE_CONTACTS` or
  `WRITE_CALL_LOG` — it cannot modify your contacts or call history even if
  it wanted to.
- **No PII in logs.** Diagnostic log lines (tagged `Wisal`, visible only via
  `adb logcat` on a device you control) record timestamps, counts, and
  booleans — never a name, number, or note.
- **Open source, so you don't have to take any of this on faith** — every
  claim above is something you can grep for yourself.

### Permissions, and why each one exists

| Permission | Why |
|---|---|
| `READ_CONTACTS` | To list your contacts when building a list, and to match phone numbers to names. |
| `READ_CALL_LOG` | To find your last answered call with each person — the core feature. |
| `POST_NOTIFICATIONS` | To show the two reminder notifications (Android 13+ requires this explicitly). |
| `SCHEDULE_EXACT_ALARM` | So the notifications fire at the exact time you chose, not "sometime around" it. |
| `RECEIVE_BOOT_COMPLETED` | To re-arm the notification schedule after a reboot (`AlarmManager` alarms don't survive one). |
| `WAKE_LOCK`, `ACCESS_NETWORK_STATE`, `FOREGROUND_SERVICE` | Declared by `androidx.work` (WorkManager), used for the periodic background data refresh. Not requested by app code directly, and none of them grant network access on their own. |

## Architecture

- **Flutter** (`lib/`) — UI, lists, reminder logic, bilingual strings
  (`core/i18n.dart` — a plain `tr(ref, en, ar)` helper, no ARB/codegen), and
  a local SQLite database (`core/database/app_database.dart`) for lists,
  members, settings, and a small reconnect log used for stats.
- **Kotlin** (`android/app/src/main/kotlin/com/wisal/app/`) — a single
  `MethodChannel` (`wisal/native`) handles permissions, contacts, call-log
  reads, and phone-number matching (`Sync.kt`); `AlarmManager`
  (`Alarms.kt`) schedules the two notifications so they fire at an exact
  time even without the Flutter engine running; `WorkManager`
  (`Background.kt`) does a periodic (~6h) data refresh; a `RemoteViewsService`
  (`ReconnectWidgetService.kt`) backs the scrollable home-screen widget.
- Flutter mirrors lists/members/settings to native storage after every
  change (`AppDatabase.pushConfig`); native re-arms its alarms from that
  same config right after every save, but only when the notification
  settings actually changed (`Alarms.rescheduleFromConfig`) — so a routine
  background sync can't accidentally defer an already-armed alarm.
- صلة الرحم sentences are bundled identically as a Flutter asset
  (`assets/sentences.txt`) and an Android raw resource
  (`res/raw/sentences.txt`), so the home-screen card and the day's
  notification always land on the same sentence (`epochDay % count`).

### Project structure

```
wisal_app/
├── lib/
│   ├── core/            # database, models, native bridge, theme, i18n, reminder logic
│   └── features/        # home, lists, contacts, settings, stats, onboarding — one folder per screen
├── android/app/src/main/
│   ├── kotlin/com/wisal/app/   # native sync, alarms, widget, notifications
│   └── res/                    # widget layout/colors, launcher icon, strings (en/ar)
├── assets/              # bundled fonts (Tajawal, Inter) and the صلة الرحم sentence list
└── test/                # Dart unit tests
```

## Getting started

Requires the [Flutter SDK](https://flutter.dev) and Android SDK/platform
tools (`sdkmanager`, `adb`) on your `PATH`.

```bash
cd wisal_app
flutter pub get
flutter run                       # debug build on a connected device/emulator
flutter build apk --release       # release build → build/app/outputs/flutter-apk/app-release.apk
```

Sideloading is required either way: Google Play restricts `READ_CALL_LOG`
to an app's *default dialer*, which this isn't, so it can't be distributed
through the Play Store.

### Signing release builds

`android/app/build.gradle.kts` looks for `android/key.properties`: if it's
missing, release builds fall back to the debug key (so the project still
builds out of the box for anyone cloning the repo); if it's present, the
release build is signed with the real keystore it points to. Neither the
keystore nor `key.properties` are ever committed — `android/.gitignore`
excludes both.

To set up your own signing identity:

```bash
keytool -genkeypair -v -keystore ~/your-release-key.jks \
  -alias your-alias -keyalg RSA -keysize 4096 -validity 10000
```

then create `android/key.properties`:

```properties
storePassword=<the password you set above>
keyPassword=<the same or a separate password>
keyAlias=your-alias
storeFile=/home/you/your-release-key.jks
```

Back up both the keystore file and its password somewhere safe outside the
repo (a password manager, not a text file) — Android requires the *same*
signing key for every future update to an app; losing either one means you
can never publish an update under that app identity again.

Some phones (Xiaomi, Oppo, Samsung, and other aggressive-battery-management
skins) restrict background work by default — Settings → Battery
optimization in the app walks you through allowing it, which makes the
scheduled reminders more reliable.

## Testing

```bash
cd wisal_app && flutter test                                  # Dart
cd wisal_app/android && ./gradlew :app:testDebugUnitTest       # Kotlin (phone-number normalization)
```

## Implementation notes

- Answered calls = incoming/outgoing with duration ≥ 10s
  (`MIN_CALL_SECONDS` in `Sync.kt`) — a missed pickup or voicemail bounce
  doesn't count as a real conversation.
- The contact picker de-duplicates by normalized phone number
  (`Contacts.list` in `Sync.kt`): Android doesn't always merge raw contacts
  from different sources (phone-local storage vs. a Google account) into
  one aggregate, so a phone-to-phone transfer often leaves the same person
  as two separate entries with the same number — only the first is shown.
- Default country code for local numbers is 213 (Algeria) —
  `PhoneNormalizer` in `Sync.kt`; change `CC` there for a different default.
- WhatsApp/Telegram calls aren't in the Android call log on virtually any
  device today, so they can't be included. (Android 16.1 introduces an
  OS-level unified call log that could someday expose them, but it needs
  both that OS version and the other app's opt-in — not available in
  practice yet.)
- The widget list scrolls (`ReconnectWidgetService`/`RemoteViewsFactory`)
  and shows every overdue person, not just the first few; names are always
  rendered left-to-right in it (`textDirection="ltr"`) so Arabic names don't
  flip to right alignment.
- Language defaults to Arabic on first install; an in-app toggle (Settings
  → Language, or the onboarding flow) switches it, independent of the
  phone's own system language. The one exception is the home-screen
  launcher label under the app icon, which Android always draws from the
  *phone's* system locale, not this in-app setting.
- "Kin" lists only change UI treatment (badge, icon, a shorter prefilled
  default) — it's not a separate code path, it rides the same per-list
  reminder-interval the sync already uses.

## Contributing

Issues and pull requests are welcome. A few things that keep this
maintainable:
- Run `flutter analyze` and `flutter test` before opening a PR — CI-free
  for now, so this is the only gate.
- Keep the "no network, no telemetry" property intact — any dependency or
  change that would add either needs a very good reason and a clear call-out
  in the PR description.
- Match the existing bilingual pattern (`tr(ref, 'English', 'العربية')`)
  for any new user-visible string.

## License

GPL-3.0 — see [LICENSE](LICENSE). Copyright © 2026 Soh-AI-B.
