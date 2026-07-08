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
    namespace = "com.jro.swimtracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jro.swimtracker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfigs {
                create("release") {
                    storeFile = file(System.getenv("CM_KEYSTORE_PATH") ?: "")
                    storePassword = System.getenv("CM_KEYSTORE_PASSWORD") ?: ""
                    keyAlias = System.getenv("CM_KEY_ALIAS") ?: ""
                    keyPassword = System.getenv("CM_KEY_PASSWORD") ?: ""
                }
            }

            buildTypes {
                release {
                    signingConfig = signingConfigs.getByName("release")
                }
            }
        }
    }

    
}

dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
    }

flutter {
    source = "../.."
}
