plugins {
    id("com.android.application")
    // Eliminamos id("kotlin-android") para usar el "Built-in Kotlin" de Flutter y quitar la advertencia
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.app_ventas"
    compileSdk = 36

    compileOptions {
        // Subimos la versión a Java 21 para emparejar exactamente con la tarea de Kotlin
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    defaultConfig {
        applicationId = "com.example.app_ventas"
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