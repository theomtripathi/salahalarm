# SalahAlarm growth release 2.4

## Diagnosis (20 September 2026)

- App Store Search remains near 10 product-page views per day.
- App Referrer traffic fell from roughly 12 views per day over 90 days to roughly 1 per day in the last week.
- The previous organic scheduler completed its 60-day queue, which explains the referral cliff.
- The 90-day product-page conversion rate is 6.81%, down 35.3%.
- The app has 1,310 first-time downloads but only 13 ratings (4.85 stars).
- US search positions measured from Apple's public search endpoint:
  - `fajr alarm`: #18
  - `prayer alarm`: #42
  - `azan alarm`: #47
  - `salah`: #95
  - `prayer times`, `muslim prayer`, `qibla`: outside the top 100

## Product change implemented

The app now asks for a native App Store rating after a user has opened the subscribed app on two distinct days and confirmed at least three prayers. It records the request once, never interrupts that user again, and sends `rating_prompt_requested` to PostHog and AppsFlyer.

This timing targets a completed value moment instead of asking during onboarding or at launch.

## App Store metadata for the next version

**Name (30/30)**  
`Salah Alarm: Prayer Time Quran`

**Subtitle (30/30)**  
`Fajr, Azan, Qibla & Muslim Dua`

**Keyword field (96/100)**  
`namaz,athan,adhan,ramadan,islam,islamic,mosque,kaaba,compass,tracker,habit,reminder,widget,dhikr`

**Promotional text (147/170; can be changed on the live version)**  
`Never miss Fajr again. Dismiss the alarm at your prayer mat, follow accurate prayer times, read Quran, find Qibla, and build a lasting salah habit.`

**What's New**  
`Build a stronger salah habit with a more reliable prayer experience, improved onboarding, and faster subscription status updates. We also fixed bugs affecting alarms, background refresh, and app stability.`

## Screenshot message order

The first three frames should sell one clear job before listing utilities:

1. `Never Miss Fajr Again` — alarm sounding, prayer mat dismissal visible.
2. `Your Alarm Stops at the Prayer Mat` — show the scan/dismiss interaction.
3. `Stay Accountable for Every Salah` — phone lock or prayer streak proof.
4. `Accurate Prayer Times, Anywhere`
5. `Quran, Qibla, Duas & Widgets`

## Organic referral recovery

Restart content with varied assets and hooks rather than repeating one clip and caption. Use the existing strongest videos in `/Users/pc/Desktop/salahalarm videos` and publish one post per day per active account for 30 days. Every caption should lead with one pain point and use a measurable App Store campaign link.

Initial hook rotation:

1. `If you keep snoozing Fajr, put the off switch on your prayer mat.`
2. `This alarm makes you get up before it stops.`
3. `A prayer reminder is easy to swipe away. Accountability is harder.`
4. `I stopped missing Fajr when my phone made me walk to my prayer mat.`
5. `Your alarm should know when Fajr changes every day.`

Track each platform with a distinct App Store campaign link so App Analytics can identify which account restored referrals.

## Success criteria for the first 14 days

- Product-page conversion: 6.81% → at least 9%.
- App Referrer page views: 1/day → at least 8/day.
- Rating volume: 13 → at least 25 while remaining above 4.6 stars.
- `fajr alarm`: #18 → top 12.
- `prayer alarm`: #42 → top 30.
- No increase in crash rate in version 2.4.
