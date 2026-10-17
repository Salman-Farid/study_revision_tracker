import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.pootustudycompanion.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.pootustudycompanion.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Keep only a compact symbol table (not full debug .sym files).
            ndk {
                debugSymbolLevel = "symbol_table"
            }
        }
    }

    packaging {
        resources {
            // Drop transitive jar/source clutter that never ships to devices.
            excludes += setOf(
                "kotlin/**",
                "kotlin-tooling-metadata.json",
                "org/dmfs/**",
                "**.kotlin_builtins",
                "META-INF/*.version",
                "META-INF/*.kotlin_module",
                "META-INF/INDEX.LIST",
                "META-INF/DEPENDENCIES",
                "DebugProbesKt.bin",
                "third_party/**",
            )
        }
        jniLibs {
            // split-per-abi already isolates ABIs; never ship foreign ABIs inside one APK.
            pickFirsts += "**/libc++_shared.so"
        }
    }

    bundle {
        // Play delivers a single ABI/DPI/language per device — keep splits on.
        language { enableSplit = true }
        density { enableSplit = true }
        abi { enableSplit = true }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
