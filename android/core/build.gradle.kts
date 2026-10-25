plugins {
    id("org.jetbrains.kotlin.jvm")
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}
kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }

dependencies {
    // Same calculation library family the iOS app uses (Adhan-Swift).
    api("com.batoulapps.adhan:adhan:1.2.1")
    testImplementation(kotlin("test"))
}

tasks.test { useJUnitPlatform() }
