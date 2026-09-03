-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

-keep class com.tekartik.sqflite.** { *; }
-keep class net.sqlcipher.** { *; }
-dontwarn net.sqlcipher.**

-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

-keep class androidx.security.crypto.** { *; }

# Le moteur Flutter référence toujours les classes Play Core (installation
# différée de composants / "deferred components"), même si l'application ne
# télécharge jamais de module à la demande — l'appli est distribuée en APK
# unique, hors Play Store, et n'utilise pas cette fonctionnalité. R8 échoue
# sinon avec "Missing classes" pour du code mort dans notre cas ; -dontwarn
# suffit car ces chemins ne sont jamais exécutés.
-dontwarn com.google.android.play.core.**
