# Where to submit Scottimizer

Work top to bottom. Tick items off as you go. Prefer a few high-quality posts
over carpet-bombing — and **read each site's self-promotion rules first**.

Legend: `[ ]` todo · `[~]` in progress · `[x]` done

## Tier 1 — highest traffic, do these first

- [ ] **AlternativeTo** — https://alternativeto.net/manage-app/ (list as an
      alternative to Chris Titus WinUtil, O&O ShutUp10, Winaero Tweaker)
- [ ] **Reddit r/Windows11** — read rules + use flair. Post the "why" version.
- [ ] **Reddit r/software** — friendly to free tools.
- [ ] **Hacker News — Show HN** — post Tue–Thu, 8–10am US Eastern. Use the copy.
- [ ] **GitHub topic + social preview image** — repo settings → set the
      OpenGraph image to `docs/assets/shot-dashboard.png`.

## Tier 2 — strong, focused audiences

- [ ] **Reddit r/pcmasterrace / r/pcgaming** — lead with the benchmark angle.
- [ ] **Reddit r/opensource / r/coolgithubprojects**
- [ ] **r/windows, r/sysadmin** — only where rules allow; sysadmin likes the
      security audit + undo.
- [ ] **MajorGeeks** — https://www.majorgeeks.com/ (has a submission form)
- [ ] **Softpedia** — https://www.softpedia.com/ (submit via their form)
- [ ] **PortableApps.com** — https://portableapps.com/ (fits the "no install" model)
- [ ] **WindowsReport / Ghacks tips line** — email a short pitch with 2 screenshots.
- [ ] **Chocolatey** — https://community.chocolatey.org/packages (easy, scripted)
- [ ] **Scoop** — https://github.com/ScoopInstaller/Extras (submit a manifest PR)

## Tier 3 — evergreen distribution

- [ ] **winget** — already submitted (PR #453051). Update each release with
      `tools\Update-Winget.ps1`.
- [ ] **Microsoft Store** — optional; needs MSIX/Partner Center. Higher effort.
- [ ] **Product Hunt** — https://www.producthunt.com/ (pick a launch day)
- [ ] **SourceForge / Fosshub** — mirror the release zip.
- [ ] **LibHunt / Open Source Agenda / Awesome-Windows lists** — PR a link.

## Creators to pitch (one DM each, with the TikTok clip)

- [ ] Chris Titus Tech (he inspired the project — be gracious)
- [ ] Frédéric / "The Windows Club" style YouTube channels
- [ ] Enderman, JayzTwoCents-style "Windows optimization" videos
- [ ] r/Optimized, r/lowendgaming regulars

## Every release, after you run `tools\Release.ps1`

- [ ] Update winget: `powershell -NoProfile -File tools\Update-Winget.ps1 -Version x.y.z`
- [ ] Post the changelog as a short update on the busiest 1–2 channels only.
- [ ] Ask happy users for a ⭐ (it is the strongest ranking signal on GitHub).
