# Scottimizer — press & creator kit

Everything a writer, YouTuber or curator needs, in one page. Link them here:
**https://github.com/SCOTTYinCntrl/Scottimizer/blob/main/marketing/press-kit.md**

---

## One-liner

**Scottimizer** is a free, open-source Windows 10/11 tuner that benchmarks the
before/after latency of every change and can undo all of them — 79 tweaks, a
one-click security audit, and no ads, telemetry or paid tier.

## Fact sheet

| | |
|---|---|
| **Name** | Scottimizer |
| **Tagline** | Free Windows gaming, privacy & security tuner |
| **Category** | Utilities / System Tuning · Open Source |
| **Platform** | Windows 10, Windows 11 (x64) |
| **Built with** | Windows PowerShell 5.1 + WPF (no runtime to install) |
| **License** | MIT |
| **Price** | Free. Donations optional, unlock nothing. |
| **Version** | 2.1.3 |
| **Homepage** | https://scottyincntrl.github.io/Scottimizer/ |
| **Source** | https://github.com/SCOTTYinCntrl/Scottimizer |
| **Download** | https://github.com/SCOTTYinCntrl/Scottimizer/releases/latest |
| **Demo (20s)** | https://scottyincntrl.github.io/Scottimizer/#demo |
| **Donate** | https://cash.app/$ScottyRockIt27 |
| **Author** | SCOTTYinCntrl |
| **Inspired by** | Chris Titus Tech's WinUtil |

## What's genuinely different (the hook)

1. **It benchmarks itself.** Before and after every change it pings a target and
   records average latency and jitter, colour-coded and exportable to CSV. You
   can see which tweaks actually helped instead of trusting a magic button.
2. **A real undo.** It snapshots the exact prior state — registry values *and
   their types*, service start modes, the active power plan, DNS — and restores
   that, rather than guessing.
3. **Security audit + one-click fix.** ~36 read-only checks produce a 0–100
   score; failing items that map to a tweak get a Fix button.
4. **Additive security only.** It never disables Microsoft Defender, Windows
   Firewall or Windows Update. That's the usual reason people distrust tweakers.

## Blurbs (copy-paste)

**One line**
> Free, open-source Windows tuner: 79 tweaks, a security audit, per-tweak latency
> benchmarks and a real undo. https://scottyincntrl.github.io/Scottimizer/

**Short (~300 chars)**
> Scottimizer is a free, open-source (MIT) Windows 10/11 tuner for gaming
> performance plus privacy and security. 79 tweaks, a one-click security audit
> with a 0–100 score, per-tweak before/after latency benchmarking, and exact-state
> undo. No ads, no telemetry, no paid tier. https://scottyincntrl.github.io/Scottimizer/

**Long**
> **Scottimizer — make Windows faster and safer, reversibly.**
> A ground-up Windows tweaker built for gaming speed *plus* privacy and security
> hardening. 79 tweaks across Gaming & Performance, Network & Latency, Security
> Hardening, Privacy, Debloat and System & Storage. Run a ~36-point security
> audit, get a 0–100 score, and fix failing items in one click. Benchmark the
> before/after latency of *every* tweak, then undo anything using an exact-state
> snapshot (registry values and their types, services, power plan and DNS). Six
> one-click profiles, a live dashboard and complete appearance customisation.
> Additive security only — it never disables Defender, the firewall or Windows
> Update. Free and open source (MIT).

## Assets

All screenshots are 1:1 PNGs of the real UI. The demo is a 20-second vertical
clip (also usable as a Short/Reel).

| Asset | URL |
|---|---|
| App icon | https://scottyincntrl.github.io/Scottimizer/assets/icon.png |
| Dashboard | https://scottyincntrl.github.io/Scottimizer/assets/shot-dashboard.png |
| Security audit | https://scottyincntrl.github.io/Scottimizer/assets/shot-audit.png |
| Latency benchmarks | https://scottyincntrl.github.io/Scottimizer/assets/shot-benchmarks.png |
| Gaming & performance | https://scottyincntrl.github.io/Scottimizer/assets/shot-gaming.png |
| Security hardening | https://scottyincntrl.github.io/Scottimizer/assets/shot-security.png |
| Appearance | https://scottyincntrl.github.io/Scottimizer/assets/shot-appearance.png |
| Demo video (20s, 9:16) | https://scottyincntrl.github.io/Scottimizer/assets/demo.mp4 |

## Pitch email (creators / press)

> **Subject:** Free open-source Windows tuner that benchmarks + reverses every tweak
>
> Hi <name>,
>
> I liked your <specific video/post> — especially <specific detail>, so this felt
> relevant rather than random.
>
> I built **Scottimizer**, a free, open-source (MIT) Windows tuner. The bit I
> think your audience would care about: it **benchmarks the before/after ping of
> every tweak** and keeps an **exact-state undo**, so it's the opposite of a
> black-box "optimizer". It never disables Defender, the firewall or Windows
> Update.
>
> 20-second demo: https://scottyincntrl.github.io/Scottimizer/#demo
> Press kit + assets: https://github.com/SCOTTYinCntrl/Scottimizer/blob/main/marketing/press-kit.md
>
> No obligation at all — happy to answer anything, and I can send a signed-off
> build or the source if that helps.
>
> Thanks,
> <your name>

Keep it **one** paragraph of pitch, one of proof, one of links. Personalise the
first line per recipient — that's what gets it opened.

## Fact-check notes (for accuracy)

- The `.exe` is **unsigned**; first run triggers SmartScreen
  ("More info → Run anyway"). Running `Scottimizer.bat` avoids it.
- It **requires Administrator** (registry, services, power plan, DNS).
- winget package is submitted and **pending review**; Scoop/Chocolatey manifests
  exist but aren't published yet.
- It's a **PowerShell/WPF** app, not a compiled native binary — the source is
  plain text and auditable.
