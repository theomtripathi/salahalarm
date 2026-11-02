# Ramadan Ready challenge release (v1)

Goal: be in the App Store before Day 1 of the 90-Day Ramadan Ready challenge
(Tue 10 Nov 2026). Submit by Fri 6 Nov. The pre-challenge app is saved on the
`pre-ramadan-2027` branch so it can be restored after Ramadan.

## What v1 adds

- **Free challenge tier.** On the paywall, "Not ready to pay? Join the free
  90-Day Ramadan challenge" joins the challenge without a subscription. Joined,
  unsubscribed users land on `ChallengeFreeHomeView`: today's five prayers with
  check-ins, the challenge card, and an "Unlock premium" upsell. Subscribers keep
  the full app, with the challenge card on Home.
- **Challenge progress** (`Models/RamadanChallenge.swift`): Day X of 90 from
  10 Nov, three 30-day phases, 3 grace days per phase, Bronze/Silver/Ramadan
  Ready tiers. A day counts when all five prayers are confirmed in the existing
  prayer log. Days before the user joined don't count against them.
- **Invite codes and links** (`Services/ChallengeService.swift`): every joiner
  gets a 6-character code and `https://salahalarm.com/c/<CODE>`. Codes are
  captured from the custom scheme `salahalarm://c/<CODE>`, universal links
  (once Associated Domains is on), AppsFlyer deferred deep links
  (`deep_link_sub1`), or typed in by hand.
- **Share card**: a rendered 9:16 image with the day count, days to Ramadan,
  `#ImRamadanReady` and the invite link, shared through the iOS share sheet.
- **Official rules link and Apple disclaimer** in the challenge sheet
  (guideline 5.3).
- **Events**: `challenge_joined` and `challenge_shared` to AppsFlyer.

## Firestore

```
users/<uid>.challenge   = { joinedAt, code, invitedBy }
referrals/<CODE>        = { ownerUid, createdAt, joinedCount }
challengeStats/global   = { joinedCount }
```

Deploy the updated `firestore.rules` before release, or joining will fail:
`firebase deploy --only firestore:rules`.

`joinedCount` values are client-incremented display counters. Rewards
(3 friends = 1 month, 10 friends = 1 year) must be granted by a server job in
v2 that recounts friends who completed Day 1.

## Set up outside the code

1. **AppsFlyer OneLink**: create a OneLink template for the challenge. The
   website's `/c/<CODE>` route forwards to it with `deep_link_value=challenge`
   and `deep_link_sub1=<CODE>`.
2. **Universal links (optional for v1)**: enable Associated Domains for the
   app ID, add `applinks:salahalarm.com` to the entitlements, and serve
   `/.well-known/apple-app-site-association` from salahalarm.com covering `/c/*`.
   Not added in this change, because the entitlement breaks signing until the
   capability is enabled in the developer portal.
3. **Official rules page** at `https://salahalarm.com/ramadan-2027/rules`
   (linked from the app). Needs legal review before any prize is announced.
4. **App Store metadata** (App Store Connect, submitted with this version):
   - Name: `Ramadan 2027: Salah Alarm`
   - Subtitle: `Fajr alarm, suhoor & challenge`
   - Keywords (en): `ramadan,2027,suhoor,sehri,fajr,alarm,azan,adhan,prayer,salah,namaz,iftar,challenge`
   - Localized names: ar `رمضان 2027: منبه الصلاة`, tr `Ramazan 2027: Namaz Alarmı`,
     id `Ramadhan 2027: Alarm Sholat`, ur `رمضان 2027: نماز الارم`
   - Switch the name back to `Salah Alarm` after Eid.
5. **In-App Event**: "90-Day Ramadan Ready Challenge", 10 Nov to 7 Feb.

## Before submitting

- Build in Xcode. This change was written without a Swift toolchain, so it has
  not been compiled yet.
- New strings use `L10n.text` with English source text and are not yet in the
  string catalogs, so ar/tr/id/ur users see English in the challenge screens
  until translations are added.
- Test: join from the paywall while signed in, confirm five prayers, check the
  Home card, share the invite, open `salahalarm://c/ABC234` on a fresh install
  and join, and confirm `referrals/ABC234.joinedCount` went up.

## Known limits (v2)

- Prayers count when confirmed, with no prayer-window or before-sunrise check.
- No reward automation, circles, meal photo log, or fasting tracker yet.
