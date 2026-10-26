# Prompt for ChatGPT or Muse (Meta AI)

Use this when you have ChatGPT (with browsing) or Muse open. Paste the prompt,
then paste the table it returns into `data/inbox/manual.csv` with
`found_by` set to `chatgpt` or `muse`. The daily run re-checks every link with
a scraper before trusting its numbers, because assistants often guess view
counts. A link that doesn't exist is dropped.

Muse is the better one for Instagram and Facebook Reels (it's Meta's own);
ChatGPT for TikTok, X and YouTube Shorts.

---

Find 30 real, public short videos or carousels posted in the last 90 days that
went far beyond their account's usual reach, in this niche: Muslim daily
practice, especially Fajr, the five prayers, Quran, dua, Ramadan, and Islamic
or prayer apps (Muslim Pro, Pillars, Just Pray, Prayr, Deenly, Hisaab and
similar). Mix languages: English, Arabic, Urdu/Hindi, Indonesian, Turkish.

Rules:
- Only posts you can link to directly (tiktok.com/@user/video/…, instagram.com/reel/…, x.com/user/status/…). No profiles, no search pages.
- Prefer posts whose views are at least 10× the account's followers.
- Include at least 8 posts that promote an app, and say which app.
- Don't invent numbers. If you can't see a count, leave it blank.

Return only a CSV with this header and nothing else:

url,views,likes,shares,saves,comments,followers,author,text,found_by

`text` is the hook or caption in under 15 words (translated to English in
brackets if needed). `found_by` is your name (chatgpt or muse).
