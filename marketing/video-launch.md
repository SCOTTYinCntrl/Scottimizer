# Video launch - one 22-second edit, four platforms

**The file:** `Scottimizer-promo-1080x1920.mp4`

Rendered with `tools\Build-PromoVideo.ps1`. 1080x1920 (9:16), 30fps, 22.0s,
H.264 + AAC. The default output lands in a Desktop folder called
`Scottimizer-Video`.

## What is in the video

| Time | Beat | On screen |
|---:|---|---|
| 0.0-3.0s | Hook | "Tweak tools can't show proof." -> "So I built one that does." |
| 3.0-7.2s | Proof 1 | `Ping, before & after.` - the Benchmarks tab |
| 7.2-11.2s | Proof 2 | `A 0-100 audit.` - the Security Audit tab |
| 11.2-15.2s | Proof 3 | `And a real undo.` - the Dashboard |
| 15.2-18.4s | Breadth | `79 tweaks. 6 categories.` |
| 18.4-22.0s | CTA | "Free. Open source. / No ads. No telemetry." + the URL |

Hook first on purpose: the still frame every platform uses as a thumbnail is
the hook, not a title card.

## Two rules that decide how far this travels

1. **Add the sound in the app, do not bake it in here.** The video has a
   silent audio track. In TikTok and Instagram, tap *Add sound* and pick
   something currently rising in the app's own trending list - the audio is
   the single biggest lever on those two feeds. For X and YouTube, silent is
   fine, or use the platform's own audio library.
2. **Post, then reply to your own first comment.** Pin it. That is where the
   link and the "what is it actually" question live, and replies are the
   cheapest engagement you will get.

## The four posts

Everything below is paste-ready. Change the voice if it is not yours - a
caption that sounds like you beats a better one that does not.

---

### 1. TikTok

**Caption**

```
Every Windows "optimizer" makes you apply 50 changes and hope. So I built
one that benchmarks all 79 - then puts them back. It's free.
```

**Hashtags** (put them at the end of the caption)

```
#pctips #windows11 #gamingpc #opensource #techtok
```

**First comment (post it yourself, then pin it)**

```
Hook it up in 4 steps: 1) grab the zip from my GitHub, 2) unzip anywhere,
3) run Scottimizer.exe, 4) hit UAC Yes. It self-elevates - nothing installs.
Link's in my bio.
```

**Notes**
- Keep the caption to one line. TikTok truncates, and the hook is the video.
- Do not put a URL in the caption; TikTok will not let it be clicked.
- Post it, then immediately watch it once with sound on.

---

### 2. X / Twitter

**Post**

```
Most "Windows optimizers" apply 50 tweaks and can't prove one helped.

Mine measures all 79 before and after, scores your security 0-100, and can
truly undo every change.

Free, MIT, no ads, no telemetry.
github.com/SCOTTYinCntrl/Scottimizer
```

**Hashtags** (append only if you have room - X rewards brevity)

```
#Windows11 #OpenSource
```

**First reply (thread it under the post)**

```
What makes it different from a list of registry edits:

- Snapshot engine: every change restores the exact previous value, not
  "Windows defaults"
- ~36 read-only security checks with a Fix button per finding
- Latency benchmark run after every tweak, so you can see what actually
  helped
Drop your setup below.
```

**Notes**
- Attach the MP4 directly. Native video on X is not throttled.
- The link is fine here - X is one of the platforms that supports a real CTA.
- Keep hashtags to zero or two. X is not hashtag-driven.

---

### 3. Instagram (Reels)

**Caption**

```
I got tired of "optimizers" that apply 50 tweaks and never show you whether
any of it worked.

So I built Scottimizer:

- 79 tweaks across 6 categories
- Ping and latency measured before and after every single one
- A 0-100 security audit with one-click fixes
- A real undo - it restores the exact previous value, not "reset to default"

Free. Open source. No ads. No telemetry. No paid tier.

It's on my GitHub - link in bio.
```

**Hashtags** (first comment, or the end of the caption)

```
#windows11 #pctips #opensource #pcgaming #tech #privacy #gamingpc #techtips
```

**First comment (pin it)**

```
Free download + the source: link in bio. Windows 10 and 11.
```

**Notes**
- The first ~125 characters are all that show before *more*. That is why the
  caption opens with the complaint, not the feature list.
- Instagram does not make caption links clickable. Bio or nothing.
- Reels pairs well with the same trending audio you used on TikTok.

---

### 4. YouTube Shorts

**Title** (78 characters)

```
Free Windows optimizer that proves every tweak - 79 tweaks, real benchmarks
```

**Description**

```
Most "optimizers" ask you to trust them. This one measures everything.

Scottimizer is a free, open-source Windows 10/11 tuner:

- 79 tweaks across 6 categories: Gaming, Network, Security, Privacy, Debloat,
  System & Storage
- Latency benchmarked before and after every tweak - you can see what helped
- 0-100 security audit with around 36 checks and one-click fixes
- A real snapshot/undo engine: every change restores its exact previous value
- Runs as a script, self-elevates, nothing installs behind your back

No ads. No telemetry. No paid tier. MIT licensed.

Download (free):
https://github.com/SCOTTYinCntrl/Scottimizer/releases/latest

Website and screenshots:
https://scottyincntrl.github.io/Scottimizer/

Scoop:
scoop bucket add scottimizer https://github.com/SCOTTYinCntrl/scoop-bucket
scoop install scottimizer/scottimizer
```

**Hashtags** (end of the description)

```
#Shorts #Windows11 #PCTips #OpenSource
```

**Notes**
- `#Shorts` in the description plus a title that says what it is.
- The link goes here, so this is the one post where "link in bio" is wrong.
- Vertical, under a minute - already correct.

---

## Order to post

1. **TikTok** and **Instagram Reels** first (they need the trending audio, and
   they are where the edit can travel fastest).
2. **X** within the hour, with the reply underneath.
3. **YouTube Shorts** last - it compounds slowest, and the description is
   where a searchable download link does the most good.

Then run `tools\Get-Metrics.ps1` and compare downloads before and after. One
number matters here: **downloads**, not likes.

## Honest caveat

No edit is *guaranteed* to go viral - short-form reach is a coin flip with a
loaded die, and the die is the audio, the first second, and whether the
comments get answered. This video is built to give the algorithm what it
wants (9:16, silent so you can add a rising sound, hook-first, 22 seconds,
caption-friendly) and to give viewers a reason to click through. The rest is
volume and replies.
