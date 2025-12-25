plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mx_cloud_pdv"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mx_cloud_pdv"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "device"
    
    productFlavors {
        create("mobile") {
            dimension = "device"
            applicationIdSuffix = ".mobile"
            resValue("string", "app_name", "MX Cloud PDV Mobile")
        }
        
        create("stoneP2") {
            dimension = "device"
            applicationIdSuffix = ".stone.p2"
            resValue("string", "app_name", "MX Cloud PDV Stone P2")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro",
                "proguard-mobile.pro"
            )
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    
    // Exclui dependências do SDK Stone no flavor mobile
    applicationVariants.all {
        val variant = this
        if (variant.flavorName == "mobile") {
            // Exclui todas as dependências relacionadas ao SDK Stone
            variant.runtimeConfiguration.exclude(
                group = "dev.ltag",
                module = "stone_payments"
            )
            variant.compileConfiguration.exclude(
                group = "dev.ltag",
                module = "stone_payments"
            )
            // Exclui SDK nativo Stone
            variant.runtimeConfiguration.exclude(
                group = "br.com.stone",
                module = "stone-sdk"
            )
            variant.compileConfiguration.exclude(
                group = "br.com.stone",
                module = "stone-sdk"
            )
        }
    }
}

dependencies {
    // O pacote stone_payments vem do pubspec.yaml (necessário para compilar código Dart)
    // Mas as dependências nativas serão excluídas no flavor mobile via applicationVariants
}

flutter {
    source = "../.."
}
