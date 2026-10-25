# Firebase, Credential Manager and Compose ship their own consumer rules.
-keep class com.salahalarm.android.lock.SalahLockService { *; }
-keep class com.batoulapps.adhan.** { *; }
-dontwarn org.slf4j.**
-dontwarn com.google.errorprone.annotations.**
