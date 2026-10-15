# Launch runbook — the do-this-now sequence

Goal: first **1,000 real visitors** in 7 days. Scottimizer is donation-funded, so
**downloads are the only metric that matters** — everything here exists to raise
that number and to make the "tip" button easy to find once someone is on the site.

> **In a hurry?** `ready-to-post.md` is the stripped-down version for the three
> platforms you already have (**Reddit, X, TikTok/YouTube/Instagram**). This file
> is the fuller playbook, including the channels you'd add by making accounts
> later (Hacker News, Product Hunt, AlternativeTo).

---

## Read this first (it decides everything else)

Every worthwhile channel below needs **your** account. An agent can write the
copy, build the assets and keep the funnel tight — but it cannot create accounts,
accept a platform's terms for you, or safely auto-post as you (most platforms
ban automated posting, and a ban costs far more than it gains).

**So the split is:** the machine does 90% of the work; you do the 10% that is a
human clicking *Post*. Budget **90 minutes total**, spread over a week.

⚠️ **Post as yourself and say so.** Reddit, Hacker News and Product Hunt all
punish astroturfing. "I built this, free and open source, would love feedback"
is welcome almost everywhere; "check out this amazing tool" gets removed.

---

## North-star metric

```powershell
gh release view v2.1.2 -R SCOTTYinCntrl/Scottimizer --json assets
```

Watch `download_count` on `Scottimizer-Advanced.zip`. (Resets only matter per
release — compare v2.1.2's number over time.)

Record it in the log at the bottom before and after each post, so you learn
which channel actually works instead of guessing.

---

## 0. Pre-flight (5 minutes, do once)

Everything below is already true — verify it rather than trusting it:

- [ ] Landing page loads with the demo video and FAQ:
      https://scottyincntrl.github.io/Scottimizer/
- [ ] Download works end-to-end: grab the zip from
      https://github.com/SCOTTYinCntrl/Scottimizer/releases/latest ,
      unzip, run `Scottimizer.exe`, accept UAC.
- [ ] The repo README renders correctly (badges, screenshots).
- [ ] You are logged into the account you'll post from, and have checked
      **that community's self-promotion rules** (linked per channel below).
- [ ] The demo video is playable: https://scottyincntrl.github.io/Scottimizer/#demo
- [ ] **Repo social preview** (2 min, once): repo → **Settings → General →
      Social preview → upload** `docs/assets/shot-dashboard.png`. Without it,
      every link anyone shares on Reddit/HN/Discord/Discord shows a grey box
      instead of the app — this directly costs clicks.

> Reddit tip that decides success or failure: **the media is the post.** Put the
> demo video or the benchmark screenshot in the post itself, keep the title
> free of marketing words, and put the link in the body. Text-only posts die.

---

## 1. Reddit — the single biggest fast lever (Day 0)

Post to **one** sub first. Wait to see if it lands. Then a second, tailored.
**Never** paste identical text into several subs — that's what gets accounts
banned for spam.

Rules to check before each (read the sidebar / rules page):
`https://www.reddit.com/r/<sub>/about/rules`

| Order | Subreddit | Angle | Notes |
|---|---|---|---|
| 1 | **r/software** | "free, open source, no ads" | Most welcoming to free tools. Start here. |
| 2 | **r/Windows11** | the tool itself + the undo feature | Use the Tools/Software flair if required. |
| 3 | **r/coolgithubprojects** | "I built…" + repo link | Small but high-signal; GitHub users → stars. |
| 4 | **r/pcgaming** | the latency-benchmark angle | Media-first. Check promo rules. |
| 5 | **r/opensource** | MIT, read-the-source framing | Lower traffic, high trust. |

Some subs require account age or karma to post. If a post is auto-removed,
don't repost — message the mods once, politely.

### Post 1 — r/software / r/opensource / r/coolgithubprojects

> **Title:** I built a free, open-source Windows tuner that shows a real "undo" and a security audit
>
> I kept running into the same problem with Windows tweak tools: they ask you to
> trust them, prove nothing, and give you no way back.
>
> So I built **Scottimizer** — free, MIT, no ads, no telemetry, no paid tier.
>
> - 79 tweaks across gaming, network, security, privacy, debloat and storage
> - A one-click **security audit** (0–100) that can fix weak settings
> - **Per-tweak latency benchmarks** so you can see what actually helped
> - **Exact-state undo** — it snapshots the real prior values (including their
>   types), services, power plan and DNS, so "Undo" means undo
> - Never disables Defender, the firewall or Windows Update
>
> Demo (20s): https://scottyincntrl.github.io/Scottimizer/#demo
> Download: https://github.com/SCOTTYinCntrl/Scottimizer/releases/latest
> Source (read every line before running — please): https://github.com/SCOTTYinCntrl/Scottimizer
>
> Feedback very welcome — especially which tweaks you'd want added.

### Post 2 — r/pcgaming / r/pcmasterrace

> **Title:** Free open-source tuner that benchmarks the before/after ping of every Windows tweak
>
> Most "gaming optimizers" are black boxes. Scottimizer benchmarks the before and
> after of *every* change (average ping + jitter) and shows it in a colour-coded
> table you can export to CSV — so you can see what actually helped instead of
> trusting a magic button. Plus power/CPU scheduling tweaks and a real undo.
>
> Free, MIT, no ads or telemetry. Demo: https://scottyincntrl.github.io/Scottimizer/#demo

### Post 3 — r/Windows11

> **Title:** Free, open-source Windows tuner with a real undo (and a 0–100 security audit)
>
> [use Post 1 body, trimmed, with the Windows 11 angle: debloat + privacy + audit]

---

## 2. Hacker News — Show HN (Day 2–4, Tue–Thu, 8–10am US Eastern)

Timing is most of HN. Post, then **stay in the thread for the first 3 hours**
and answer every technical question. Do not ask for upvotes — it's detectable
and it gets submissions penalised.

> **Show HN: Scottimizer – a Windows tuner that benchmarks and reverses every change**
>
> I kept seeing Windows "optimizers" that apply dozens of registry tweaks with no
> way back and no evidence they help. Scottimizer is my answer:
>
> - Every tweak is risk-rated with a plain-English description
> - Each records its exact prior state (value *and* type) so undo really undoes
> - Optional before/after ping benchmarking per tweak, exportable to CSV
> - A ~36-check security audit with a 0–100 score and one-click fixes
> - Additive security only: Defender, firewall and Windows Update stay on
>
> PowerShell 5.1 + WPF, MIT.
> Repo: https://github.com/SCOTTYinCntrl/Scottimizer
> Site: https://scottyincntrl.github.io/Scottimizer/
>
> Happy to talk about the snapshot/undo design, or where the benchmarks surprised me.

---

## 3. AlternativeTo — best evergreen SEO (Day 2, 15 min)

Highest long-tail payoff of any directory: people search "alternative to X"
forever. One account, then list Scottimizer as an alternative to
**Chris Titus WinUtil**, **O&O ShutUp10++**, **Winaero Tweaker** and
**BleachBit**.

- Create: https://alternativeto.net/manage-app/
- Use the fields in `launch-kit.md` → "Directory submission fields".
- Tag it **Free · Open Source · Windows**. Add 2 screenshots.

---

## 4. Submit to directories (Day 3, ~30 min, all forms)

Use the directory fields in `launch-kit.md`. Prioritise by traffic:

| Site | Where | Notes |
|---|---|---|
| **MajorGeeks** | https://www.majorgeeks.com/ (submission form) | Big for this exact niche. |
| **Softpedia** | https://www.softpedia.com/ | Submit via their form; wants a short description. |
| **PortableApps.com** | https://portableapps.com/ | Zip + no install fits their model. |
| **WindowsReport / Ghacks** | tips email | Short pitch + 2 screenshots. |

---

## 5. Short-form video (Day 3–5) — the highest ceiling, if you're up for it

You already have `preview/Scottimizer-TikTok.mp4` (20s, vertical). Post it to
**TikTok, YouTube Shorts and Instagram Reels** with a hook from
`launch-kit.md` → "Video hooks". These are the only channels where a brand-new
free tool can reach 100k+ people with no following — and the algorithm doesn't
care that you're the author.

Suggested caption: *"I benchmarked every Windows 'gaming tweak' so you don't
have to — free tool, link in bio."*

---

## 6. Product Hunt (Day 5–7)

Needs an account and a launch day. Prepare: the **Long** blurb from
`launch-kit.md`, the demo video as the gallery's first item, and 4 screenshots.
Launch ~12:01am PT; the first 6 hours decide the ranking.

---

## 7. Evergreen distribution (background, no rush)

- **Scoop / Chocolatey** — manifests already generate on every release
  (`packaging/README.md`). Publish when you want another install path.
- **Awesome lists** — a *single* line in a relevant list is a permanent
  backlink. **Submit these by hand, as yourself.** Many curated lists now
  explicitly reject AI-generated contributions, so an automated PR can get
  closed and reflect on your account. Good fits to read the rules of:
  `awesome-windows`, `awesome-privacy`, `awesome-list-windows-debloaters`.
- **Creator outreach** — YouTubers who cover Windows optimisation. Use
  `press-kit.md`; one 30-second personal email beats a mass BCC.

---

## 8. What NOT to do

- ❌ Buy stars, downloads or upvotes. GitHub and Reddit detect it; it can kill
  the repo's or account's reputation permanently.
- ❌ Post the same text in 5 subreddits at once.
- ❌ Hide that you're the developer.
- ❌ Argue with critics. Answer once, thank them, move on — the thread is read
  by hundreds of people who never comment.

---

## Post log (fill this in — it's how you learn)

| Date/time (UTC) | Channel | URL | Downloads before | Downloads after (24h) |
|---|---|---:|---:|---:|
| | | | | |
| | | | | |

---

## If it goes well

Reply to **every** comment for the first two hours. Ask people what tweaks
they'd want. Every reply bumps the thread and every "actually useful" comment
is what turns a download into a donation later.
