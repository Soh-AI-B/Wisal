#!/usr/bin/env bash
# Creates the Flutter Android project, applies this overlay, adds native deps.
set -e
cd "$(dirname "$0")"
flutter create --org com.wisal --project-name wisal_app --platforms=android reconnect_app
rm -f reconnect_app/test/widget_test.dart
# flutter create scaffolds com/wisal/wisal_app (org + project name); the overlay's Kotlin lives
# under the shorter com/wisal/app, so drop the stale default package before copying it in.
rm -rf reconnect_app/android/app/src/main/kotlin/com/wisal/wisal_app
rm -rf reconnect_app/android/app/src/test/kotlin/com/wisal/wisal_app
cp -r overlay/. reconnect_app/

G=reconnect_app/android/app/build.gradle
[ -f "$G.kts" ] && G="$G.kts"
# flutter create derives com.wisal.wisal_app from --org/--project-name; pin it to the shorter id we actually use.
sed -i 's/com\.wisal\.wisal_app/com.wisal.app/' "$G"
cat >> "$G" <<'GRADLE'

dependencies {
    implementation("androidx.work:work-runtime-ktx:2.9.1")
    implementation("androidx.core:core-ktx:1.13.1")
    testImplementation("junit:junit:4.13.2")
}
GRADLE

cd reconnect_app
flutter pub get
echo
echo "Ready. Connect an Android phone, then:  cd reconnect_app && flutter run"
echo "APK for sharing:                        flutter build apk --release"
