// The Android Gradle Plugin builds the native code with the Android NDK.

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        // The Android Gradle Plugin knows how to build native code with the NDK.
        classpath("com.android.tools.build:gradle:9.1.1")
    }
}

plugins {
    id("com.android.library")
}

group = "com.kurban.xue_hua_barcode_scanner"
version = "1.2.0"

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

android {
    namespace = "com.kurban.xue_hua_barcode_scanner"
    compileSdk = 36

    externalNativeBuild {
        cmake {
            path = file("../src/CMakeLists.txt")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("consumer-rules.pro")
    }
}
