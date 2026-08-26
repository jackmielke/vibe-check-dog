# Vibe Check: Dog Judge

A native SwiftUI iOS app. A very unimpressed dog looks you in the face, rates
your vibe out of 100, and roasts you in one line. Open the app, and if you have
not been judged today the dog asks for a vibe check.

Native rewrite of the original Lovable web app (`~/dev/vibe-check-with-a`),
reusing that project's existing Supabase backend unchanged.

## How it works

- **Scoring** — `analyze-vibe` edge function, Gemini 2.5 Pro via the Lovable AI
  gateway. The key stays server-side; the app only ever sends a photo.
- **Local first** — every check is scored and stored on device. Nothing is
  uploaded to the leaderboard until you sign in with Apple and explicitly post,
  which routes through `submit-vibe` instead.
- **Leaderboard** — `leaderboard-api`, shared with the original web app, so the
  existing entries and photos are already there.
- **Sign in with Apple** — used only to attach a real name to a post. No account
  is created on any server; the identifier lives in UserDefaults and is cleared
  on sign out.

## The dog

`VibeCheck/Views/DogView.swift` is an original illustration composed from SwiftUI
primitives, not an image asset. It stays sharp at any size, blinks on a timer,
and changes its eyelids, brows, and head tilt based on the score. The app icon is
rendered from that same view (`-renderIcon`), so the home screen mark and the
in-app dog are literally the same drawing.

## Build

```bash
xcodegen generate
xcodebuild test -project VibeCheck.xcodeproj -scheme VibeCheck \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

`VibeCheckTests` covers the backend's rough edges (fractional scores, Postgres
timestamps with variable fractional seconds) and the image-encoding path the
simulator cannot exercise. `VibeCheckUITests` drives the app and captures the
screenshot set.

Vibe Check is a joke. The dog is not a real judge of anything.
