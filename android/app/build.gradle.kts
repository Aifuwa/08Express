import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.eightexpress.app"
    
    // Explicitly set to 36 to support modern Firebase libraries and Push Notifications
    compileSdk = 36 
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.eightexpress.app"
        //minSdk = flutter.minSdkVersion 
        minSdk = flutter.minSdkVersion 
        // Explicitly set to 35 to prevent "Unknown calling package" error during Auth logic
        targetSdk = 35 
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            
            // Optimization for production
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // --- DOCUMENTATION IMPLEMENTATION START ---
    
    // 1. Import the BoM (Bill of Materials) for the Firebase platform 
    // to ensure all Firebase library versions are compatible.
    implementation(platform("com.google.firebase:firebase-bom:34.8.0"))

    // 2. Add the dependency for the Firebase Authentication library.
    // Versions are managed by the BoM above.
    implementation("com.google.firebase:firebase-auth")

    // --- DOCUMENTATION IMPLEMENTATION END ---

    // Core library desugaring for compatibility with older Android devices
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // Multidex support for large dependency sets
    implementation("androidx.multidex:multidex:2.0.1") 
}
