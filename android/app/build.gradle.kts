import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Yayın imzası: android/key.properties dosyası (veya CI ortam değişkenleri) varsa kullanılır.
// Yoksa hata ayıklama anahtarıyla imzalanır (kurulabilir, ancak mağaza yayını için uygun değildir).
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val releaseStoreFile: String? = keystoreProperties.getProperty("storeFile") ?: System.getenv("WT_KEYSTORE")

android {
    namespace = "com.furkanbaykal.worldtrack"
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
        applicationId = "com.furkanbaykal.worldtrack"
        // Android 7.0+: güncel SQLite ve sistem fotoğraf seçicisi desteği için.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = keystoreProperties.getProperty("storePassword") ?: System.getenv("WT_KEYSTORE_PASSWORD")
                keyAlias = keystoreProperties.getProperty("keyAlias") ?: System.getenv("WT_KEY_ALIAS")
                keyPassword = keystoreProperties.getProperty("keyPassword") ?: System.getenv("WT_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
