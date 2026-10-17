# GitHub HR & Engineering Scan Report
**Account:** Salman-Farid (Salman Farid Rahman) · **Scanned:** 8 Oct 2026 · **Scope:** all 67 public repositories

Method: full metadata pull of every public repo, root file listing of each (README / LICENSE / .gitignore presence), profile README review, and a secrets sweep (API keys, tokens, `.env` files, AWS keys) across all repos.

---

## Verdict

You have a genuinely strong core — real shipped Flutter apps with good READMEs (MacnoDroidCleaner, FitBook, BRQ DocScan, the plant-disease thesis project). That is what should be visible.

Right now it is buried under ~25 tutorial-clone repos, 2 completely empty repos, typos in repo names, broken links on your profile, and 7 verbatim copies of other people's open-source projects pushed under your name (not as forks). A recruiter spending 60 seconds on your profile sees clutter and sloppiness before they ever reach the good stuff. None of this is fatal — all of it is fixable in a weekend.

**Secrets check: clean.** No `.env` files, no AWS keys, no tokens committed. The Firebase keys in `firebase_options.dart` / `google-services.json` are normal client-side config, not a leak.

---

## 🔴 Critical — fix before your next application

### 1. Delete the 2 empty repos (zero commits — the worst possible look)
- `batteryguard-pitch`
- `backend`

An empty public repo tells a screener you start things and abandon them. Delete, don't archive.

### 2. Delete or privatize 7 copies of other people's projects
These are **not forks** — they are someone else's repos pushed under your name, most bulk-pushed on 23–26 Jan 2025. To an engineer reviewing you, this reads as claiming others' work:
- `OpenNutriTracker-main`
- `OpenAuthenticator-main`
- `observatory-main`
- `flutter_twitter_clone-master`
- `Flutter_EbookApp-master`
- `finance_app_UI-main`
- `nopCommerce-develop`

### 3. Fix the broken links on your profile README
Your profile links to `Salman-Farid/CodeForces-Solutions` and `Salman-Farid/LeetCode-Solutions`. **Neither repo exists.** Your two biggest competitive-programming claims 404. Either create/publish those repos or remove the links.

### 4. Fix `thesis_defense` — it contains a template placeholder
Its README is a copy of the PlantTreatmonty README containing:
`git clone https://github.com/your-username/plant_treatmonty.git`
A literal `your-username` placeholder in a thesis repo is an instant credibility hit. Also the repo name doesn't match its content. Either rewrite it as a real thesis repo or delete it (`plantTreatmonty` already holds the app).

### 5. Rename the typo repos (GitHub renames auto-redirect, so it's safe)
- `plantTreatmonty` → `plant-treatment-app` (also fix the typo inside its README)
- `WallpaperBot_A-Walpaper-app-by-flutter` → fix "Walpaper"
- `Python_Code_Practice_Basic_to_Adavnce` → fix "Adavnce"
- `Mofa-s-Kitchen-Buddy` → `mofas-kitchen-buddy`
- `Infinite_Slider` description: "stunningAdvanced UI" → missing space

### 6. Privatize the ToS-grey projects
Most engineers won't care, but HR/compliance at banks and enterprises might:
- `Facebook-Scraper-by-Playwright` — "automating Facebook login"
- `facebook-group-scraper-new-method-2025`
- `Oracle-oci-arm-host-capacity` — "allows to bypass Oracle Cloud Infrastructure 'Out of host capacity' errors"
- `Phishing-App-Detector-Ethical-Hacking-Course-project` — it's a legit ethical-hacking course project, but **the name starts with "Phishing-App"**. An automated keyword scan or a non-technical recruiter will misread this. Rename or privatize.

---

## 🟡 High-priority polish

- **Repo name ≠ project name** (confusing when linked on a CV):
  - `healthydiet` → the README says **FitBook 2026**. Rename the repo to `fitbook-2026`.
  - `brq-web` → the README says **BRQ DocScan**. Rename to `brq-docscan`.
  - `Nakhlah_2.0` → has no description at all. What is it? One line would fix it.
- **MacnoDroidCleaner** (your flagship): README claims "production-ready" but Screenshots says *"Coming soon"*. Add 3–4 screenshots — this is the repo a hiring manager will open first.
- **32 repos have no description.** At minimum, add one-liners to the ~12 keepers listed below.
- **43 repos have no LICENSE file.** Add MIT to your original work (at least the portfolio pieces) — "no license" means "not open source" to a careful reader, and some companies won't touch unlicensed code.
- **3 repos still default to `master`**: `MacnoDroidCleaner`, `Vacation_App_by_flutter`, `flutter-google-docs-clone`. Switch the flagship to `main`.
- `Salman-Farid.github.io` (your portfolio site) has **no README**. It's your personal site — it should explain itself and show a live demo link.
- `AnyHow_Vendor_App` has no README.
- **Pin 6 repos** on your profile so visitors see the best first: `MacnoDroidCleaner`, `healthydiet`, `brq-web`, `plant_disease_detection`, `Nano-scrap-fbride`, `Admin-panel`.

---

## 🟢 What's already good (keep doing this)

- Your 2026 work has genuinely good READMEs: `brq-web`, `healthydiet`, `MacnoDroidCleaner`, `Nano-scrap-fbride`.
- Profile README is polished and visual.
- The 8 forks are properly marked as forks — honest, no issue.
- Commit activity is recent across the portfolio pieces; nothing looks abandoned since 2024.

---

## Full repo-by-repo action list

### KEEP & POLISH (your real work — descriptions, topics, LICENSE, screenshots)
`Salman-Farid` (profile) · `MacnoDroidCleaner` · `healthydiet` → rename `fitbook-2026` · `brq-web` → rename `brq-docscan` · `plantTreatmonty` → rename `plant-treatment-app` · `plant_disease_detection` · `Admin-panel` · `Smartsociety-Application-by-Flutter` · `Nakhlah_2.0` (add description) · `Salman-Farid.github.io` (add README) · `Logos` · `Infinite_Slider` (fix description typo) · `ShinraAI-du-student-submission` (fork, competition entry — fine) · `Nano-scrap-fbride`, `deer-flow`, `hermes-agent-contribution` (forks — fine)

### DELETE (2)
`batteryguard-pitch` · `backend` — both completely empty, zero commits.

### PRIVATIZE or DELETE — others' projects pushed as your own (7)
`OpenNutriTracker-main` · `OpenAuthenticator-main` · `observatory-main` · `flutter_twitter_clone-master` · `Flutter_EbookApp-master` · `finance_app_UI-main` · `nopCommerce-develop`

### PRIVATIZE — ToS-grey / risky names (4)
`Facebook-Scraper-by-Playwright` · `facebook-group-scraper-new-method-2025` · `Oracle-oci-arm-host-capacity` · `Phishing-App-Detector-Ethical-Hacking-Course-project`

### ARCHIVE — tutorial/practice clones (honest history, read-only, out of the way)
`flutter-google-docs-clone` · `crypto_wallet_app_by_flutter` · `movies_app_built_on_flutter` · `flutter_planets_app` · `Gardenly_Flutter_App` · `water_drop_style_flutter` · `animated_playlist_card_flutter` · `Vacation_App_by_flutter` · `Drag-PDF_by_flutter` · `ebook_app_by_flutter` · `Food-UI-Transition_Animation_by_flutter` · `Flutter-Code-Snippet-videoplayer` · `Video-Controller-Code` · `Flutter_auth_by_api_and_getx` · `Helper_Code_Flutter` · `Flutter-Resources` · `Data-Science-Project-Materials` · `Python_Code_Practice_Basic_to_Adavnce` (rename first or just archive) · `Competitive_programming_codes_and_snippets` · `Bank_Account_System_Java_Project_1` · `webtest` · `Air-Dash` · `Doodle_Art_App` · `Mutual-Fund` · `Money_Management_Finance_App` · `PosManager_by_flutter` · `Neyoka_Ecommerce_by_flutter` · `Medcare-doctors_app_by_flutter` · `Overmorrow-by-flutter` · `smarty-by-flutter` · `AnyHow_Vendor_App` (add README first if you keep it public) · `Mofa-s-Kitchen-Buddy` · `leetcode-company-wise-problems` (fork — harmless either way) · `webkit` (verify what this is — a repo named `webkit` with a `stable` branch needs an explanation or a better name)

### FIX README content (3)
`thesis_defense` (remove `your-username` placeholder; fix name/content mismatch) · `plantTreatmonty` (fix "Treatmonty" typo) · `Salman-Farid.github.io` (write one)

---

## Suggested weekend order
1. Delete the 2 empty repos (2 minutes).
2. Fix the 2 broken profile links (5 minutes).
3. Privatize the 7 copies + 4 ToS-grey repos (10 minutes).
4. Rename the 4 typo repos + 2 mismatched names (15 minutes).
5. Rewrite `thesis_defense` README (20 minutes).
6. Add descriptions + topics + MIT LICENSE to the 12 keepers (1 hour).
7. Screenshots for MacnoDroidCleaner + pin 6 repos (1 hour).

Do steps 1–4 and your profile already looks like a different person.
