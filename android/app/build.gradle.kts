plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_khalil"

    // القيم هذه يوفّرها Flutter plugin
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21

        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    defaultConfig {
        // لازم يطابق package_name داخل google-services.json
        applicationId = "com.example.flutter_khalil"

        // ✅ Firebase يتطلب 23 أو أعلى — خلّها صريحة 23
        minSdk = flutter.minSdkVersion
        targetSdk = 34

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    buildTypes {
        release {
            // توقيع مؤقت باستخدام debug keystore
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ إضافة core library desugaring (مهم جداً!)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // ✅ إضافة multidex support
    implementation("androidx.multidex:multidex:2.0.1")
}
