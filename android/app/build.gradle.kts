plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

fun prop(name: String, default: String = ""): String =
    (findProperty(name) as String?)?.takeIf { it.isNotBlank() } ?: System.getenv(name)?.takeIf { it.isNotBlank() } ?: default

fun str(value: String) = "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

android {
    namespace = "com.salahalarm.android"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.salahalarm.android"
        minSdk = 26
        targetSdk = 35
        versionCode = prop("VERSION_CODE", "1").toInt()
        versionName = prop("VERSION_NAME", "1.0.0")

        buildConfigField("String", "API_ORIGIN", str(prop("API_ORIGIN", "https://salahalarm.com")))
        buildConfigField("String", "FIREBASE_API_KEY", str(prop("FIREBASE_API_KEY", "AIzaSyABdJ9QWxrxu4GGs8hXqhgouMjE4B7TQlI")))
        buildConfigField("String", "FIREBASE_PROJECT_ID", str(prop("FIREBASE_PROJECT_ID", "ramadan-pro-684da")))
        // Replace with the Android app id once the app is registered in Firebase.
        buildConfigField("String", "FIREBASE_APP_ID", str(prop("FIREBASE_ANDROID_APP_ID", "1:151770307855:ios:96ca1da5d7b4984acc327a")))
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", str(prop("GOOGLE_WEB_CLIENT_ID", "151770307855-2guv4dlie4p8k3su6056s2ren6jb30tg.apps.googleusercontent.com")))
        buildConfigField("String", "POSTHOG_KEY", str(prop("POSTHOG_KEY", "phc_AmAGJBxqjVu2fSzoNZjNRmfAQrf6iyQjgzhRRmatutGX")))
        buildConfigField("String", "POSTHOG_HOST", str(prop("POSTHOG_HOST", "https://us.i.posthog.com")))
    }

    val keystore = prop("SIGNING_STORE_FILE")
    signingConfigs {
        if (keystore.isNotEmpty()) {
            create("release") {
                storeFile = file(keystore)
                storePassword = prop("SIGNING_STORE_PASSWORD")
                keyAlias = prop("SIGNING_KEY_ALIAS", "salahalarm")
                keyPassword = prop("SIGNING_KEY_PASSWORD", prop("SIGNING_STORE_PASSWORD"))
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources.excludes += setOf("/META-INF/{AL2.0,LGPL2.1}", "META-INF/DEPENDENCIES")
    }

    dependenciesInfo {
        // Sideloaded APK: no Play dependency metadata block.
        includeInApk = false
        includeInBundle = false
    }
}

dependencies {
    implementation(project(":core"))

    implementation(platform("androidx.compose:compose-bom:2024.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.work:work-runtime-ktx:2.9.1")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")

    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")

    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
}
