# Flutter's own engine/embedding and plugins ship their own consumer ProGuard rules bundled in
# their AARs, which R8 picks up automatically — nothing needed here for them.

# WorkManager instantiates Worker subclasses by reflection using the class name it stored when the
# job was scheduled, with no manifest entry to anchor R8's default keep rules. Without this, a
# release build can silently fail to run the background sync worker after R8 renames/strips it.
-keep class * extends androidx.work.Worker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
