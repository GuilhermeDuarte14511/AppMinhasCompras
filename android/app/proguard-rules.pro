# Project specific ProGuard rules.
# Most Flutter/Firebase plugins ship their own consumer rules.

# Keep plugin registrant used by Flutter embedding.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Ignore optional ML Kit script recognizers not bundled in this app.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
