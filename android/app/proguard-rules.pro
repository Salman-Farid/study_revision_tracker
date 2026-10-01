# Flutter / plugin keep rules for release minify.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Supabase / realtime
-keep class io.supabase.** { *; }

# Local notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Home widget
-keep class com.pootustudycompanion.app.** { *; }
