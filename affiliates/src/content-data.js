// The content library: one entry per content type, each rendered on its own page.
// `L` is the affiliate's context: { link, linkUrl, username, loggedIn, daysToRamadan, daysWords }.
// View counts come from the Salah Alarm research library (Oct-Nov 2026); open the post for today's number.

export const RAMADAN_2027 = '2027-02-08'; // expected first day of Ramadan 2027
export const ENTRIES_CLOSE = '2027-01-09';

const SHOTS = [
  ['store-01.webp', 'Home: next prayer and today\'s log'],
  ['store-02.webp', 'Scan the prayer mat to log a prayer'],
  ['store-03.webp', 'Fajr alarm you can\'t ignore'],
  ['store-04.webp', 'SalahLock: apps blocked until you pray'],
  ['store-05.webp', 'Streak: stay consistent'],
  ['store-06.webp', 'Lock screen duas'],
  ['store-07.webp', 'Dua widget'],
  ['store-08.webp', 'Everything in one place'],
];
export const SCREENSHOTS = SHOTS.map(([file, label]) => ({ src: `/img/app/${file}`, label }));

export const BENEFITS = [
  'A Fajr alarm that keeps ringing until you get up and scan your prayer mat. No snooze.',
  'SalahLock blocks distracting apps (TikTok, Instagram, games) at prayer time until you\'ve prayed.',
  'Log all 5 prayers in a second by scanning your mat, and keep a daily streak.',
  'Accurate prayer times for your location, with the adhan.',
  'Duas on the lock screen and a home-screen dua widget.',
  'Ramadan 2027 challenge: log your 5 daily prayers and get a chance in the Free Makkah Trip draw.',
];

// Hook categories from the clipping-campaign reference (Scroll The Bible style), adapted to Salah Alarm.
export const HOOK_STYLES = {
  'Concept reveal': [
    'Someone made an alarm that won\'t stop until you\'re on your prayer mat...',
    'My friend built an app that locks TikTok until I pray...',
    'There\'s an app that makes you scan your prayer mat to turn off the Fajr alarm...',
    'This app turned my phone into a reason to pray, not a reason to skip...',
    'Someone finally made a Fajr alarm you can\'t snooze...',
  ],
  'Receipt': [
    'I haven\'t missed Fajr in 30 days...',
    'I\'ve prayed more on time this month than the whole of last year...',
    'Day 47 of praying all 5. Here\'s what changed...',
    'My screen time went down 2 hours a day after I did this...',
    'I used to wake up at 9. Now I\'m up for Fajr every day...',
  ],
  'Self-trick': [
    'This is how I tricked myself into never missing Fajr...',
    'How I trick myself into praying on time when I\'m lazy...',
    'The one setting that got me up for Fajr every single day...',
    'I made it impossible for myself to skip Salah...',
    'How I stopped scrolling through Asr...',
  ],
  'Guilt-flip': [
    'I stopped missing Fajr by making my phone work against me...',
    'I used to feel guilty every morning I missed Fajr. Not anymore...',
    'I was on TikTok for 3 hours but "too busy" to pray 5 minutes...',
    'Your phone knows when you skip Fajr. Mine doesn\'t let me anymore...',
    'I stopped hitting snooze on Fajr when my alarm started fighting back...',
  ],
};

export const CTAS = (L) => [
  `My friend built an app called Salah Alarm, you can download it. ${L.loggedIn ? `Link: ${L.link}` : 'Link in bio.'}`,
  'It\'s called Salah Alarm. Link in my bio.',
  'Search "Salah Alarm" or tap the link in my bio.',
  'Comment FAJR and I\'ll send you the link.',
  'If you keep missing Fajr, this is your sign. Salah Alarm, link in bio.',
  'Send this to the friend who sleeps through Fajr.',
];

export const BIO_LINES = (L) => [
  `Never miss Fajr again 🌙 Salah Alarm 👇\n${L.link}`,
  `Pray on time, every time ⏰ Free Makkah Trip draw 🕋\n${L.link}`,
  `The alarm that wakes you for Fajr 🤲\n${L.link}`,
];

// Numbers to words for the countdown line ("Ninety-one days from now").
export function numberWords(n) {
  const ones = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];
  const tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];
  if (n < 20) return ones[n];
  if (n < 100) return tens[Math.floor(n / 10)] + (n % 10 ? `-${ones[n % 10]}` : '');
  if (n < 1000) return `${ones[Math.floor(n / 100)]} hundred${n % 100 ? ` and ${numberWords(n % 100)}` : ''}`;
  return String(n);
}

export function daysUntil(dateIso, now = new Date()) {
  const t = Date.UTC(...dateIso.split('-').map((v, i) => (i === 1 ? Number(v) - 1 : Number(v))));
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  return Math.max(0, Math.round((t - today) / 864e5));
}

const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);

// Om's "Free Makkah Trip Challenge" prompt, with the CTA pointed at the affiliate's own link.
export function makkahPrompt(L) {
  const n = L.daysToRamadan;
  const words = cap(numberWords(n));
  const spoken = L.loggedIn
    ? `Salah Alarm dot com slash ${L.username.replace(/_/g, ' underscore ')}`
    : '[read your link out loud here]';
  return `Full prompt: "The Free Makkah Trip Challenge" (${n} days to Ramadan) short
Copy everything below the line into the AI. It is written to stand on its own: style, characters, script, every shot, sound, end card and checks.
______________________________________________

ROLE AND GOAL
You are an animator and editor. Make one vertical promo short for the app Salah Alarm (a prayer alarm and prayer-tracking app).

The short announces the Ramadan 2027 "Free Makkah Trip" challenge:
- Users log their 5 daily prayers in the app to earn entries into a free prize draw.
- The prize is Umrah for two.
- The short ends on a scannable QR code card.
Overall feel: warm and hopeful, a little playful, never preachy. It is an ad, but it should feel like a tiny story.

OUTPUT SPECS
Format: 1080 x 1920 vertical (9:16), 30 fps, H.264 MP4 (CRF ~18), AAC audio.
Length: about 41 s. The video ends ~0.3 s after the link is read. Nothing comes after it.
Audio: integrated loudness -14 LUFS, true peak under -1 dBTP.
YouTube copy: under 10 MB (~1650 kbps video, 96 kbps audio, faststart).
Language: English only.
Safe area: keep all text out of the top 12% and bottom 20% of the frame, where the platform UI sits.

VISUAL STYLE: "2D cartoon characters in a colourful 3D world"
World
- A real 3D scene (three.js-like) with painted, saturated textures and thin black ink outlines on all geometry, like a comic drawn over 3D.
- Big saturated skies with soft painted clouds. Fog takes the horizon colour.
- Depth of field: the background is softly blurred whenever the camera is close to a character.
- A subtle bloom on highlights and a gentle warm grade.
Characters
- Characters are flat 2D cartoon cards (billboards that always face the camera) standing in the 3D world.
- Bean-shaped heads, stick-like limbs, a thick plum/dark-purple variable-width outline, and simple faces with big expressive eyes and mouths.
- They are lit by the scene light (two-tone shading), never glowing. They cast a soft blob shadow on the ground.
- Walk and run cycles are bouncy. Characters blink.
Camera
- Always moving: slow push-ins and glides, never a locked-off tripod.
- Small "kick" shakes on big beats.
- Crossfades only when the place or time changes; otherwise hard cuts on the word.
- A quick white flash on the 2-3 biggest reveals.
On-screen labels
- Rounded-rectangle "sign" cards that pop into the 3D world with a quick scale-up overshoot (~0.15 s), placed next to whatever they describe.
- Bold uppercase headline plus an optional smaller sub-line.
- Flat solid colours with white text. Palette: teal #1f6a5a, red #c0453f, deep blue #24306a, orange #e0702a, purple #7a3b8a, green #3f7a4a.
- Small effect sprites: a green check mark, a red heart, "Zzz", "+1" tags.
Captions
- Word-by-word burned-in captions, synced exactly to the voice.
- Large white bold sans with a dark outline, 2-4 words on screen at a time, the current word highlighted.
- Placed in the lower-middle of the frame, above the bottom safe area.

CHARACTERS AND COSTUMES
- Yusuf (the hero): a young Muslim man in his 20s, short dark hair and a short beard, medium-brown skin. Everyday outfit: casual jacket and trousers in teal/green tones. Bed scene: pyjamas. Makkah scenes: white ihram (two white cloths) with tan sandals.
- His mum: a warm older woman, lighter skin (#f5c9a0), in a white/cream pilgrim abaya and headscarf. A gentle smile, tearful joy at the end.
- Pilgrims: a crowd of ~90-150 small white-clad pilgrims of mixed skin tones walking slowly anticlockwise around the Kaaba (tawaf).
- Friends: three friends who run behind Yusuf: two adults in modern casual clothes and one kid.

SETS
- Makkah: the Kaaba (black cube with the gold band) in the centre of a wide white marble courtyard (the Haram), ringed by arched colonnades and minarets. Used in night, golden-hour and wide aerial versions. At night there is a thin crescent moon in a deep-blue sky.
- Yusuf's bedroom: a cosy room with a bed and pillow, a bedside stand with a phone on it, and a green prayer mat on the floor by a window. The window light changes colour with the time of day.
- The calendar running track: a big oval stadium track painted with the months NOV -> DEC -> JAN -> FEB along the lanes, so running along it reads as time passing toward Ramadan.

VOICE
One adult male narrator: warm, clear American English, steady and friendly, with no character voices.
Slightly brisk delivery, about 1.15x normal speed, with short natural pauses between sentences.
Pronounce "Salah" as "sa-LAH", and "Dhuhr" as "Zuhr".
Read the link exactly as: "${spoken}."

SCRIPT (voice-over, final)
${words} days from now, Ramadan begins. And someone is going to Makkah, for free. Here's how. Starting today, log your five daily prayers in Salah Alarm. Fajr. Dhuhr. Asr. Maghrib. Isha. Every full day counts. Thirty days puts you in the draw. Sixty days, two entries. All ninety days, three entries. And every friend you bring adds one more. The prize? Umrah for two. Flights, visas, and a hotel right by the Haram. For you, and someone you love. Imagine Yusuf. Ninety days ago, he couldn't get up for Fajr. Now he's standing in Makkah with his mum. Entries close on January ninth. Scan the code, or go to ${L.link}.

Notes:
- "${words} days": recompute this from the posting date to the first day of Ramadan 2027 (about 8 Feb 2027) so it is true on the day it posts. Today it is ${n}.
- No "comment LINK" line. The video ends after the link.

FACT RULES (must hold everywhere: voice, labels, captions, description)
- How to enter: log all five daily prayers in Salah Alarm. 30 full days = 1 entry, 60 = 2, 90 = 3, all counted before 7 Feb 2027.
- Friends: after you hit 30 days, +1 entry for each friend who joins with your link and logs a full day (up to 50).
- Prize: Umrah for 2, with return flights, visas and a hotel near the Haram (about US$4,000). The random draw is on 10 Feb 2027.
- Eligibility: no purchase necessary, US, UK and Canada residents aged 18+. Entries close 9 Jan. Odds depend on entries. Full rules: salahalarm.com/ramadan-2027.
- It is a DRAW: always say "a chance" / "in the draw". Never "you will win" or "guaranteed".

SHOT LIST
Times are from the voice track. Each cut lands on its word, and every label or reaction appears 0-3 frames before its word.
1 (0.0-3.1) "${words} days from now, Ramadan begins." Makkah at night, wide high angle, slow push toward the Kaaba. Crescent moon, pilgrims circling. Label floating above the Kaaba: ${n} DAYS / UNTIL RAMADAN (deep blue), popping in at 0.05 s.
2 (3.1-5.1) "And someone is going to Makkah, for free." Crossfade to Makkah at golden hour, even higher and wider, pushing in. On "Makkah": white flash + label FREE TRIP / TO MAKKAH (red).
3 (5.1-9.4) "Here's how. Starting today, log your five daily prayers in Salah Alarm." Bedroom, dawn light. Close shot of Yusuf on the prayer mat holding his phone, smiling; the background is blurred. On "log": label LOG 5 PRAYERS / EVERY DAY (teal) and he grins. On "Salah Alarm": a green check pops by the phone.
4-8 (9.4-11.6) "Fajr. Dhuhr. Asr. Maghrib. Isha." Same frame, one quick cut per prayer name. Yusuf has his hands raised in dua with a relieved smile. The window light turns through the day: Fajr dawn blue, Dhuhr bright day, Asr golden, Maghrib pink dusk, Isha night. Each cut gets a small camera punch, the prayer-name label (FAJR deep blue, DHUHR #2f6a8a, ASR #c8642e, MAGHRIB #b8455a, ISHA #1f2a5a) and a check popping beside it.
9 (11.6-12.9) "Every full day counts." Same mat, daylight, a slightly tighter push. Label 5 OF 5 / FULL DAY (green). On "counts", Yusuf throws both arms up in a cheer and laughs.
10 (12.9-18.4) "Thirty days puts you in the draw. Sixty days, two entries. All ninety days, three entries." Calendar track, daytime. A tracking camera runs alongside Yusuf as he sprints laughing from NOV toward FEB. A label rides above his head and swaps on each number: 30 DAYS / 1 ENTRY (teal), 60 DAYS / 2 ENTRIES (teal), then 90 DAYS / 3 ENTRIES (red). A camera kick on each.
11 (18.4-20.6) "And every friend you bring adds one more." Slightly higher and wider on the same track. Three friends run in behind Yusuf, one by one; each gets an orange +1 tag above their head on "friend", "adds" and "more".
12 (20.6-25.0) "The prize? Umrah for two. Flights, visas, and a hotel right by the Haram." Crossfade to Makkah golden hour, big aerial, a slow push. On "Umrah": white flash, camera kick and label UMRAH FOR 2 / THE PRIZE (red). On "Flights" the label swaps to FLIGHTS + VISAS / + HOTEL BY THE HARAM (teal).
13 (25.0-26.6) "For you, and someone you love." Ground-level medium shot. Yusuf in ihram and his mum stand side by side in the courtyard, gently smiling, with pilgrims circling in the blurred background. On "love" a red heart pops above them.
14 (26.6-30.6) "Imagine Yusuf. Ninety days ago, he couldn't get up for Fajr." Crossfade to the bedroom at dawn. Yusuf is asleep in pyjamas, head on the pillow, looking dazed. "Zzz" floats up and the phone on the stand shows an alarm ringing. The camera slowly pushes in. Label 90 DAYS AGO (purple) near his head.
15 (30.6-32.8) "Now he's standing in Makkah with his mum." Crossfade back to Yusuf and mum in Makkah, golden hour, a slightly faster push. Both are now overjoyed (open-mouth laugh, happy tears). On "mum", Yusuf cheers and his mum raises her hands in dua. Label NOW (red).
16 (32.8-35.2) "Entries close on January ninth." Extreme close-up, looking straight down at the phone lying on a surface in soft dawn light. The screen shows the Salah Alarm promo page: Free Makkah Trip, Ramadan 2027 Challenge, the URL ${L.link} and a "Join" button. A very slow push.
17 (35.2-end) "Scan the code, or go to ${L.link}." Crossfade to a wide golden-hour Makkah aerial, very slow push. Starting 0.2 s before "Scan", the QR end card slides up over the scene (see below). The video ends 0.3 s after the last word of the link.

QR END CARD
- A white rounded card in the centre of the frame, with a soft shadow, over the Makkah aerial.
- Top: "Free Makkah Trip" (bold) and "Ramadan 2027 Challenge".
- Middle: a large, crisp, high-contrast QR code encoding ${L.linkUrl} , at least 45% of the frame width, with a quiet zone.
- Under it: the URL in big text, ${L.link}.
- Bottom: small print in one or two lines: "Free prize draw · No purchase necessary · US, UK & Canada residents 18+ · Odds depend on entries · Rules at salahalarm.com/ramadan-2027"
- The QR must decode from a frame grabbed 1 s before the end, even scaled down to 360 x 640.

MUSIC
An original, light, uplifting score with no vocals. It sits well under the voice and ducks whenever the voice speaks. Mood changes:
0.0 calm (soft pads, gentle bells) · 3.1 bright (light percussion comes in) · 12.9 drive (steady upbeat rhythm for the race) · 20.6 cta (big warm swell) · 26.6 calm (pulls back for the flashback) · 30.6 cta (full warm swell to the end).

SOUND EFFECTS
Synthesized cartoon SFX, mixed under the voice (gain in dB):
0.05 sparkle (-6) · 3.0 whoosh (-4) · 4.0 "Makkah" chime (-4) · 5.0 whoosh (-6) · 6.8 "log" pop (-6) · 8.4 "Salah" phone scan/ding (-2) · each prayer name pop (-6) · 12.2 "counts" chime (-6) · 12.8 whoosh (-6) · "30" and "60" pop (-4) · "All" sparkle (-4) + short crowd cheer (-8) · "friend", "adds", "more" pop (-6) · 20.5 whoosh (-4) · "Umrah" sparkle (-2) + crowd cheer (-8) · "Flights" pop (-6) · 26.0 "love" chime (-6) · 26.5 "Imagine" whoosh (-6) + phone alarm ringing (-10) · 30.5 "Now" whoosh (-4) + short cheer (-6) · "January" pop (-6) · "Scan" whoosh (-4), then scan beep (0), then chime (-4).
Final mix: music about +3 dB relative to the default bed, SFX around -6 dB, voice unchanged on top. Normalize to -14 LUFS.

FINAL CHECKS BEFORE DELIVERY
- The QR on the last frame decodes to ${L.linkUrl}
- Loudness is -14 LUFS ±0.5.
- Captions match the spoken words exactly. The URL caption reads ${L.link}.
- No black, white, frozen or glitch frames, apart from the intended white flashes.
- No wording promises a win. "Draw" and "chance" only.
- Labels and captions stay inside the safe area.
- The YouTube copy is under 10 MB.

POST CAPTION (for Instagram/TikTok/YouTube)
${n} days until Ramadan… and someone's going to Makkah for FREE 🕋

Log your 5 daily prayers in Salah Alarm and get entries into the draw for a FREE Umrah trip for 2 to Makkah. Flights, visas and a hotel by the Haram. ✅ 30 days = 1 entry • 60 days = 2 • 90 days = 3 ➕ Hit 30 days, then +1 entry for every friend who joins. Entries close 9 Jan. 👉 ${L.loggedIn ? L.link : 'link in bio'}

Free prize draw · No purchase necessary · US, UK & Canada residents 18+ · Odds depend on entries · Rules at salahalarm.com/ramadan-2027

#ramadan #ramadan2027 #umrah #makkah #islam #muslim #salah #ImRamadanReady

YouTube title: ${n} Days Until Ramadan: a chance at a FREE trip to Makkah 🕋 #shorts`;
}

export const TYPES = [
  {
    slug: 'makkah-trip-story',
    emoji: '🕋',
    title: 'Free Makkah Trip story (AI animation)',
    short: 'A 41-second animated mini-story about the Ramadan 2027 Free Makkah Trip draw. Paste one prompt into an AI video tool and post a fresh one every day until entries close.',
    tags: ['Daily', 'AI video', 'Ramadan'],
    effort: '20-40 min per video with an AI tool',
    why: [
      'It\'s Salah Alarm\'s own format and one of the best performers so far. A warm story beats a hard sell.',
      'It has a built-in daily reason to post: the countdown changes every day, so each day is a "new" video.',
      'Animated Islamic stories pull huge numbers: the animation channels below have millions of views.',
    ],
    refs: [
      { label: 'Adam, Islamic Animation (YouTube)', url: 'https://www.youtube.com/watch?v=WuiLWYlEuew', views: '19.6M views', note: 'Animated Islamic storytelling at scale' },
      { label: '@verse.sakinah (Instagram)', url: 'https://www.instagram.com/reel/DexCI2hugDQ/', views: '~1.9M views', note: 'Animated Quran reflection explainer' },
      { label: 'Illustrated Quran explainer (Instagram)', url: 'https://www.instagram.com/reel/De2XrBjOmdf/', views: '553K views', note: 'Illustrated scenes + one clear message' },
      { label: 'Illustrated repentance explainer (Instagram)', url: 'https://www.instagram.com/reel/De4z3vIsZs-/', views: '285K views', note: 'Same style, different topic' },
    ],
    steps: [
      'Copy the full prompt below. It already has today\'s day count and your own link in it.',
      'Paste it into an AI video tool that can do animation from a script (one long prompt or scene by scene). If the tool only makes short clips, generate it shot by shot using the shot list.',
      'Make the voice-over in ElevenLabs from the SCRIPT section (settings below), then line the shots up to the voice.',
      'Check the QR code scans and goes to your link before you post.',
      'Post the same video on TikTok, Instagram Reels and YouTube Shorts with the caption at the bottom of the prompt.',
      'Tomorrow: open this page again. The day count updates automatically, so the prompt is always correct for the day you post.',
    ],
    rules: [
      'It\'s a free prize draw. Always say "a chance" or "in the draw". Never "you will win" or "guaranteed".',
      'Keep the eligibility line in the caption: US, UK & Canada residents 18+, odds depend on entries, rules at salahalarm.com/ramadan-2027.',
      'Entries close on 9 January 2027. After that, switch to the Ramadan countdown format.',
    ],
    voice: 'Narrator: warm male voice, American English. Model: Eleven Multilingual v2. Stability 45, Similarity 75, Style 10, Speaker boost on, speed 1.1-1.15. Write "Salah" as "Sa-laah" and "Dhuhr" as "Zuhr" in the text if the voice mispronounces them.',
    hasPrompt: true,
  },
  {
    slug: 'clipping',
    emoji: '✂️',
    title: 'Clipping: viral Islamic clips + a new hook',
    short: 'Take a proven Islamic reminder or speaker clip, put a tweet-style hook card on top, and end with "My friend built an app called Salah Alarm". The fastest way to post 3+ times a day.',
    tags: ['3+ a day', 'Fastest', 'Faceless'],
    effort: '5-10 min per video',
    why: [
      'The clip has already proven it holds attention. Your only job is a new hook and a soft CTA.',
      'This is exactly how the big clipping campaigns run (Scroll The Bible\'s campaign uses the same hook-card layout).',
      'You can make a week of posts in an hour, and test many hooks on the same clip.',
    ],
    layout: true,
    refs: [
      { label: '@mysalahmat (TikTok)', url: 'https://www.tiktok.com/@mysalahmat/video/7590135926479752470', views: '8.2M views', note: 'Prayer education' },
      { label: '@8tvnn (Instagram)', url: 'https://www.instagram.com/reel/DcbQy_nIafe/', views: '5.4M views', note: 'Night sky + Quranic text about ease after hardship' },
      { label: '@reminding_guy (Instagram)', url: 'https://www.instagram.com/reel/DeS8lfgMjXe/', views: '3.3M views', note: 'Spoken reflection over outdoor footage' },
      { label: 'Quran translation reminder (Instagram)', url: 'https://www.instagram.com/reel/DXZF3N7DC8o/', views: '3.0M views', note: 'Mosque setting with translated recitation' },
      { label: '@islamicwisdomhub.1 (TikTok)', url: 'https://www.tiktok.com/@islamicwisdomhub.1/video/7464320098199735558', views: '2.8M views', note: 'Waking for Fajr: the perfect topic for us' },
      { label: '@alinoor.ahmed (TikTok)', url: 'https://www.tiktok.com/@alinoor.ahmed/video/7611642363617856776', views: '2.4M views', note: 'Prayer education clip' },
      { label: 'Islamic Media Australia (YouTube)', url: 'https://www.youtube.com/watch?v=Kuk6HgOH9yQ', views: '15.8M views', note: 'Long talk: cut 20-40 s moments out of it' },
      { label: 'Scroll The Bible campaign clip (TikTok)', url: 'https://darkugc.com/video/tt-7658866833000336653', views: '2.1M views', note: 'Same campaign style for a faith app: hook card + clip + app mention' },
    ],
    steps: [
      'Find a clip: a reminder, a short talk, a Quran recitation with translation, or a Fajr moment. Use the references above or the clip packs in the Resources page. Pick ones with 100K+ views.',
      'Cut 15-45 seconds: the strongest single idea, starting mid-sentence if needed. No intros.',
      'Add the hook card on top: app icon, "Salah Alarm" name, and one hook line ending in "...". Black bars top and bottom, clip in the middle (see the layout below).',
      'End with the CTA as text on the last 2-3 seconds and in the caption. Keep it soft: "My friend built an app called Salah Alarm, you can download it. Link in bio."',
      'Write a caption that repeats the hook and adds the CTA. 3-5 hashtags.',
      'Post the same clip with 2-3 different hooks across your accounts. Keep the hook that wins.',
    ],
    rules: [
      'Always change something: new hook, new crop, captions, your CTA. Never re-upload a whole video untouched.',
      'Credit the speaker or creator in the caption when you can, and take a clip down if the owner asks.',
      'No clips that mock other Muslims, scholars or groups. Nothing sectarian.',
      'Translations of Quran verses must be from a known translation; don\'t make up hadith.',
    ],
    voice: 'Most clips keep their original audio. If you add a spoken hook, make 3-5 seconds in ElevenLabs: Stability 40, Similarity 75, Style 20, a calm young voice. Keep it lower than the clip\'s voice.',
  },
  {
    slug: 'slideshows',
    emoji: '🖼️',
    title: 'TikTok slideshows and Instagram carousels',
    short: 'Swipeable 5-8 slide posts: lists, "things I stopped doing", Fajr tips, with the app on the last slides. Cheap to make, very shareable, and TikTok pushes photo mode hard.',
    tags: ['Daily', 'No video', 'Canva'],
    effort: '10-15 min per post',
    why: [
      'Saves and shares drive reach on carousels, and Islamic list posts get saved a lot.',
      'TikTok photo slideshows often get more reach than videos on new accounts.',
      'You can turn one idea into a TikTok slideshow and an Instagram carousel in the same 15 minutes.',
    ],
    refs: [
      { label: 'topcarousels.com Islamic carousel', url: 'https://topcarousels.com/api/assets/import-aeae1275-2b62-422b-9888-6c3123239625-0', views: '124K likes', note: 'Reminder list carousel' },
      { label: 'topcarousels.com: browse the top carousels', url: 'https://topcarousels.com/', views: 'Library', note: 'Filter by faith, self-improvement and habits for layouts that already went viral' },
      { label: 'Two rakahs of Fajr carousel (Instagram)', url: 'https://www.instagram.com/p/Dbqel0TT6C-/', views: '65.9K likes', note: 'One reminder, broken across slides' },
      { label: '@islamisdeeen photo post (TikTok)', url: 'https://www.tiktok.com/@islamisdeeen/photo/7594369552314666241', views: '53.9K likes', note: 'Prayer education slideshow' },
      { label: 'Eid three-item list with app mention (Instagram)', url: 'https://www.instagram.com/reel/DY0Npkqsfwd/', views: '134K views', note: 'List format that mentions an app in the caption' },
      { label: 'Critical list about Muslim trends (Instagram)', url: 'https://www.instagram.com/reel/DZQwYwXvMAY/', views: '128K views', note: 'Three-item list hook, app mention' },
    ],
    templates: [
      { name: '"5 things that got me up for Fajr every day"', slides: ['Slide 1 (hook): 5 things that finally got me up for Fajr 🌙', '2: Sleeping 30 minutes earlier (Isha, then phone away)', '3: Making intention before sleeping: "I will wake for Fajr"', '4: Putting my prayer mat where my feet land', '5: An alarm I can\'t snooze: it only stops when I scan my prayer mat', '6: The app is called Salah Alarm (screenshot of the Fajr alarm)', '7: Save this for tonight 🤲 Link in bio'] },
      { name: '"Things I stopped doing as a Muslim in 2026"', slides: ['1: Things I stopped doing this year as a Muslim', '2: Praying Asr after scrolling for an hour', '3: Snoozing Fajr "just 5 more minutes"', '4: Saying "I\'ll start praying properly next month"', '5: Letting TikTok decide when I pray (SalahLock blocks it until I pray, screenshot)', '6: What I use: Salah Alarm. Link in bio'] },
      { name: '"Your Ramadan starts now: X days left"', slides: ['1: There are X days until Ramadan. Here\'s the plan', '2: Weeks 1-4: all 5 prayers, on time', '3: Weeks 5-8: add 2 rakahs before Fajr', '4: Weeks 9-12: a page of Quran a day', '5: Track it all in one place (Salah Alarm streak screenshot)', '6: Bonus: log your prayers for a chance in the Free Makkah Trip draw. Link in bio'] },
      { name: '"POV: your phone stops letting you skip Salah"', slides: ['1: POV: your phone stops letting you skip Salah', '2: 4:58 AM: Fajr alarm. Won\'t stop until you scan your mat (screenshot)', '3: 1:15 PM: TikTok locked until Dhuhr is prayed (SalahLock screenshot)', '4: 9:40 PM: 5/5 prayers logged, 21-day streak (streak screenshot)', '5: It\'s called Salah Alarm. Link in bio'] },
    ],
    steps: [
      'Pick a template below (or a viral layout from topcarousels.com) and write 5-8 slides. One idea per slide, 12 words max.',
      'Design 1080x1350 for Instagram and 1080x1920 for TikTok in Canva or CapCut. Big text, high contrast, one calm photo or plain background.',
      'Put the app screenshots (download them below) on the last 1-2 slides only. The first slides must be pure value.',
      'Last slide: the CTA. "Link in bio" or "Comment FAJR".',
      'On TikTok, post as a photo slideshow with a trending nasheed-free sound or no sound. On Instagram, post as a carousel.',
      'Caption: repeat the hook, add one line of value, the CTA and 3-5 hashtags.',
    ],
    rules: [
      'Check any hadith or verse you quote. If you\'re not sure of the source, leave it out.',
      'No music with instruments on Islamic content: many viewers dislike it. Use nasheeds without instruments, ambience or silence.',
    ],
    voice: 'Slideshows don\'t need a voice. If you turn one into a video, record a 10-second ElevenLabs line for the hook only.',
  },
  {
    slug: 'pov-skits',
    emoji: '😴',
    title: 'POV and relatable Fajr skits',
    short: 'Short relatable moments: snoozing Fajr, the alarm that won\'t stop until you scan your prayer mat, "5 more minutes". The alarm-app challenge format gets millions of views.',
    tags: ['Face or faceless', 'Funny', 'High reach'],
    effort: '15-30 min per video',
    why: [
      'Alarm apps built huge accounts on exactly this: a person struggling with an alarm that won\'t stop (4.3M and 3.6M views below).',
      'Muslim humour about Fajr is one of the most viewed topics in our library.',
      '"Send this to the friend who sleeps through Fajr" makes people share it.',
    ],
    refs: [
      { label: 'PushClock alarm challenge (TikTok)', url: 'https://darkugc.com/video/tt-7668726250147482912', views: '4.3M views', note: '"Send this to someone who never wakes up on time"' },
      { label: 'Noozr wake-up struggle (TikTok)', url: 'https://darkugc.com/video/tt-7627246990283263253', views: '3.6M views', note: 'Struggling with an alarm that won\'t stop' },
      { label: '@ismilezzzzzzz Muslim humour (TikTok)', url: 'https://www.tiktok.com/@ismilezzzzzzz/video/7570029738337619232', views: '3.9M views', note: 'Relatable humour' },
      { label: '@hassantoqeer93 (TikTok)', url: 'https://www.tiktok.com/@hassantoqeer93/video/7608378679529426197', views: '3.6M views', note: 'Relatable humour' },
      { label: '@muslim: humour before Fajr (TikTok)', url: 'https://www.tiktok.com/@muslim/video/7692563730223090958', views: '3.2M views', note: 'Two rakahs before Fajr' },
      { label: 'Ummah Moments (YouTube Shorts)', url: 'https://www.youtube.com/shorts/L1oWHZ83UGA', views: '7.6M views', note: 'Muslim humour short' },
      { label: '@journey_with_kacho (Instagram)', url: 'https://www.instagram.com/p/DeMtQ8LKy5h/', views: '~10M views', note: 'The calm of praying Fajr' },
    ],
    templates: [
      { name: 'The alarm that fights back', slides: ['On screen: "POV: you downloaded the Fajr alarm that won\'t stop until you\'re on your prayer mat"', 'Shot: phone ringing on the nightstand, you hit snooze, nothing happens', 'Shot: you stumble to the prayer mat, scan it, silence', 'Shot: you on the mat, calm, small smile', 'End text: "It\'s called Salah Alarm. Link in bio"'] },
      { name: '"5 more minutes"', slides: ['On screen: "Me at 5:01 AM: 5 more minutes"', 'Cut: "Me at 7:40 AM:" (panic, sunlight)', 'Cut: "Me since I got an alarm I can\'t snooze:" (up, wudu, praying)', 'End text: "Salah Alarm. Send this to your Fajr-skipping friend"'] },
      { name: 'Phone vs. me', slides: ['On screen: "Me trying to open TikTok before Asr"', 'Screen recording: TikTok opens, SalahLock screen appears: "Complete your prayer to unlock"', 'You: sigh, get up, pray', 'Cut: TikTok unlocked, 5/5 logged', 'End text: "My friend built this. Salah Alarm, link in bio"'] },
    ],
    steps: [
      'Pick a skit. Film vertical with your phone, or do it faceless: hands, phone on nightstand, prayer mat, screen recordings.',
      'Use the app screenshots or a screen recording of the alarm for the "app moment". Keep it under 3 seconds.',
      'Text on screen carries the joke. 3-6 words per line.',
      'Keep it 7-20 seconds. Cut every 1-2 seconds.',
      'Caption: "Send this to someone who sleeps through Fajr 😭" + CTA.',
    ],
    rules: [
      'Laugh at the struggle, never at the prayer itself or at people who pray differently.',
      'No fake reviews or fake "I\'m a doctor/scholar" claims.',
    ],
    voice: 'Use your own voice or none. For a narrated version, ElevenLabs with a casual young voice: Stability 35, Similarity 75, Style 30, speed 1.1.',
  },
  {
    slug: 'reminders',
    emoji: '🌙',
    title: 'Reminder overlays (text over calm footage)',
    short: 'Night sky, rain, a quiet street or a mosque, with one short reminder or dua on screen. The biggest Islamic pages post this every day. Add a soft Salah Alarm line at the end.',
    tags: ['Daily', 'Faceless', 'Easy'],
    effort: '5 min per video',
    why: [
      'It\'s the single most common viral format in our library of Islamic content: 236 of 261 top posts are reminders.',
      'Christian prayer apps grow with the same "text + daily moment" format (Creed: 6.7M and 3M views below).',
      'Short (8-15 s), so people rewatch it, which pushes it further.',
    ],
    refs: [
      { label: '@8tvnn (Instagram)', url: 'https://www.instagram.com/reel/DcbQy_nIafe/', views: '5.4M views', note: 'Car roof night sky + one Quranic line' },
      { label: 'Prayer for a good ending (Instagram)', url: 'https://www.instagram.com/reel/DcGf3Bjgb5V/', views: '2.8M views', note: 'Warm night footage + Arabic and English dua' },
      { label: 'Alhamdulillah (Instagram)', url: 'https://www.instagram.com/reel/DcyIwwtA2jb/', views: '2.5M views', note: 'Night sky, flowers, dhikr with translation' },
      { label: 'Night-street reminder (Instagram)', url: 'https://www.instagram.com/reel/De3E_1_shPt/', views: '904K views', note: 'Night street, Urdu text' },
      { label: 'Prayer and trust (Instagram)', url: 'https://www.instagram.com/reel/DLf_dJIt64X/', views: '898K views', note: 'Rooftop prayer space, one line' },
      { label: 'Life after Fajr (Instagram)', url: 'https://www.instagram.com/reel/DdSgKGvI57w/', views: '670K views', note: 'Dawn routine montage' },
      { label: 'Creed "text + daily moment" (TikTok)', url: 'https://darkugc.com/video/tt-7675524808179846414', views: '6.7M views', note: 'Same format for a Christian prayer app' },
    ],
    templates: [
      { name: 'Fajr reminder', slides: ['Footage: dark sky turning blue before sunrise', 'Text 1: "The two rak\'ahs before Fajr are better than the world and everything in it." (Sahih Muslim 725)', 'Text 2: "Don\'t sleep through them tomorrow."', 'End: "Set an alarm you can\'t ignore: Salah Alarm, link in bio"'] },
      { name: 'Hardship reminder', slides: ['Footage: rain on a car window at night', 'Text: "Indeed, with hardship comes ease." (Quran 94:6)', 'Text: "Talk to Allah before you talk to anyone else about it."', 'End: "Never miss a prayer: Salah Alarm"'] },
      { name: 'Type Ameen', slides: ['Footage: calm night sky', 'Text: "If this reached you, may Allah let you reach Ramadan 🤲"', 'Text: "Allahumma ballighna Ramadan"', 'Text: "Type Ameen"', 'Caption CTA: "Getting Ramadan-ready? Start with Fajr. Salah Alarm, link in bio"'] },
    ],
    steps: [
      'Get calm footage: your own phone clips (sky, rain, street, mosque) or free stock (Pexels, Pixabay). No faces needed.',
      'One short reminder: a verse with reference, a sahih hadith with source, or a simple dua. 1-2 lines on screen at a time.',
      'Add soft audio: recitation, a nasheed without instruments, or rain. 8-15 seconds total.',
      'End frame or caption: one gentle line about Salah Alarm. Keep 80% of these posts pure reminder; the trust is what sells.',
    ],
    rules: [
      'Quote the Quran with a reference (Surah:Ayah) and hadith only with a source. If unsure, use a dua instead.',
      'Don\'t put Quran verses over music with instruments.',
    ],
    voice: 'Usually no voice, or recitation. For an English voice-over, ElevenLabs: soft, slow voice, Stability 55, Similarity 80, Style 0, speed 0.95.',
  },
  {
    slug: 'ramadan-countdown',
    emoji: '📅',
    title: 'Ramadan countdown (daily)',
    short: '"X days until Ramadan" posts, every day until Ramadan starts. Pause challenges, 90-days-in-20-seconds and "type Ameen" loops. One easy post a day with a built-in hook.',
    tags: ['Daily', 'Seasonal', 'Easy'],
    effort: '5-15 min per day',
    why: [
      'The number changes daily, so the same format feels new every day and people follow along.',
      'Interest in Ramadan climbs every week until February, so these posts get bigger over time.',
      'Om runs these on the Salah Alarm pages already; the formats below are the ones picked from the top of the library.',
    ],
    refs: [
      { label: '@journey_with_kacho (Instagram)', url: 'https://www.instagram.com/p/DeMtQ8LKy5h/', views: '~10M views', note: 'Calm after effort: the feeling a countdown should end on' },
      { label: '@thebeliefguide "type Ameen" (TikTok)', url: 'https://www.tiktok.com/@thebeliefguide/video/7608213744711142676', views: '42K views, 15% shared', note: 'Highest share rate in our library: the one-word comment prompt' },
      { label: '@4joykids (TikTok)', url: 'https://www.tiktok.com/@4joykids/video/7611997866420112662', views: '2.0M views', note: 'Simple reminder that people send to family' },
      { label: '@bymouadh morning routine (TikTok)', url: 'https://www.tiktok.com/@bymouadh/video/7621857518850952468', views: '2.5M views', note: 'Routine montage to borrow for "getting ready"' },
    ],
    templates: [
      { name: 'Pause challenge (18 s)', slides: ['Text: "X days until Ramadan. Pause to get your goal"', 'Goals flash at 10 per second: "pray all 5", "finish the Quran", "no music", "pray Tahajjud", "make Fajr in the masjid", "fast Mondays"...', 'End: "Comment the goal you got 👇"', 'Caption: "Start with Fajr: Salah Alarm, link in bio"'] },
      { name: '90 days in 20 seconds (24 s)', slides: ['Day counter races from Day 1 to Day 90, a dot grid fills up', 'Phases: Weeks 1-4 "5 prayers", 5-8 "+ Quran", 9-12 "+ Tahajjud"', 'End: "Day 1 of Ramadan: you\'re already ready."', 'Caption: "Log your prayers in Salah Alarm for a chance in the Free Makkah Trip draw"'] },
      { name: 'Type Ameen (16 s)', slides: ['Text: "If this video reached you, X days are left"', 'Text: "Allahumma ballighna Ramadan"', 'Text: "Type AMEEN"', 'Caption CTA: "Salah Alarm, link in bio"'] },
    ],
    steps: [
      'Work out today\'s number: days from your posting date to 8 February 2027 (expected start of Ramadan). Today it is {DAYS}.',
      'Pick a format below. Make a template once in CapCut/Canva and only change the number each day.',
      'Post at the same time every day so followers expect it.',
      'Caption: the day count, one line, the CTA, #ramadan #ramadan2027.',
    ],
    rules: [
      'Say "expected" or "about" for the Ramadan start date: it depends on the moon sighting.',
      'If you mention the Makkah Trip, it\'s "a chance in the draw", never a guaranteed prize.',
    ],
    voice: 'Optional. For a spoken countdown line, ElevenLabs: Stability 50, Similarity 75, Style 10, a warm voice. Generate "X days until Ramadan" fresh each day.',
  },
  {
    slug: 'app-demo-voiceover',
    emoji: '📱',
    title: 'App demo with an AI voice-over',
    short: 'A screen recording or the app screenshots, with a calm ElevenLabs voice explaining one problem the app solves. Faith apps like Scroll The Bible grew to millions of views with this.',
    tags: ['Faceless', 'Converts best', 'ElevenLabs'],
    effort: '15-20 min per video',
    why: [
      'It shows the app clearly, so the people who click already know what they\'re getting. These convert best.',
      'Scroll The Bible\'s explainer-plus-screen videos reach 1-2M views each.',
      'One script works in many voices and languages, so you can run it on several pages.',
    ],
    refs: [
      { label: 'Scroll The Bible explainer (TikTok)', url: 'https://darkugc.com/video/tt-7658866833000336653', views: '2.1M views', note: '"Stop scrolling TikTok and scroll the Bible": voice + screen' },
      { label: 'Scroll The Bible prayer (TikTok)', url: 'https://darkugc.com/video/tt-7675936693928725790', views: '1.7M views', note: 'Same format' },
      { label: 'Scroll The Bible good news (TikTok)', url: 'https://darkugc.com/video/tt-7694074066038197535', views: '1.4M views', note: 'Same format, another creator' },
      { label: 'Just Pray collab (Instagram)', url: 'https://www.instagram.com/reel/Db35L4uhR1h/', views: '415K views', note: 'Muslim prayer app promo that worked' },
      { label: 'Learning prayer with an app (Instagram)', url: 'https://www.instagram.com/reel/DdzNUTCTUgp/', views: '327K views', note: 'Prayer app shown in use' },
      { label: 'Mat-scan alarm review (TikTok)', url: 'https://www.tiktok.com/@dassahlynnn/video/7695547570596154655', views: '118K views', note: 'An alarm you turn off by scanning a mat' },
    ],
    templates: [
      { name: 'The Fajr problem (30 s script)', slides: ['"If you keep sleeping through Fajr, it\'s not because you don\'t care."', '"It\'s because your alarm is too easy to turn off."', '"My friend built an app called Salah Alarm. The Fajr alarm keeps going until you\'re standing on your prayer mat and scan it."', '"No snooze. No going back to sleep."', '"It also logs all five prayers and keeps your streak."', '"Salah Alarm. Link in my bio."'] },
      { name: 'The scrolling problem (30 s script)', slides: ['"I\'d spend three hours on TikTok and tell myself I didn\'t have five minutes for Asr."', '"So I installed something that doesn\'t let me lie anymore."', '"At prayer time, Salah Alarm locks TikTok and Instagram until I\'ve prayed."', '"Pray, scan the mat, and everything unlocks."', '"Search Salah Alarm, or tap the link in my bio."'] },
      { name: 'Ramadan prep (30 s script)', slides: ['"Ramadan is about {DAYS} days away. Here\'s the one thing to fix first."', '"Your five prayers. On time."', '"Salah Alarm wakes you for Fajr and won\'t stop until you\'re on your mat."', '"And if you log all five every day, you get entries in a free draw for a trip to Makkah for two."', '"It\'s a draw, so it\'s a chance, not a promise. Link in bio."'] },
    ],
    steps: [
      'Pick one problem per video: Fajr, scrolling instead of praying, consistency, or Ramadan prep.',
      'Generate the voice in ElevenLabs from a script below (settings underneath).',
      'Visuals: the app screenshots below, or a screen recording if you have the app. Add a slow zoom on each screenshot, cut on every sentence.',
      'Burn in word-by-word captions (CapCut auto captions).',
      'End on the app icon and "Salah Alarm" for 2 seconds. Caption with the CTA.',
    ],
    rules: [
      'Only claim what the app really does (see the feature list below).',
      'Don\'t clone a real scholar\'s or celebrity\'s voice.',
    ],
    voice: 'ElevenLabs: Eleven Multilingual v2. A calm, close, conversational voice (male or female). Stability 45, Similarity 75, Style 15, Speaker boost on, speed 1.05. Use a new voice per page so your accounts don\'t sound the same.',
  },
];

export const findType = (slug) => TYPES.find((t) => t.slug === slug);
