allprojects {
    repositories {
        google()
        mavenCentral()
        
        // Repositório Stone Payments (PackageCloud)
        val localProperties = java.util.Properties()
        val localPropertiesFile = rootProject.file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { localProperties.load(it) }
        }
        
        val packageCloudToken = localProperties.getProperty("packageCloudReadToken")
        
        if (packageCloudToken != null && packageCloudToken.isNotEmpty()) {
            maven {
                url = uri("https://packagecloud.io/priv/stone/pos-android/maven2")
                credentials {
                    username = packageCloudToken
                    password = ""
                }
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
