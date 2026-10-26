package com.salahalarm.android.data

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.salahalarm.android.Graph
import java.util.concurrent.TimeUnit

/**
 * Once a day, even if the app isn't opened: sync prayer history with the account
 * and re-check the subscription or free trial, so a trial that ends (or a plan
 * bought on salahalarm.com) shows up without waiting for the next launch.
 */
class DailySyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val repo = Graph.repo
        if (repo.user.value == null) return Result.success()
        repo.syncFromCloud()
        repo.refreshEntitlement(force = true)
        return Result.success()
    }

    companion object {
        private const val NAME = "daily_account_sync"

        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<DailySyncWorker>(1, TimeUnit.DAYS)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }
}
