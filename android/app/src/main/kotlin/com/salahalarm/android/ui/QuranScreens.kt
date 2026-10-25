package com.salahalarm.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.salahalarm.android.Graph
import com.salahalarm.android.I18n
import com.salahalarm.android.data.Api
import com.salahalarm.android.data.LastRead
import com.salahalarm.android.t
import com.salahalarm.android.tf
import kotlinx.coroutines.launch

private object QuranCache {
    var surahs: List<Api.Surah> = emptyList()
    var lang: String = ""
}

/** Port of iOS QuranTabView: search, continue reading, bookmarks, surah list. */
@Composable
fun QuranScreen() {
    val repo = Graph.repo
    val lastRead by repo.lastRead.collectAsState()
    val bookmarks by repo.bookmarks.collectAsState()
    var surahs by remember { mutableStateOf(QuranCache.surahs) }
    var error by remember { mutableStateOf<String?>(null) }
    var query by remember { mutableStateOf("") }
    val lang = I18n.lang

    LaunchedEffect(lang) {
        if (QuranCache.surahs.isEmpty() || QuranCache.lang != lang) {
            try {
                QuranCache.surahs = Api.surahs(lang)
                QuranCache.lang = lang
                surahs = QuranCache.surahs
                error = null
            } catch (e: Exception) {
                if (surahs.isEmpty()) error = t("Could not load surahs. Check your connection and try again.")
            }
        }
    }

    val filtered = surahs.filter {
        query.isBlank() || it.name.contains(query, true) || it.translatedName.contains(query, true) ||
            it.arabicName.contains(query) || it.number.toString() == query.trim()
    }

    LazyColumn(contentPadding = PaddingValues(horizontal = 20.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Column {
                Text(t("Quran"), fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Secondary(t("Read with focus and resume where you left off."), size = 13)
            }
        }
        item {
            OutlinedTextField(
                value = query, onValueChange = { query = it }, singleLine = true,
                leadingIcon = { Icon(Icons.Filled.Search, null) },
                placeholder = { Text(t("Search surah")) },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
                colors = OutlinedTextFieldDefaults.colors(focusedContainerColor = Color.White, unfocusedContainerColor = Color.White),
            )
        }
        lastRead?.let { lr ->
            item {
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Palette.green)
                        .clickable { Nav.push(Route.Reader(lr.surah, lr.name, lr.ayah)) }.padding(18.dp),
                ) {
                    Text(t("Continue Reading"), color = Color.White.copy(alpha = 0.85f), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    Text(lr.name, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    Text(tf("Ayah %@", lr.ayah), color = Color.White.copy(alpha = 0.85f), fontSize = 14.sp)
                }
            }
        }
        if (bookmarks.isNotEmpty()) {
            item { SectionTitle(t("Bookmarks")) }
            items(bookmarks, key = { "b" + it.id }) { b ->
                val s = surahs.firstOrNull { it.number == b.surah }
                val name = s?.name ?: "Surah ${b.surah}"
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Color.White)
                        .clickable { Nav.push(Route.Reader(b.surah, name, b.ayah)) }.padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.Bookmark, null, tint = Palette.gold)
                    Spacer(Modifier.width(10.dp))
                    Text(name, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                    Secondary(tf("Ayah %@", b.ayah), size = 13)
                }
            }
        }
        item { SectionTitle(t("Surahs")) }
        if (error != null) item { Secondary(error!!) }
        if (surahs.isEmpty() && error == null) {
            item { Box(Modifier.fillMaxWidth().padding(30.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Palette.green) } }
        } else if (filtered.isEmpty() && error == null) {
            item { Secondary(t("No surahs found")) }
        }
        items(filtered, key = { it.number }) { s ->
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Color.White)
                    .clickable { Nav.push(Route.Reader(s.number, s.name)) }.padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.size(36.dp).clip(CircleShape).background(Palette.green.copy(alpha = 0.12f)), contentAlignment = Alignment.Center) {
                    Text("${s.number}", color = Palette.green, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                }
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(s.name, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                    Secondary(tf("%@ • %d ayahs", s.translatedName, s.ayahCount), size = 12)
                }
                Text(s.arabicName, fontSize = 18.sp, color = Palette.gold)
            }
        }
    }
}

/** Port of iOS QuranReadingView: Arabic with translation, bookmarks, font size, resume position. */
@Composable
fun QuranReader(route: Route.Reader, onBack: () -> Unit) {
    val repo = Graph.repo
    val prefs by repo.quranPrefs.collectAsState()
    val bookmarks by repo.bookmarks.collectAsState()
    val ayahs = remember(route.surah) { mutableStateListOf<Api.Ayah>() }
    var page by remember(route.surah) { mutableIntStateOf(0) }
    var totalPages by remember(route.surah) { mutableIntStateOf(1) }
    var loading by remember(route.surah) { mutableStateOf(false) }
    var error by remember(route.surah) { mutableStateOf<String?>(null) }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    val lang = I18n.lang

    suspend fun loadNext() {
        if (loading || page >= totalPages) return
        loading = true
        try {
            val res = Api.ayahs(route.surah, page + 1, lang)
            ayahs.addAll(res.ayahs)
            page = res.page
            totalPages = res.totalPages
            error = null
        } catch (e: Exception) {
            error = t("No verses available")
        } finally {
            loading = false
        }
    }

    LaunchedEffect(route.surah) {
        loadNext()
        // Resume at the saved ayah, loading pages until it's there.
        val target = route.ayah
        if (target != null && target > 1) {
            while (ayahs.none { it.number == target } && page < totalPages && error == null) loadNext()
            val index = ayahs.indexOfFirst { it.number == target }
            if (index >= 0) listState.scrollToItem(index + 1)
        }
    }

    LaunchedEffect(listState) {
        snapshotFlow { listState.firstVisibleItemIndex to listState.layoutInfo.totalItemsCount }.collect { (first, total) ->
            val visible = ayahs.getOrNull((first - 1).coerceAtLeast(0))
            if (visible != null) repo.saveLastRead(LastRead(route.surah, route.name, visible.number))
            if (total > 0 && first + 8 >= total) scope.launch { loadNext() }
        }
    }

    Column(Modifier.fillMaxSize().background(Palette.cream).systemBarsPadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = t("Back")) }
            Text(route.name, fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            IconButton(onClick = { repo.updateQuranPrefs { it.copy(fontSize = (it.fontSize - 2).coerceAtLeast(16f)) } }) {
                Icon(Icons.Filled.Remove, null)
            }
            IconButton(onClick = { repo.updateQuranPrefs { it.copy(fontSize = (it.fontSize + 2).coerceAtMost(40f)) } }) {
                Icon(Icons.Filled.Add, null)
            }
            IconButton(onClick = { repo.updateQuranPrefs { it.copy(showTranslation = !it.showTranslation) } }) {
                Icon(Icons.Filled.Translate, null, tint = if (prefs.showTranslation) Palette.green else Palette.textSecondary)
            }
        }
        LazyColumn(state = listState, contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                if (route.surah != 1 && route.surah != 9) {
                    Text(
                        "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ", fontSize = (prefs.fontSize + 2).sp, color = Palette.green,
                        textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                    )
                }
            }
            items(ayahs, key = { it.key }) { a ->
                val marked = bookmarks.any { it.surah == route.surah && it.ayah == a.number }
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(30.dp).clip(CircleShape).background(Palette.green.copy(alpha = 0.12f)), contentAlignment = Alignment.Center) {
                            Text("${a.number}", color = Palette.green, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                        Spacer(Modifier.weight(1f))
                        IconButton(onClick = { repo.toggleBookmark(route.surah, a.number) }) {
                            Icon(if (marked) Icons.Filled.Bookmark else Icons.Filled.BookmarkBorder, null, tint = Palette.gold)
                        }
                    }
                    androidx.compose.runtime.CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                        Text(a.arabic, fontSize = prefs.fontSize.sp, lineHeight = (prefs.fontSize * 1.9f).sp, modifier = Modifier.fillMaxWidth())
                    }
                    if (prefs.showTranslation && a.translation.isNotEmpty()) {
                        Text(a.translation, fontSize = 15.sp, color = Palette.textSecondary, lineHeight = 22.sp)
                    }
                }
            }
            item {
                when {
                    loading -> Box(Modifier.fillMaxWidth().padding(20.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = Palette.green)
                    }
                    error != null -> Secondary(error!!)
                    else -> Spacer(Modifier.height(24.dp))
                }
            }
        }
    }
}
