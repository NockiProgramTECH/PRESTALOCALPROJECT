# Règles ProGuard/R8 pour le build release (Play Store).
# Les plugins Flutter fournissent déjà leurs propres règles via
# consumer-rules.pro ; ce fichier conserve le strict minimum.

# Flutter embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
