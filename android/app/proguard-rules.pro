# ProGuard rules gerais para o projeto
# Regras específicas por flavor são aplicadas via applicationVariants

# Mantém classes do Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Mantém classes nativas
-keepclasseswithmembers class * {
    native <methods>;
}

# Mantém classes anotadas com @Keep
-keep @androidx.annotation.Keep class *
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Regras específicas para flavor mobile (aplicadas via build.gradle.kts)
# As classes do SDK Stone serão ignoradas no flavor mobile

# Ignora avisos sobre classes do SDK POS que não estão disponíveis
-dontwarn android.os.ServiceManager
-dontwarn android.os.SystemProperties
-dontwarn com.pos.sdk.**

