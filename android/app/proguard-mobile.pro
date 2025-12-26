# ProGuard rules para flavor mobile
# IMPORTANTE: ORDEM É CRÍTICA! Preservar ANTES de remover/otimizar

# ============================================================================
# CRÍTICO: PRESERVAR PRIMEIRO (antes de qualquer otimização)
# ============================================================================
# Desabilita TODAS as otimizações e ofuscação (máxima segurança)
-dontoptimize
-dontobfuscate
-dontpreverify
-keepattributes *
-keepnames class * { *; }

# Preserva MainActivity e ciclo de vida (CRÍTICO - deve vir primeiro!)
-keep class com.example.mx_cloud_pdv.MainActivity { *; }
-keep class io.flutter.embedding.android.FlutterActivity { *; }
-keepclassmembers class com.example.mx_cloud_pdv.MainActivity { *; }
-keepclassmembers class io.flutter.embedding.android.FlutterActivity { *; }

# Preserva TODOS os adapters do Hive (CRÍTICO - deve vir antes de otimizações!)
-keep class * extends com.ryanharter.hive.typeadapters.TypeAdapter { *; }
-keep class * implements com.ryanharter.hive.typeadapters.TypeAdapter { *; }
-keep @com.ryanharter.hive.typeadapters.TypeAdapter class * { *; }

# Preserva TODOS os adapters específicos do projeto (CRÍTICO!)
-keep class com.example.mx_cloud_pdv.data.models.local.**Adapter { *; }
-keep class com.example.mx_cloud_pdv.data.models.home.**Adapter { *; }
-keep class com.example.mx_cloud_pdv.data.models.local.**Local { *; }
-keep class com.example.mx_cloud_pdv.data.models.home.** { *; }

# Preserva classes com @HiveType
-keep @hive.HiveType class * { *; }
-keepclassmembers @hive.HiveType class * { *; }

# Preserva métodos read e write dos adapters
-keepclassmembers class * extends com.ryanharter.hive.typeadapters.TypeAdapter {
    public * read(***);
    public void write(***, ***);
}

# Preserva o pacote completo de models local
-keep class com.example.mx_cloud_pdv.data.models.local.** { *; }

# Preserva nomes das classes (importante para reflexão do Hive)
-keepnames class com.example.mx_cloud_pdv.data.models.local.** { *; }
-keepnames class com.example.mx_cloud_pdv.data.models.home.** { *; }

# Preserva construtores dos adapters (necessários para instanciação)
-keepclassmembers class com.example.mx_cloud_pdv.data.models.local.**Adapter {
    <init>();
}

# Preserva TODAS as classes que contêm "Adapter" no nome (segurança extra)
-keep class **.*Adapter { *; }

# Preserva anotações (incluindo @Keep)
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes SourceFile,LineNumberTable
-keepattributes EnclosingMethod

# ============================================================================
# SDK Stone - Ignora classes do SDK Stone (depois de preservar o essencial)
# ============================================================================
# IMPORTANTE: O R8 está detectando referências às classes Stone mesmo que não sejam usadas
# Estas regras fazem com que o R8 ignore completamente essas classes e não tente incluí-las no APK

# ============================================================================
# SDK Stone - Pacote br.com.stone.*
# ============================================================================
# Ignora todas as classes do pacote br.com.stone (não inclui no APK)
-dontwarn br.com.stone.**
-dontnote br.com.stone.**

# Remove todas as classes Stone do APK final
-assumenosideeffects class br.com.stone.** {
    *;
}

# Ignora classes específicas do SDK Stone que podem ser referenciadas mas não estão disponíveis
-dontwarn br.com.stone.pay.core.**
-dontwarn br.com.stone.posandroid.**
-dontwarn br.com.stone.application.**
-dontwarn br.com.stone.controllers.**
-dontwarn br.com.stone.database.**
-dontwarn br.com.stone.exception.**
-dontwarn br.com.stone.logger.**
-dontwarn br.com.stone.providers.**
-dontwarn br.com.stone.receipt.**
-dontwarn br.com.stone.repository.**
-dontwarn br.com.stone.user.**
-dontwarn br.com.stone.utils.**

# ============================================================================
# SDK Stone - Pacote stone.* (usado pelo plugin stone_payments)
# ============================================================================
# Ignora todas as classes do pacote stone.* (não inclui no APK)
-dontwarn stone.**
-dontnote stone.**

# Remove todas as classes Stone do APK final
-assumenosideeffects class stone.** {
    *;
}

# Ignora classes específicas do SDK Stone (stone.*)
-dontwarn stone.application.**
-dontwarn stone.application.enums.**
-dontwarn stone.application.interfaces.**
-dontwarn stone.database.transaction.**
-dontwarn stone.providers.**
-dontwarn stone.user.**
-dontwarn stone.utils.**
-dontwarn stone.utils.keys.**

# ============================================================================
# Google Play Core - Classes relacionadas a split installs/deferred components
# Estas classes são referenciadas pelo Flutter mas não são necessárias no flavor mobile
# ============================================================================
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Ignora todo o pacote Google Play Core (opcional, mais agressivo)
-dontwarn com.google.android.play.core.**

# ============================================================================
# Dependências do SDK Stone
# ============================================================================
# Ignora classes do Google Protobuf (usadas pelo SDK Stone)
-dontwarn com.google.protobuf.**

# Ignora classes do Retrofit/OkHttp (usadas pelo SDK Stone)
-dontwarn retrofit2.**
-dontwarn okhttp3.logging.**

# Ignora classes do XStream (usadas pelo SDK Stone)
-dontwarn com.thoughtworks.xstream.**

# Ignora classes do SLF4J (usadas pelo SDK Stone)
-dontwarn org.slf4j.**

# Ignora classes AWT/Swing (não disponíveis no Android)
-dontwarn java.awt.**
-dontwarn javax.swing.**

