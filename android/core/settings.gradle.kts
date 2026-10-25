// Lets the platform-free logic build and test on its own, without the Android
// SDK: `gradle -p core test`. Ignored when core is built as part of the app.
pluginManagement {
    repositories { mavenCentral(); gradlePluginPortal() }
    plugins { id("org.jetbrains.kotlin.jvm") version "2.0.21" }
}
dependencyResolutionManagement { repositories { mavenCentral() } }
rootProject.name = "core"
