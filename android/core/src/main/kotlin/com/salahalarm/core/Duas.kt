// Generated from Ramadan Pro/Utils/DuaLibrary.swift by android/scripts/gen_duas.py. Do not edit.
package com.salahalarm.core

import java.time.Instant

data class Dua(val english: String, val arabic: String, val reference: String)
data class DuaTheme(val top: Long, val bottom: Long, val accent: Long)

object DuaLibrary {
    /** Same 30-minute rotation as the iOS app and widget. */
    fun dua(at: Instant): Dua = all[index(at, all.size)]
    fun theme(at: Instant): DuaTheme = themes[index(at, themes.size, 7)]

    fun index(at: Instant, count: Int, salt: Long = 0): Int {
        val bucket = maxOf(0L, at.epochSecond) / 1800
        // Swift wraps in UInt64; Long multiply wraps the same way, so compare unsigned.
        val scrambled = (bucket + salt) * 2654435761L
        return java.lang.Long.remainderUnsigned(scrambled, count.toLong()).toInt()
    }

    val themes = listOf(
        DuaTheme(0xFF1F7A44, 0xFF0E4A27, 0xFFF5D56A),
        DuaTheme(0xFF1D3557, 0xFF0E1D33, 0xFFF1C879),
        DuaTheme(0xFF4A2C6D, 0xFF2A1741, 0xFFE8C9F5),
        DuaTheme(0xFF0F6E6B, 0xFF07403E, 0xFFBDEDE3),
        DuaTheme(0xFF7A4A21, 0xFF4A2A0E, 0xFFF5DFA8),
        DuaTheme(0xFF701C33, 0xFF3D0E1C, 0xFFF5C6C6),
        DuaTheme(0xFF2E3A8C, 0xFF161D4D, 0xFFC7D0FF),
        DuaTheme(0xFF33502F, 0xFF1A2C18, 0xFFD9E8C5),
    )

    val all = listOf(
        Dua("Our Lord, grant us good in this world and the Hereafter.", "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ", "Quran 2:201"),
        Dua("My Lord, increase me in knowledge.", "رَبِّ زِدْنِي عِلْمًا", "Quran 20:114"),
        Dua("My Lord, forgive me and have mercy upon me.", "رَبِّ اغْفِرْ وَارْحَمْ وَأَنْتَ خَيْرُ الرَّاحِمِينَ", "Quran 23:118"),
        Dua("My Lord, make me one who establishes prayer.", "رَبِّ اجْعَلْنِي مُقِيمَ الصَّلَاةِ", "Quran 14:40"),
        Dua("My Lord, expand my chest.", "رَبِّ اشْرَحْ لِي صَدْرِي", "Quran 20:25"),
        Dua("Ease my task for me.", "وَيَسِّرْ لِي أَمْرِي", "Quran 20:26"),
        Dua("Untie the knot from my tongue.", "وَاحْلُلْ عُقْدَةً مِن لِّسَانِي", "Quran 20:27"),
        Dua("Increase me in patience.", "رَبَّنَا أَفْرِغْ عَلَيْنَا صَبْرًا", "Quran 2:250"),
        Dua("Our Lord, do not let our hearts deviate.", "رَبَّنَا لَا تُزِغْ قُلُوبَنَا", "Quran 3:8"),
        Dua("Our Lord, pour upon us patience and let us die as Muslims.", "رَبَّنَا أَفْرِغْ عَلَيْنَا صَبْرًا وَتَوَفَّنَا مُسْلِمِينَ", "Quran 7:126"),
        Dua("My Lord, forgive me, my parents, and the believers.", "رَبَّنَا اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ", "Quran 14:41"),
        Dua("Our Lord, accept this from us.", "رَبَّنَا تَقَبَّلْ مِنَّا", "Quran 2:127"),
        Dua("Our Lord, forgive us our sins.", "رَبَّنَا اغْفِرْ لَنَا ذُنُوبَنَا", "Quran 3:16"),
        Dua("Our Lord, forgive us and have mercy on us.", "رَبَّنَا اغْفِرْ لَنَا وَارْحَمْنَا", "Quran 23:109"),
        Dua("Our Lord, we have wronged ourselves.", "رَبَّنَا ظَلَمْنَا أَنفُسَنَا", "Quran 7:23"),
        Dua("My Lord, forgive me.", "رَبِّ اغْفِرْ لِي", "Quran 71:28"),
        Dua("My Lord, have mercy on them as they raised me when I was young.", "رَبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا", "Quran 17:24"),
        Dua("My Lord, I am truly in need of whatever good You send me.", "رَبِّ إِنِّي لِمَا أَنزَلْتَ إِلَيَّ مِنْ خَيْرٍ فَقِيرٌ", "Quran 28:24"),
        Dua("You are my Protector in this world and the Hereafter.", "أَنتَ وَلِيِّي فِي الدُّنْيَا وَالْآخِرَةِ", "Quran 12:101"),
        Dua("My Lord, increase me in gratitude.", "رَبِّ أَوْزِعْنِي أَنْ أَشْكُرَ نِعْمَتَكَ", "Quran 27:19"),
        Dua("O Allah, forgive me.", "اللَّهُمَّ اغْفِرْ لِي", "Sahih al-Bukhari"),
        Dua("O Allah, guide me.", "اللَّهُمَّ اهْدِنِي", "Sahih Muslim"),
        Dua("O Allah, grant me well-being.", "اللَّهُمَّ عَافِنِي", "Jami' al-Tirmidhi"),
        Dua("O Allah, You are Pardoning and love pardon, so pardon me.", "اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي", "Jami' al-Tirmidhi"),
        Dua("O Turner of hearts, keep my heart firm upon Your religion.", "يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ", "Jami' al-Tirmidhi"),
        Dua("O Allah, I ask You for Paradise.", "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْجَنَّةَ", "Sunan Abi Dawud"),
        Dua("O Allah, I seek refuge in You from the Fire.", "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ النَّارِ", "Sunan Abi Dawud"),
        Dua("O Allah, grant me beneficial knowledge.", "اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا", "Sunan Ibn Majah"),
        Dua("O Allah, help me remember You, thank You, and worship You well.", "اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ", "Sunan Abi Dawud"),
        Dua("O Allah, make the Quran the spring of my heart.", "اللَّهُمَّ اجْعَلِ الْقُرْآنَ رَبِيعَ قَلْبِي", "Musnad Ahmad"),
        Dua("O Allah, suffice me with what You have made lawful.", "اللَّهُمَّ اكْفِنِي بِحَلَالِكَ عَنْ حَرَامِكَ", "Jami' al-Tirmidhi"),
        Dua("O Allah, enrich me by Your bounty.", "وَأَغْنِنِي بِفَضْلِكَ عَمَّنْ سِوَاكَ", "Jami' al-Tirmidhi"),
        Dua("O Allah, make my affairs easy.", "اللَّهُمَّ يَسِّرْ لِي أَمْرِي", "Based on Quran 20:26"),
        Dua("O Allah, bless me in my time.", "اللَّهُمَّ بَارِكْ لِي فِي وَقْتِي", "Prophetic supplications"),
        Dua("O Allah, grant me patience.", "اللَّهُمَّ ارْزُقْنِي الصَّبْرَ", "Prophetic supplications"),
        Dua("O Allah, increase my faith.", "اللَّهُمَّ زِدْنِي إِيمَانًا", "Supplication of the early Muslims"),
        Dua("O Allah, purify my heart.", "اللَّهُمَّ طَهِّرْ قَلْبِي", "Prophetic supplications"),
        Dua("O Allah, grant me sincerity.", "اللَّهُمَّ ارْزُقْنِي الْإِخْلَاصَ", "Islamic supplication"),
        Dua("O Allah, make me among the grateful.", "اللَّهُمَّ اجْعَلْنِي مِنَ الشَّاكِرِينَ", "Islamic supplication"),
        Dua("O Allah, make me among the patient.", "اللَّهُمَّ اجْعَلْنِي مِنَ الصَّابِرِينَ", "Islamic supplication"),
        Dua("O Allah, grant me a righteous heart.", "اللَّهُمَّ ارْزُقْنِي قَلْبًا سَلِيمًا", "Based on Quran 26:89"),
        Dua("O Allah, keep me steadfast.", "اللَّهُمَّ ثَبِّتْنِي", "Prophetic supplications"),
        Dua("O Allah, forgive all my sins.", "اللَّهُمَّ اغْفِرْ لِي ذُنُوبِي كُلَّهَا", "Sahih Muslim"),
        Dua("O Allah, make me among Your righteous servants.", "اللَّهُمَّ اجْعَلْنِي مِنْ عِبَادِكَ الصَّالِحِينَ", "Islamic supplication"),
        Dua("O Allah, grant me a good ending.", "اللَّهُمَّ اخْتِمْ لِي بِخَيْرٍ", "Islamic du'a"),
        Dua("O Allah, let me die as a Muslim.", "تَوَفَّنِي مُسْلِمًا", "Quran 12:101"),
        Dua("O Allah, unite us in Paradise.", "اللَّهُمَّ اجْمَعْنَا فِي الْجَنَّةِ", "Islamic supplication"),
        Dua("O Allah, accept my repentance.", "اللَّهُمَّ تُبْ عَلَيَّ", "Sunan Abi Dawud"),
        Dua("O Allah, make the best of my deeds the last of them.", "اللَّهُمَّ اجْعَلْ خَيْرَ عَمَلِي آخِرَهُ", "Musnad Ahmad"),
        Dua("O Allah, bless Muhammad and the family of Muhammad.", "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ", "Sahih al-Bukhari"),
        Dua("Do not lose hope in the mercy of Allah.", "لَا تَقْنَطُوا مِن رَّحْمَةِ اللَّهِ", "Quran 39:53"),
        Dua("Allah is enough for us, and the best Trustee.", "حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ", "Quran 3:173"),
        Dua("Whoever fears Allah, He will make a way out.", "وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا", "Quran 65:2"),
        Dua("And He will provide from where they never imagined.", "وَيَرْزُقْهُ مِنْ حَيْثُ لَا يَحْتَسِبُ", "Quran 65:3"),
        Dua("Whoever relies upon Allah, He is enough for them.", "وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ", "Quran 65:3"),
        Dua("My Lord is with me. He will guide me.", "كَلَّا إِنَّ مَعِيَ رَبِّي سَيَهْدِينِ", "Quran 26:62"),
        Dua("Allah is the best Protector.", "فَاللَّهُ خَيْرٌ حَافِظًا", "Quran 12:64"),
        Dua("Your Lord has not abandoned you.", "مَا وَدَّعَكَ رَبُّكَ وَمَا قَلَى", "Quran 93:3"),
        Dua("Your Lord will soon give you, and you will be satisfied.", "وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَى", "Quran 93:5"),
        Dua("Surely, Allah is with those who are mindful of Him.", "إِنَّ اللَّهَ مَعَ الَّذِينَ اتَّقَوْا", "Quran 16:128"),
        Dua("Be patient. Indeed, the promise of Allah is true.", "فَاصْبِرْ إِنَّ وَعْدَ اللَّهِ حَقٌّ", "Quran 30:60"),
        Dua("My success is only through Allah.", "وَمَا تَوْفِيقِي إِلَّا بِاللَّهِ", "Quran 11:88"),
        Dua("He knows what is in every heart.", "عَلِيمٌ بِذَاتِ الصُّدُورِ", "Quran 67:13"),
        Dua("Allah is with the doers of good.", "إِنَّ اللَّهَ مَعَ الْمُحْسِنِينَ", "Quran 29:69"),
        Dua("The Hereafter is better for you than this world.", "وَلَلْآخِرَةُ خَيْرٌ لَّكَ مِنَ الْأُولَى", "Quran 93:4"),
        Dua("Remember Allah often so that you may succeed.", "وَاذْكُرُوا اللَّهَ كَثِيرًا لَّعَلَّكُمْ تُفْلِحُونَ", "Quran 62:10"),
        Dua("Allah loves those who purify themselves.", "وَاللَّهُ يُحِبُّ الْمُطَّهِّرِينَ", "Quran 9:108"),
        Dua("Allah loves those who repent.", "إِنَّ اللَّهَ يُحِبُّ التَّوَّابِينَ", "Quran 2:222"),
        Dua("The patient will be rewarded without measure.", "إِنَّمَا يُوَفَّى الصَّابِرُونَ أَجْرَهُم بِغَيْرِ حِسَابٍ", "Quran 39:10"),
        Dua("Whoever does an atom's weight of good will see it.", "فَمَن يَعْمَلْ مِثْقَالَ ذَرَّةٍ خَيْرًا يَرَهُ", "Quran 99:7"),
        Dua("Every soul shall taste death.", "كُلُّ نَفْسٍ ذَائِقَةُ الْمَوْتِ", "Quran 3:185"),
        Dua("Race toward forgiveness from your Lord.", "سَابِقُوا إِلَىٰ مَغْفِرَةٍ مِّن رَّبِّكُمْ", "Quran 57:21"),
        Dua("So flee to Allah.", "فَفِرُّوا إِلَى اللَّهِ", "Quran 51:50"),
        Dua("Call upon Me; I will answer you.", "ادْعُونِي أَسْتَجِبْ لَكُمْ", "Quran 40:60"),
        Dua("We are closer to him than his jugular vein.", "وَنَحْنُ أَقْرَبُ إِلَيْهِ مِنْ حَبْلِ الْوَرِيدِ", "Quran 50:16"),
        Dua("Indeed, Allah is with the patient.", "إِنَّ اللَّهَ مَعَ الصَّابِرِينَ", "Quran 2:153"),
        Dua("Allah does not waste the reward of the righteous.", "إِنَّ اللَّهَ لَا يُضِيعُ أَجْرَ الْمُحْسِنِينَ", "Quran 9:120"),
        Dua("Indeed, the honor belongs to Allah.", "فَإِنَّ الْعِزَّةَ لِلَّهِ جَمِيعًا", "Quran 10:65"),
        Dua("Your Lord is never unjust.", "وَمَا رَبُّكَ بِظَلَّامٍ لِّلْعَبِيدِ", "Quran 41:46"),
        Dua("Whoever is grateful, it is for their own good.", "وَمَن شَكَرَ فَإِنَّمَا يَشْكُرُ لِنَفْسِهِ", "Quran 31:12"),
        Dua("The strongest are those who control their anger.", "لَيْسَ الشَّدِيدُ بِالصُّرَعَةِ وَلَكِنَّ الشَّدِيدَ الَّذِي يَمْلِكُ نَفْسَهُ عِنْدَ الْغَضَبِ", "Sahih al-Bukhari"),
        Dua("The most beloved deeds to Allah are those done consistently.", "أَحَبُّ الْأَعْمَالِ إِلَى اللَّهِ أَدْوَمُهَا وَإِنْ قَلَّ", "Sahih al-Bukhari & Muslim"),
        Dua("Allah does not look at your appearance but at your hearts and deeds.", "إِنَّ اللَّهَ لَا يَنْظُرُ إِلَى صُوَرِكُمْ وَلَكِنْ يَنْظُرُ إِلَى قُلُوبِكُمْ وَأَعْمَالِكُمْ", "Sahih Muslim"),
        Dua("The best people are those most beneficial to others.", "خَيْرُ النَّاسِ أَنْفَعُهُمْ لِلنَّاسِ", "Al-Mu'jam al-Awsat"),
        Dua("None of you truly believes until he loves for his brother what he loves for himself.", "لَا يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ", "Sahih al-Bukhari & Muslim"),
        Dua("Whoever remains silent is saved.", "مَنْ صَمَتَ نَجَا", "Jami' al-Tirmidhi"),
        Dua("Be in this world as though you are a traveler.", "كُنْ فِي الدُّنْيَا كَأَنَّكَ غَرِيبٌ أَوْ عَابِرُ سَبِيلٍ", "Sahih al-Bukhari"),
        Dua("Paradise lies beneath the feet of mothers.", "الْجَنَّةُ تَحْتَ أَقْدَامِ الْأُمَّهَاتِ", "Islamic saying"),
        Dua("The believer is not one who insults others.", "لَيْسَ الْمُؤْمِنُ بِالطَّعَّانِ وَلَا اللَّعَّانِ", "Jami' al-Tirmidhi"),
        Dua("The nearest to me on the Day of Judgment are those with the best character.", "إِنَّ مِنْ أَحَبِّكُمْ إِلَيَّ أَحَاسِنَكُمْ أَخْلَاقًا", "Jami' al-Tirmidhi"),
        Dua("The world is a prison for the believer and a paradise for the disbeliever.", "الدُّنْيَا سِجْنُ الْمُؤْمِنِ وَجَنَّةُ الْكَافِرِ", "Sahih Muslim"),
        Dua("Allah is Beautiful and loves beauty.", "إِنَّ اللَّهَ جَمِيلٌ يُحِبُّ الْجَمَالَ", "Sahih Muslim"),
        Dua("Whoever humbles himself for Allah, Allah will raise him.", "وَمَا تَوَاضَعَ أَحَدٌ لِلَّهِ إِلَّا رَفَعَهُ اللَّهُ", "Sahih Muslim"),
        Dua("Every act of kindness is charity.", "كُلُّ مَعْرُوفٍ صَدَقَةٌ", "Sahih al-Bukhari"),
        Dua("Exchange gifts and you will love one another.", "تَهَادُوا تَحَابُّوا", "Al-Adab al-Mufrad"),
        Dua("The most perfect believers are those with the best character.", "أَكْمَلُ الْمُؤْمِنِينَ إِيمَانًا أَحْسَنُهُمْ خُلُقًا", "Jami' al-Tirmidhi"),
        Dua("Whoever eases another's hardship, Allah will ease theirs.", "مَنْ نَفَّسَ عَنْ مُؤْمِنٍ كُرْبَةً نَفَّسَ اللَّهُ عَنْهُ", "Sahih Muslim"),
        Dua("The one who remembers Allah and the one who does not are like the living and the dead.", "مَثَلُ الَّذِي يَذْكُرُ رَبَّهُ وَالَّذِي لَا يَذْكُرُهُ كَمَثَلِ الْحَيِّ وَالْمَيِّتِ", "Sahih al-Bukhari"),
        Dua("Whoever seeks forgiveness, Allah will make a way out for them.", "مَنْ لَزِمَ الِاسْتِغْفَارَ جَعَلَ اللَّهُ لَهُ مِنْ كُلِّ هَمٍّ فَرَجًا", "Sunan Abi Dawud"),
        Dua("This world is provision, and the best provision is a righteous spouse.", "الدُّنْيَا مَتَاعٌ وَخَيْرُ مَتَاعِ الدُّنْيَا الْمَرْأَةُ الصَّالِحَةُ", "Sahih Muslim"),
    )
}
