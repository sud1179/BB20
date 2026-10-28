# Big Boss Popularity (Android) — ~$0/month

## 1. Backend (free)
1. Create a GitHub repo, push this whole folder.
2. Edit `contestants.json` with real names (and set `SHOW_NAME` in collect.yml env if needed).
3. Get a YouTube Data API key (Google Cloud Console, free) and a Gemini API key (aistudio.google.com, free tier).
4. Repo Settings > Secrets > Actions: add `YOUTUBE_API_KEY`, `GEMINI_API_KEY`.
5. Actions tab > "collect" > Run workflow. It then runs every 6 hours and commits `data.json`.
   (Make the repo public so the app can read the raw file for free.)

## 2. App
1. Install Flutter. In `app/` run: `flutter create . --platforms=android` (generates android/ folder; keeps lib/ and pubspec).
2. In `app/lib/main.dart`, set `dataUrl` to `https://raw.githubusercontent.com/<user>/<repo>/main/data.json`.
3. Test: `flutter run`. Build: `flutter build apk --release` (share APK free) or `flutter build appbundle` for Play Store ($25 one-time).

## Score
score = 5*videos + 3*shorts + 4*IG/FB posts + 0.02*comments*(0.5 + positive_ratio)
Tune weights in `collector/collect.py`. IG/FB counts are 0 until Meta Graph API access is added in `collect()`.
