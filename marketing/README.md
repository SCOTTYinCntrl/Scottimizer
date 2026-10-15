# Scottimizer — growth & funding playbook

Scottimizer is **free, MIT, no ads, no telemetry, no paid tier**. Money only
comes from **donations**, so the entire game is **reach**: more downloads →
more people who feel helped → a small fraction tip.

## The honest math

Donation conversion across free desktop utilities is roughly **0.05%–0.25%** of
downloads, at an average of **$5–$15** per tipper. That means:

| Downloads | Realistic donors | Realistic revenue |
|---|---:|---:|
| 1,000 | ~1–2 | $5–$30 |
| 10,000 | ~5–25 | $50–$350 |
| 100,000 | ~50–250 | $500–$3,500 |

So a well-made app is worth almost nothing until it is **seen**. Every script
and doc in this folder exists to increase the top number (downloads) and lower
the friction to tip.

## What is automated vs. what is one click

| Task | How |
|---|---|
| Ship a new version (build, zip, checksum, tag, release, assets) | `tools\Release.ps1 -Version x.y.z` (or push a `v*` tag) |
| Never ship a broken build | `.github/workflows/validate.yml` |
| Offer a tip option on the repo | `.github/FUNDING.yml` → the **Sponsor** button |
| Tip in one click from the site | `docs/index.html` → Support section |
| Update the winget package | `tools\Update-Winget.ps1 -Version x.y.z` |
| Post/submit to directories | copy in `launch-kit.md`, checklist in `targets.md` |

## Files

* **`ready-to-post.md`** — 👈 **start here.** Paste-ready posts for the platforms
  you already have (Reddit, X, TikTok/YouTube/Instagram), in the order to post
  them, with the media and captions to attach.
* **`video-launch.md`** — the 22-second vertical promo video
  (`Scottimizer-promo-1080x1920.mp4`) and a **separate caption + hashtag set for
  TikTok, X, Instagram and YouTube**. Read this next to the video. The frame
  renderer lives at `../tools/Build-PromoVideo.ps1`.
* **`launch-runbook.md`** — the wider "do this now" sequence:
  pre-flight, Reddit, Show HN, directories, video, and a post log to measure
  which channel worked.
* **`launch-kit.md`** — ready-to-paste copy for every channel (short/long blurbs,
  Reddit posts, Show HN, a tweet thread, video hooks, directory fields).
* **`press-kit.md`** — fact sheet, asset URLs and a pitch email for creators and
  press. Send people this link.
* **`targets.md`** — where to submit, with links and a status checklist.
* **`../tools/Get-Metrics.ps1`** — run it to see stars, downloads and traffic
  (the north-star number) before and after each post.

## Rules of thumb

1. **Post where promotion is welcome.** Read each subreddit's self-promotion
   rules first; one good post beats five removed ones (and bans).
2. **Lead with the demo, not the ask.** Screenshots and the TikTok clip get
   clicks; the donation link does the rest.
3. **Ship often.** Every release is a new reason to post.
4. **Reply to everyone.** Forums and issue threads are where "free but worth
   paying for" reputations are built.
