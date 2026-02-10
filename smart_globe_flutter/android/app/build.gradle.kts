plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services plugin'i buraya ekli (Doğru yer burası)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.flutter_application_1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Application ID'nin Firebase'e kaydettiğinle AYNI olduğundan emin ol
        applicationId = "com.android.application"
        
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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

// --- BURAYI BİZ EKLİYORUZ (En alta) ---
dependencies {
    // Firebase BOM (Versiyon yönetimini kolaylaştırır)
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    
    // İhtiyacımız olan kütüphaneler
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-database")
}