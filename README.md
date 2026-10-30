# Aura

Native iOS app (SwiftUI, ARKit/RealityKit, Core Data, Firebase) for finding virtual walls near you, opening them in AR and leaving messages. Target city: Colombo, Sri Lanka.

## For markers: quick start

1. Clone the repo and open `Aura.xcodeproj` in Xcode 26.5 or newer.
2. Copy the supplied `GoogleService-Info.plist` (it comes with the submission, it is not in the repo) into the `Aura/` folder.
3. Create a file `Config/Local.xcconfig` with these two lines (for the simulator the team can stay empty):

   ```
   AURA_BUNDLE_ID = l.Aura
   DEVELOPMENT_TEAM =
   ```

   `l.Aura` matches the supplied plist. Without this file the app uses `com.example.Aura`.
4. Choose the `Aura` scheme and an iPhone 17 Pro simulator, then press Run (⌘R).

## Logging in

- **Test account:** email `[TEST ACCOUNT EMAIL]`, password `[TEST ACCOUNT PASSWORD]`. Use Welcome → "I already have an account" → Log in.
- **Or make your own:** Welcome → Get started → Sign up. Any email works, no verification is needed. Onboarding asks for interests and an avatar, then offers location and a practice AR wall (Skip is fine in the simulator).
- New accounts start with 1,000 points.
- "Continue with Google" only works for the original bundle ID `l.Aura` on the original Firebase project. Use email sign-in.

