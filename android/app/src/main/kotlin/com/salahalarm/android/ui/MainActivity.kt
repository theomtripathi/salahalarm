package com.salahalarm.android.ui

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.sp
import com.salahalarm.android.Graph
import com.salahalarm.android.data.Analytics
import com.salahalarm.android.t
import com.salahalarm.core.PrayerName
import com.salahalarm.core.PrayerLogic
import kotlinx.coroutines.launch

/** Screens opened on top of the tabs. */
sealed interface Route {
    data object AlarmSettings : Route
    data object Qibla : Route
    data object Setup : Route
    data object History : Route
    data class Reader(val surah: Int, val name: String, val ayah: Int? = null) : Route
}

object Nav {
    var tab by mutableStateOf(0)
    var stack by mutableStateOf(listOf<Route>())
    var confirmPrayer by mutableStateOf<PrayerName?>(null)
    var loginCode by mutableStateOf<String?>(null)

    fun push(r: Route) {
        stack = stack + r
    }

    fun pop() {
        stack = stack.dropLast(1)
    }
}

class MainActivity : ComponentActivity() {
    companion object {
        const val EXTRA_CONFIRM_PRAYER = "confirm_prayer"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Graph.init(this)
        enableEdgeToEdge()
        handle(intent)
        Analytics.appOpened()
        setContent { SalahTheme { App() } }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handle(intent)
    }

    override fun onResume() {
        super.onResume()
        Graph.scope.launch {
            Graph.repo.refreshEntitlement()
            Graph.repo.checkForUpdate()
        }
    }

    private fun handle(intent: Intent?) {
        intent ?: return
        PrayerName.fromId(intent.getStringExtra(EXTRA_CONFIRM_PRAYER))?.let {
            Nav.tab = 0
            Nav.confirmPrayer = it
        }
        val data = intent.data
        if (data != null && data.scheme == "salahalarm" && data.host == "login") {
            data.getQueryParameter("code")?.let { Nav.loginCode = it }
        }
    }
}

@Composable
private fun App() {
    val user by Graph.repo.user.collectAsState()
    var setupDone by rememberSaveable { mutableStateOf(Graph.store.flag("setup_done")) }

    LaunchedEffect(Unit) { Graph.repo.refreshLocation() }

    val entitlement by Graph.repo.entitlement.collectAsState()
    val now by rememberNow(60_000)

    when {
        user == null -> LoginScreen()
        // No plan (trial over, or an APK passed on without paying): the website sells plans.
        !entitlement.isActive(now) -> LockedScreen()
        !setupDone -> SetupScreen(onDone = {
            Graph.store.setFlag("setup_done")
            setupDone = true
        })
        else -> MainTabs()
    }

    Nav.confirmPrayer?.let { prayer ->
        if (user != null) {
            ConfirmPrayerDialog(
                prayer = prayer,
                onConfirm = {
                    Graph.repo.confirm(prayer)
                    Nav.confirmPrayer = null
                },
                onDismiss = { Nav.confirmPrayer = null },
            )
        }
    }
}

@Composable
private fun MainTabs() {
    val top = Nav.stack.lastOrNull()
    BackHandler(enabled = top != null) { Nav.pop() }
    BackHandler(enabled = top == null && Nav.tab != 0) { Nav.tab = 0 }

    when (top) {
        Route.AlarmSettings -> AlarmSettingsScreen(onBack = Nav::pop)
        Route.Qibla -> QiblaScreen(onBack = Nav::pop)
        Route.Setup -> SetupScreen(onDone = Nav::pop, standalone = true)
        Route.History -> PrayersScreen()
        is Route.Reader -> QuranReader(top, onBack = Nav::pop)
        null -> Tabs()
    }
}

@Composable
private fun Tabs() {
    val now by rememberNow(30_000)
    val logs by Graph.repo.logs.collectAsState()
    val location by Graph.repo.location.collectAsState()
    val schedule = remember3(now, location) { Graph.repo.todaySchedule() }
    val todayLog = logs[com.salahalarm.core.DateKeys.of(Graph.repo.today())] ?: com.salahalarm.core.DailyPrayerLog()
    val unconfirmed = PrayerName.entries.count { PrayerLogic.status(it, todayLog, schedule, now) == PrayerLogic.Status.MISSED }

    val items = listOf(
        Triple("Home", Icons.Filled.Home, 0),
        Triple("Prayers", Icons.Filled.WbSunny, 1),
        Triple("Lock", Icons.Filled.Lock, 2),
        Triple("Quran", Icons.AutoMirrored.Filled.MenuBook, 3),
        Triple("Profile", Icons.Filled.Person, 4),
    )
    Scaffold(
        containerColor = Palette.cream,
        bottomBar = {
            NavigationBar(containerColor = Color.White) {
                items.forEach { (label, icon, index) ->
                    NavigationBarItem(
                        selected = Nav.tab == index,
                        onClick = { Nav.tab = index },
                        icon = {
                            if (index == 1 && unconfirmed > 0) {
                                BadgedBox(badge = { Badge { Text("$unconfirmed") } }) { Icon(icon, contentDescription = null) }
                            } else {
                                Icon(icon, contentDescription = null)
                            }
                        },
                        label = { Text(t(label), fontSize = 11.sp, maxLines = 1) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Palette.green,
                            selectedTextColor = Palette.green,
                            indicatorColor = Palette.green.copy(alpha = 0.12f),
                            unselectedIconColor = Palette.tabUnselected,
                            unselectedTextColor = Palette.tabUnselected,
                        ),
                    )
                }
            }
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when (Nav.tab) {
                0 -> HomeScreen()
                1 -> PrayersScreen()
                2 -> LockScreen()
                3 -> QuranScreen()
                else -> ProfileScreen()
            }
        }
    }
}

@Composable
fun <T> remember3(a: Any?, b: Any?, calc: () -> T): T = androidx.compose.runtime.remember(a, b) { calc() }
