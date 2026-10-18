# Local Firebase testing

The live Firebase project stays on Spark. Local tests use `demo-spotshield`, with separate accounts and data.

## Start the backend

Open Terminal in the SpotShield project folder and run:

```bash
npm --prefix functions ci
npx -y firebase-tools@latest emulators:start --project demo-spotshield --only auth,firestore,functions
```

Keep this Terminal open while testing. Open the local control page at http://127.0.0.1:4000.

| Service | Port |
|---|---:|
| Authentication | 9099 |
| Firestore | 8080 |
| Functions | 5001 |
| Control page | 4000 |

## Run the app locally

1. Stop the app in Xcode.
2. Open Product > Scheme and select **SpotShield Local**.
3. Select an iPhone simulator and run the app.
4. Create a new test Driver account, then open Wallet.

The shared SpotShield Local scheme enables `SPOTSHIELD_USE_EMULATORS=1` for every Run. A one-time Terminal launch does not enable this setting for later Xcode runs.

The local mode connects Authentication and Firestore before AppState starts. It uses a separate Firebase app ID and an in-memory Firestore cache. Existing cloud accounts do not exist in this local project.

Select the normal **SpotShield** scheme to return to the live Spark project, and ensure it has no enabled `SPOTSHIELD_USE_EMULATORS` variable. Local mode is available only in Debug builds running in the simulator. An account created in the live project will not appear locally; create a fresh local account after switching schemes.

## Current backend

`functions/index.js` contains a small `checkConnection` callable function. It requires sign-in and returns a message. It does not change any records. The iOS app does not call it yet; the Firebase Functions iOS dependency will be added with the wallet top-up integration.

`firestore.rules` contains the complete previously tested prototype rules. Direct wallet balance updates and transaction writes remain blocked. Review these rules before sharing the app widely. No rules or functions have been deployed to the live project.

## Stop testing

Stop the app, then press Control-C in the emulator Terminal. Without an export, local records are cleared when the emulators stop. Create fresh test accounts when starting again. These records never become live Firebase data.

Wallet top-ups and parking payments are the next backend features; they are not implemented by this setup.
