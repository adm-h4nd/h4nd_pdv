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

# ============================================================================
# CRÍTICO: Preserva adapters do Hive (aplicado a todos os flavors)
# ============================================================================
# Preserva TODOS os adapters do Hive
-keep class * extends com.ryanharter.hive.typeadapters.TypeAdapter { *; }
-keep class * implements com.ryanharter.hive.typeadapters.TypeAdapter { *; }

# Preserva adapters específicos do projeto
-keep class com.example.mx_cloud_pdv.data.models.local.**Adapter { *; }
-keep class com.example.mx_cloud_pdv.data.models.home.**Adapter { *; }
-keep class com.example.mx_cloud_pdv.data.models.local.**Local { *; }
-keep class com.example.mx_cloud_pdv.data.models.home.** { *; }

# Preserva nomes das classes (importante para reflexão)
-keepnames class com.example.mx_cloud_pdv.data.models.local.** { *; }
-keepnames class com.example.mx_cloud_pdv.data.models.home.** { *; }

# Regras específicas para flavor mobile (aplicadas via build.gradle.kts)
# As classes do SDK Stone serão ignoradas no flavor mobile

