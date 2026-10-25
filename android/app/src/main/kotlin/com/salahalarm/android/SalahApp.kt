package com.salahalarm.android

import android.annotation.SuppressLint
import android.app.Application
import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.salahalarm.android.alarm.AlarmScheduler
import com.salahalarm.android.alarm.Notifications
import com.salahalarm.android.data.Repo
import com.salahalarm.android.data.Store
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

class SalahApp : Application() {
    override fun onCreate() {
        super.onCreate()
        if (FirebaseApp.getApps(this).isEmpty()) {
            // Configured in code rather than google-services.json so the build
            // needs nothing from the Firebase console beyond these ids.
            val options = FirebaseOptions.Builder()
                .setApiKey(BuildConfig.FIREBASE_API_KEY)
                .setApplicationId(BuildConfig.FIREBASE_APP_ID)
                .setProjectId(BuildConfig.FIREBASE_PROJECT_ID)
                .setGcmSenderId("151770307855")
                .setStorageBucket("${BuildConfig.FIREBASE_PROJECT_ID}.firebasestorage.app")
                .build()
            FirebaseApp.initializeApp(this, options)
        }
        Graph.init(this)
        Notifications.createChannels(this)
        AlarmScheduler.reschedule(this)
    }
}

/** App-wide singletons. Small enough not to need a DI framework. */
@SuppressLint("StaticFieldLeak")
object Graph {
    lateinit var context: Context
        private set
    lateinit var store: Store
        private set
    lateinit var repo: Repo
        private set
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    fun init(app: Context) {
        if (::repo.isInitialized) return
        context = app.applicationContext
        store = Store(context)
        I18n.init(context, store.language())
        repo = Repo(context, store)
    }
}
