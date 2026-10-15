# Post it tonight — copy/paste edition

You have **Reddit, X and TikTok/YouTube/Instagram**. That's enough to pull all
three levers: a community post (Reddit), a fast-feed post (TikTok/Shorts) and a
shareable thread (X). Budget **~45 minutes**.

## Order of operations

| # | Where | Time | Why this order |
|---|---|---|---|
| 1 | **Reddit r/software** | 15 min | Most welcoming to free tools. The safe first test. |
| 2 | **YouTube Shorts + TikTok** | 10 min | Highest ceiling; the algorithm ignores your follower count. |
| 3 | **X / Twitter thread** | 10 min | Compounding, and gets screenshotted into other places. |
| 4 | **Reddit r/Windows11** | 10 min | Only after #1 lands — don't fire two Reddit posts blind. |

**Three rules that decide whether this works:**

1. **Post the media, not the link.** Reddit and TikTok both bury link-only
   posts. Upload the video or the benchmark screenshot *as* the post, and put
   the link in the body or the first comment.
2. **Say you built it.** Every platform here punishes astroturfing. "I built
   this, it's free and open source, feedback welcome" is welcome nearly
   everywhere. "Check out this tool" is not.
3. **Answer every comment for the first 2 hours.** Replies are what push a post
   into more feeds, and every reply is read by people who never comment.

Best times (US-centric): **Tue–Thu, 8–11am or 7–10pm Eastern.**

---

## 1. Reddit — r/software

Read first: https://www.reddit.com/r/software/about/rules

In the composer choose **Images & Video**, and upload **one** of:
- `preview/Scottimizer-TikTok.mp4` (the 20-second demo — best performer)
- or `preview/shot-benchmarks.png` (the latency table — very shareable)

**Title**
```
I built a free, open-source Windows tuner that benchmarks every tweak and can undo all of them
```

**Body / first comment** (paste as the post body if the composer allows it,
otherwise post it as the first comment immediately after publishing):

```
I kept hitting the same problem with Windows tweak tools: they ask you to trust
them, prove nothing, and give you no way back. So I built Scottimizer — free,
MIT, no ads, no telemetry, no paid tier.

- 79 tweaks across gaming, network, security, privacy, debloat and storage
- A one-click security audit (0-100) that can fix weak settings
- Per-tweak latency benchmarks, so you can see what actually helped
- Exact-state undo — it snapshots the real prior values (including their types),
  services, power plan and DNS, so "Undo" means undo
- It never disables Defender, the firewall or Windows Update

Demo (20s): https://scottyincntrl.github.io/Scottimizer/#demo
Download: https://github.com/SCOTTYinCntrl/Scottimizer/releases/latest
Source (read every line before running — please): https://github.com/SCOTTYinCntrl/Scottimizer
Scoop: scoop bucket add scottimizer https://github.com/SCOTTYinCntrl/scoop-bucket

Feedback very welcome — especially which tweaks you'd want added.
```

---

## 2. YouTube Shorts + TikTok + Reels

**File to upload:** `preview/Scottimizer-TikTok.mp4` (20s, vertical 9:16).

**Caption / description:**

```
I benchmarked every Windows "gaming tweak" so you don't have to. Free, open
source, no ads. Full tool + source: https://scottyincntrl.github.io/Scottimizer/

#windows #windows11 #pcgaming #pctips #pcoptimization #pcbuilding #gaming
#opensource #techtok #fyp
```

> **Platform gotcha:** TikTok and Instagram only make links clickable once you
> have some followers (TikTok ~1,000). So **YouTube Shorts is your best bet
> first** — Shorts descriptions are clickable immediately. On TikTok, say
> "link in bio" and put the URL in the caption's first line so it's readable
> even when it isn't tappable.

Try these hooks as the on-screen text if you re-cut the clip (from
`launch-kit.md`):
- "I benchmarked every Windows 'gaming tweak' so you don't have to."
- "This free tool shows you which tweaks actually lowered your ping."
3. "The one feature every Windows optimizer is missing: a real undo."

---

## 3. X / Twitter — one thread

Attach the demo video (or the benchmark screenshot) to **tweet 1**. Post as a
thread, not one long tweet.

**1/**
```
Windows tweak tools want blind trust.

Scottimizer is free, MIT, and shows you proof + a way back. 🧵
```

**2/**
```
79 tweaks, 6 categories. Every one has a risk level and a plain-English
description — no "just trust me" registry keys.
```

**3**

```
Run a security audit (0–100) and fix failing items in one click. It never
disables Defender, the firewall or Windows Update. 🛡️
```

**4**

```
Benchmark every tweak. Before/after average ping + jitter, colour-coded, CSV
export. You can finally see what actually helped.
```

**5**

```
Real undo. It snapshots the exact prior state — value *and* type, services,
power plan, DNS. "Undo" restores it, not a guess.
```

**6**

```
Free. No ads. No telemetry. No paid tier. Windows 10/11.

Download: https://github.com/SCOTTYinCntrl/Scottimizer/releases/latest
Source: https://github.com/SCOTTYinCntrl/Scottimizer
```

Hashtags, if you use them (1–2 max, not 10): `#Windows11` `#OpenSource`

---

## 3. Reddit — r/Windows11 (after r/software lands)

Check the rules and use the software/tool flair if required.

**Title:**
```
Free, open-source Windows 11 tuner with a real "undo" (and a 0-100 security audit)
```

**Body:** same as the r/software body, but lead with the Windows 11 angle —
debloat, telemetry, privacy — and attach the dashboard or audit screenshot.

---

## After the first hour

- Reply to **every** comment. Ask what tweaks they want.
- If a post is removed by AutoMod, **do not repost** — message the mods once.
- Log the result in the post log at the bottom of `launch-runbook.md`, and run
  `tools\Get-Metrics.ps1` so you can see downloads move.

## If one of them takes off

That's the moment to submit to **AlternativeTo** and **Product Hunt** — both
need an account you don't have yet, and both convert far better once you can
say "trending on Reddit / X". Keep that in your back pocket.
