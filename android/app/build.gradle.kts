plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.furasuh"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        // غيّرها لاحقاً لو عندك حزمة خاصة فيك
        applicationId = "com.example.furasuh"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // إعدادات التوقيع
    signingConfigs {
        create("release") {
            storeFile = file("my-release-key.jks")   // ✅ تم التعديل هنا
            storePassword = "Ta!123123123"
            keyAlias = "my-key-alias"
            keyPassword = "Ta!123123123"
        }
    }

    buildTypes {
        getByName("release") {
            // نخلي الريليز يستخدم مفتاح التوقيع اللي أنشأناه
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        // debug يظل بإعداداته الافتراضية
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
}

flutter {
    source = "../.."
}
