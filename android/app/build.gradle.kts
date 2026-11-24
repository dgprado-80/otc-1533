import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("keystore.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val ciAbiFilters = providers.gradleProperty("otclient.android.abis")
    .orElse(providers.environmentVariable("OTCLIENT_ANDROID_ABIS"))
    .orNull
    ?.split(",")
    ?.map { it.trim() }
    ?.filter { it.isNotEmpty() }
    ?: listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")

android {
    namespace = "com.github.otclient"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.github.otclient"
        minSdk = 21
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        ndk {
            abiFilters += ciAbiFilters
        }

        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++20")

                arguments += listOf(
                    "-DVCPKG_TARGET_ANDROID=ON",
                    "-DANDROID_STL=c++_shared",
                    "-DVCPKG_MANIFEST_INSTALL=ON",
                    "-DVCPKG_INSTALL_OPTIONS=--allow-unsupported",
                    "-DSPEED_UP_BUILD_UNITY=OFF",
                    "-DOPTIONS_LOW_MEMORY_BUILD=ON",
                    "-DOPTIONS_COMPILE_JOBS=1",
                    "-DOPTIONS_LINK_JOBS=1"
                )
            }
        }
    }

    signingConfigs {
        create("release") {
            val store = System.getenv("RELEASE_KEYSTORE")
                ?: keystoreProperties.getProperty("storeFile")
                ?: error("Release keystore missing. Create android/keystore.properties or set RELEASE_KEYSTORE.")
            storeFile = rootProject.file(store)
            storePassword = System.getenv("RELEASE_KEYSTORE_PASSWORD")
                ?: keystoreProperties.getProperty("storePassword")
            keyAlias = System.getenv("RELEASE_KEY_ALIAS")
                ?: keystoreProperties.getProperty("keyAlias")
            keyPassword = System.getenv("RELEASE_KEY_PASSWORD")
                ?: keystoreProperties.getProperty("keyPassword")
        }
    }

    externalNativeBuild {
        cmake {
            path = file("../../CMakeLists.txt")
            version = "3.31.6"
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        viewBinding = true
        prefab = true
    }

    ndkVersion = "29.0.13599879"
}

dependencies {
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("androidx.games:games-activity:1.2.1")
    implementation("com.google.android.material:material:1.13.0")
}
