allprojects {
    repositories {
        google()
        mavenCentral()
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

subprojects {
    val configureNamespace = { p: Project ->
        if (p.hasProperty("android")) {
            val android = p.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            if (android.namespace == null) {
                val manifestFile = p.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val xml = groovy.xml.XmlParser().parse(manifestFile)
                    val pkg = xml.attribute("package")?.toString()
                    if (pkg != null) {
                        android.namespace = pkg
                    }
                }
            }
        }
    }
    if (project.state.executed) {
        configureNamespace(project)
    } else {
        project.afterEvaluate {
            configureNamespace(project)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
