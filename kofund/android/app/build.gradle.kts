plugins {
    id("com.android.application")
    // 🔥 Required for Firebase
    id("com.google.gms.google-services")
    id("kotlin-android")

    // Flutter plugin (must always be last)
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kofund.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true

    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.kofund.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // REQUIRED for Firebase Messaging + Ads
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 🔥 Firebase BOM → Automatically manages all versions
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))

    // 🔥 FCM Push Notifications
    implementation("com.google.firebase:firebase-messaging")

    // 📌 Required for background FCM on Android 14+
    implementation("androidx.work:work-runtime-ktx:2.9.0")

    // 📢 Local Notifications rely on this
    implementation("com.google.android.support:wearable:2.9.0")

    // 🟡 AdMob
    implementation("com.google.android.gms:play-services-ads:23.0.0")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // 🧩 Fix large build sizes from Firebase
    implementation("androidx.multidex:multidex:2.0.1")
}
