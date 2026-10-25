import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
duas = re.findall(r'Dua\(english:\s*"((?:[^"\\]|\\.)*)",\s*arabic:\s*"((?:[^"\\]|\\.)*)",\s*reference:\s*"((?:[^"\\]|\\.)*)"\)', src)
themes = re.findall(r'DuaTheme\(topHex:\s*"(#\w+)",\s*bottomHex:\s*"(#\w+)",\s*accentHex:\s*"(#\w+)"\)', src)
esc = lambda s: s.replace("\\\"", "\"").replace("\\", "\\\\").replace("\"", "\\\"").replace("$", "\\$")
out = ["// Generated from Ramadan Pro/Utils/DuaLibrary.swift by android/scripts/gen_duas.py. Do not edit.",
       "package com.salahalarm.core", "", "import java.time.Instant", "",
       "data class Dua(val english: String, val arabic: String, val reference: String)",
       "data class DuaTheme(val top: Long, val bottom: Long, val accent: Long)", "",
       "object DuaLibrary {",
       "    /** Same 30-minute rotation as the iOS app and widget. */",
       "    fun dua(at: Instant): Dua = all[index(at, all.size)]",
       "    fun theme(at: Instant): DuaTheme = themes[index(at, themes.size, 7)]", "",
       "    fun index(at: Instant, count: Int, salt: Long = 0): Int {",
       "        val bucket = maxOf(0L, at.epochSecond) / 1800",
       "        // Swift wraps in UInt64; Long multiply wraps the same way, so compare unsigned.",
       "        val scrambled = (bucket + salt) * 2654435761L",
       "        return java.lang.Long.remainderUnsigned(scrambled, count.toLong()).toInt()",
       "    }", "",
       "    val themes = listOf("]
for t, b, a in themes:
    h = lambda x: "0xFF" + x[1:].upper()
    out.append(f"        DuaTheme({h(t)}, {h(b)}, {h(a)}),")
out += ["    )", "", "    val all = listOf("]
for e, a, r in duas:
    out.append(f'        Dua("{esc(e)}", "{esc(a)}", "{esc(r)}"),')
out += ["    )", "}", ""]
open(sys.argv[2], "w", encoding="utf-8").write("\n".join(out))
print(len(duas), "duas", len(themes), "themes")
