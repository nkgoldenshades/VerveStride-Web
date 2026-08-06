---
inclusion: always
---

# Deployment Guide

## ⚠️ IMPORTANT: Hosting is GitHub Pages, NOT Firebase Hosting

The production site `vervestrideai.com` is hosted on **GitHub Pages** via a separate repo:
- **Repo**: `https://github.com/nkgoldenshades/VerveStride-Web`
- **Branch**: `main`
- **Domain**: `vervestrideai.com` (configured via `CNAME` file in repo root)

**DO NOT use `firebase deploy --only hosting`** — that deploys to `vervestride-app.web.app` which is NOT the live site.

## Correct Deploy Steps

```bash
# 1. Build
flutter build web --release --no-wasm-dry-run

# 2. Add CNAME (must exist in every build)
echo "vervestrideai.com" > build/web/CNAME

# 3. Push to GitHub Pages repo (run from build/web folder)
cd build/web
git init                  # only needed first time
git remote add origin https://github.com/nkgoldenshades/VerveStride-Web.git  # only needed first time
git checkout -b main      # only needed first time
git add -A
git commit -m "Deploy - <date>"
git push --force origin main
```

## Notes
- The `build/web` folder already has `.git` initialized pointing to `VerveStride-Web`
- Always include `CNAME` file with content `vervestrideai.com` — without it GitHub Pages loses the custom domain
- GitHub Pages takes 1-2 minutes to deploy after push
- Firebase Hosting (`vervestride-app.web.app`) is unused — ignore it
