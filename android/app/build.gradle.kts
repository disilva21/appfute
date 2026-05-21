import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { stream ->
        keystoreProperties.load(stream)
    }
}

android {
    namespace = "com.ebeltec.appfute"
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
        applicationId = "com.ebeltec.appfute"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Usamos 'getByName("debug")' ou 'debug' para configurar o padrão
        // E 'create("release")' para o novo
        create("release") {
            if (keystoreProperties.isEmpty) {
                // Prevenção opcional: evita erro se o arquivo sumir
                println("AVISO: key.properties não encontrado ou vazio!")
            } else {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Aqui garantimos que ele use a configuração de assinatura que criamos acima
            signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = false // Geralmente padrão no Flutter, ajuste se necessário
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}