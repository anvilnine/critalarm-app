# Keep the no-arg constructor of every Room database implementation.
#
# Without this the release app closes at launch, before any Dart runs:
#   Unable to get provider androidx.startup.InitializationProvider ...
#   Failed to create an instance of class androidx.work.impl.WorkDatabase
#
# The chain: com.google.android.play:asset-delivery pulls in
# androidx.work:work-runtime, which pulls in Room 2.5.0. WorkManager starts
# with the app and Room builds WorkDatabase_Impl by reflection, through its
# no-arg constructor. Room 2.5.0 ships the rule
# `-keep class * extends androidx.room.RoomDatabase`, which keeps the class
# but not its members, so R8 in full mode removes the constructor.
#
# Debug builds do not run R8, so only release builds show it.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
