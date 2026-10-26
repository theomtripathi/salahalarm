# Article brief

Every article targets one row of `seo/data/keywords.csv` and lives at
`content/<lang>/<slug>.md` with the slug from that row.

## Frontmatter

```yaml
---
title: <keyword-led title, max 70 chars>
description: <70-165 chars, says what the reader gets, includes the keyword>
keyword: <exact keyword from keywords.csv>
date: YYYY-MM-DD
status: draft            # Om flips to published after review
translationKey: <translation_key from keywords.csv, if any>
faq:
  - q: <real question people search> | a: <2-3 sentence answer>
---
```

## Writing rules

- Answer the search in the first two paragraphs. No throat-clearing intro.
- 900-1500 words. Short paragraphs, `##` sections, a numbered routine or checklist
  where it fits.
- Write natively in the target language, not a literal translation. Use the words
  that market uses: Subuh and sholat (Indonesian), sabah namazı and imsak
  (Turkish), فجر/نماز in Urdu, الفجر/الصلاة in Arabic.
- Mention Salah Alarm once in the body, where it solves the reader's problem
  (the alarm stops only at the prayer mat; exact prayer times by location;
  SalahLock; Quran, Qibla, duas, widgets). The CTA blocks are added automatically.
- Religious content: cite hadith with collection and number (e.g. Sahih
  al-Bukhari 1142) and only when sure of the reference. Give no fatwas of our own;
  say "scholars explain" and point to local scholars on fiqh questions. Dates of
  Ramadan and Eid are "expected" until officially announced.
- 3-5 FAQ entries from real "People also ask" style questions.
- No invented statistics, reviews or testimonials.
