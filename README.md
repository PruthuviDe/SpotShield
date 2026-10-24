# SpotShield

SpotShield is an iOS parking-management app for motorists, parking wardens, and administrators. Motorists can find parking zones, pay for and manage a parking session, and review their parking and ticket history. Wardens can check vehicle plates and submit observations for review. Administrators manage zones, warden applications and assignments, and enforcement decisions.

The project uses SwiftUI and Firebase. The `SpotShield Local` Xcode scheme connects to the Firebase Emulator Suite so the app can be developed and assessed without a deployed Firebase backend.

The app labels the Motorist role as **Driver** in its interface. Both names refer to the same role.

## Contents

- [Features](#features)
- [Technology](#technology)
- [Requirements](#requirements)
- [Run the app locally](#run-the-app-locally)
- [Set up local accounts and data](#set-up-local-accounts-and-data)
- [Keep emulator data between runs](#keep-emulator-data-between-runs)
- [Try the main workflows](#try-the-main-workflows)
- [Tests and checks](#tests-and-checks)
- [Architecture and project layout](#architecture-and-project-layout)
- [Permissions and device checks](#permissions-and-device-checks)
- [Troubleshooting](#troubleshooting)
- [Current scope and limitations](#current-scope-and-limitations)

## Features

### Motorist

- Create an account, sign in, reset a password, and manage profile details and a vehicle plate.
- View parking zones on a map and choose a zone and duration.
- Start, extend, and end parking sessions, with wallet balance and parking history.
- Receive local parking expiry reminders and zone arrival alerts when permissions allow.
- View a Live Activity for an active parking session.
- Protect access to the signed-in account with Face ID or Touch ID where available.
- Review tickets and manage ticket payments from the wallet.

### Parking Warden

- Apply for a warden account and view the application status.
- View assigned parking zones after an administrator approves the application and creates an assignment.
- Scan a vehicle plate with the camera, check its parking status, and submit an observation.
- Review submitted observations and their outcomes.

### Administrator

- View an overview of parking zones, warden applications, and observations awaiting review.
- Create, update, publish, and deactivate parking zones.
- Approve or reject warden applications and assign approved wardens to zones.
- Review warden observations and issue or dismiss tickets.

## Technology

- SwiftUI and Swift, using Swift 5 language mode in the project settings.
- Firebase Authentication, Cloud Firestore, and callable Cloud Functions.
- Firebase Emulator Suite for local Authentication, Firestore, and Functions.
- MapKit and Core Location for zone discovery and geofencing.
- VisionKit and AVFoundation for camera-based plate recognition.
- UserNotifications for local notifications; remote push notifications are not configured.
- ActivityKit and WidgetKit for Live Activities.
- LocalAuthentication for Face ID and Touch ID.

The wallet and ticket-payment flows record LKR balances and transactions in the application backend. No external payment processor is connected.

## Requirements

- A Mac with Xcode. **Xcode 27.0 with an iOS 27.0 Simulator** is the verified development setup for the current project configuration.
- Node.js 22 and npm for the Firebase Functions code.
- Java 21 for the Firebase emulators.
- Firebase CLI (`firebase-tools`). A Firebase account or deployed project is not required to run the local scheme.

The main app target is set to iOS 18.6, but the Live Activity extension and unit-test target currently inherit iOS 27.0. Use an iOS 27.0 Simulator for the full project and test suite; the main app's deployment setting alone does not establish compatibility of the complete app with older iOS versions.

Check the installed tools with:

```sh
xcodebuild -version
node --version
npm --version
java -version
firebase --version
```

If needed, install the Firebase CLI:

```sh
npm install --global firebase-tools
```

## Run the app locally

Run the following commands from the repository root, where `firebase.json` is located. Internet access is needed initially to install dependencies and resolve Xcode's Swift packages.

1. From the repository root, install the Functions dependencies:

   ```sh
   npm --prefix functions ci
   ```

2. For a fresh setup, start the local Firebase services and leave the terminal open. If you already have an `emulator-data/` export, use the restore command under [Keep emulator data between runs](#keep-emulator-data-between-runs) instead.

   ```sh
   firebase emulators:start --only auth,firestore,functions --export-on-exit=./emulator-data
   ```

   The Emulator Suite UI is available at <http://127.0.0.1:4000>. Authentication uses port `9099`, Firestore uses `8080`, and Functions uses `5001`.

3. Open `SpotShield.xcodeproj` in Xcode and let the Swift packages resolve. Select the **SpotShield Local** scheme and an iOS 27.0 Simulator, then press **Run** (`Command-R`). The local scheme uses the Debug configuration, sets `SPOTSHIELD_USE_EMULATORS=1`, and connects to the `demo-spotshield` emulator project.

### Run on a physical iPhone

1. Connect the iPhone to Xcode, trust the Mac, and enable Developer Mode if prompted.
2. Under **Signing & Capabilities**, select your development team for both `SpotShield` and `SpotShieldLiveActivityExtension`. Select the iPhone as the run destination.
3. Keep the iPhone and Mac on the same network. In **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**, set `SPOTSHIELD_EMULATOR_HOST` to the Mac's reachable hostname or LAN IP address. The checked-in scheme currently uses `users-MacBook-Air.local`.
4. Run the app and allow Local Network access when requested. Keep emulator ports `9099`, `8080`, and `5001` reachable through the Mac's firewall.

The Simulator always uses `127.0.0.1`; it ignores the configured device hostname. On an iPhone, `127.0.0.1` refers to the phone itself and cannot reach emulators on the Mac.

Emulator mode is available in Debug builds and its setting is remembered on the device. Keep using **SpotShield Local** for this workflow. When emulator mode is disabled, Firebase setup loads `GoogleService-Info.plist`.

## Set up local accounts and data

The repository does not include a Firestore seed dataset. A fresh emulator therefore starts with empty collections. You can create test records through the app and Emulator Suite UI.

1. Create an Administrator for local development in the Emulator Suite UI. In **Authentication**, add an email/password account and copy its generated UID. In **Firestore**, create a document in the `users` collection with that UID as its document ID and these fields:

   ```json
   {
     "name": "Administrator",
     "email": "admin@example.com",
     "role": "Admin"
   }
   ```

   Use the same email as the Authentication account. The `role` value is case-sensitive. This step bootstraps the first Administrator through the local Emulator UI; the app does not offer public Administrator registration.

2. Sign in as the Administrator and create a parking zone. New zones begin as unpublished and inactive. Set its location, radius, LKR hourly rate, opening and closing hours, and maximum stay. Zone schedules use `Asia/Colombo` time.
3. Sign out and submit a Warden application from the app. Sign back in as Administrator, approve the application, and assign that Warden to the zone.
4. Publish and activate the zone using its active Warden assignment. Creating a zone alone does not make it available for parking.
5. Create a Motorist account from the app's sign-up flow and add its vehicle plate. Open **Wallet** and select **Top Up LKR 1,000** before starting paid parking. A new wallet starts with a zero balance.

Password-reset links generated for local accounts are available through the Authentication Emulator UI. They are not sent as real email while using the emulator.

## Keep emulator data between runs

Stop the emulators with **Control-C** in their terminal and wait for the export to finish. The first-run command above saves the local accounts and Firestore records into `emulator-data/`.

For later sessions, restore that existing export and save updates on exit:

```sh
firebase emulators:start --only auth,firestore,functions --import=./emulator-data --export-on-exit=./emulator-data
```

Use `--import` only when the directory contains a Firebase export, including `firebase-export-metadata.json`. An empty directory is not a saved dataset. Start only one Emulator Suite instance at a time.

If an emulator session is already running without `--export-on-exit`, save it from a second terminal before stopping it:

```sh
firebase emulators:export ./emulator-data
```

The `emulator-data/` directory is ignored by Git and is not included in a fresh clone. To reproduce an existing local assessment dataset on another Mac, transfer its export separately and import it there. Avoid including personal accounts or private location data in a shared export.

## Try the main workflows

After creating the accounts and publishing a zone:

1. **Driver:** top up the wallet, choose a zone, select a duration, confirm **I am parked in this zone**, and start parking. Check the receipt, wallet debit, and Live Activity. Extend the session, then end it and check History.
2. **Warden:** sign in to the assigned zone, enter a plate or scan it on a supported iPhone, and check its parking status. Confirm the recognized plate before continuing. A valid paid session should not be reportable; an eligible violation can be submitted as an observation.
3. **Administrator:** review the observation and issue a ticket or dismiss it. Sign back in as the Driver to check the ticket and its payment outcome.
4. **Device features:** enable arrival alerts from the parking map, enable biometric access from Profile, and check parking expiry reminders and Live Activities on a supported device.

## Tests and checks

The Swift Testing suites cover parking opening hours, duration and extension limits, price calculations, reportable statuses, and composition of recognized plate text. The text-composition tests use supplied text fragments; they do not measure live camera recognition accuracy.

Run the iOS unit tests in Xcode with the **SpotShield Local** scheme and **Product → Test** (`Command-U`), or use `xcodebuild`:

```sh
xcodebuild test \
  -project SpotShield.xcodeproj \
  -scheme "SpotShield Local" \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

If that simulator is not installed, replace its name with an available iOS Simulator destination shown by `xcodebuild -showdestinations -project SpotShield.xcodeproj -scheme "SpotShield Local"`.

Check the JavaScript Functions files for syntax errors:

```sh
npm --prefix functions run check
```

The Functions integration suite checks profile and vehicle ownership, parking operations, role restrictions, enforcement, ticket payments, retries, and protected Firestore writes. It requires the Auth, Firestore, and Functions emulators to be running in another terminal and creates and removes its own temporary test records:

```sh
npm --prefix functions run test:emulator
```

Camera capture, OS permission prompts, biometrics, notification delivery, and Live Activity appearance also need manual device checks. Passing the automated suites does not replace those checks.

## Architecture and project layout

The app follows an MVVM structure: **Views → ViewModels → Repositories → Firebase**. Views display state and forward user actions; view models manage loading, validation, and screen state. Repositories read Firestore data and call backend Functions. `AppState` and `RootCoordinatorView` manage authentication and navigation for each role.

Shared parking rules live in `Domain`. Native platform managers handle location, notifications, biometrics, and Live Activities. Financial and enforcement mutations are validated again in backend Functions, while Firestore rules control direct client access.

```text
SpotShield/                         iOS app source
  App/                              App entry point and role-based coordination
  Domain/                           Models, roles, and parking rules
  Data/Firebase/                    Firebase setup
  Data/Repositories/                Firestore data access
  Services/Authentication/          Sign-in, account creation, and password reset
  Features/                         Motorist, Warden, Admin, profile, and auth UI
  Platform/                         Biometrics, location, notifications, Live Activity, OCR
  Shared/DesignSystem/              Shared colors and UI components
SpotShieldLiveActivity/             Live Activity and widget extension
SpotShieldTests/                    Swift unit tests
functions/                          Firebase callable Functions and tests
firestore.rules                     Firestore access rules
firestore.indexes.json              Firestore indexes
firebase.json                       Emulator and Firebase project configuration
```

The main Firestore collections include `users`, `vehicles`, `parkingZones`, `wardenRequests`, `wardenAssignments`, `wallets`, `parkingSessions`, `activeParkingSessions`, `wardenObservations`, and `simulatedTickets`. Wallet transactions are stored under `wallets/{userId}/transactions`.

## Permissions and device checks

SpotShield requests permissions when a feature needs them:

- **Location:** nearby zones and arrival geofencing. Use **Enable Arrival Alerts** on the parking map and grant **Always** location access for the implemented background arrival-alert flow. Inside/outside zone labels do not by themselves mean arrival alerts are enabled.
- **Notifications:** local parking and geofence alerts. Notification access can be changed later in iPhone Settings.
- **Camera:** plate scanning for Wardens. Use a physical device to verify live camera capture.
- **Face ID or Touch ID:** optional app access protection when supported and enabled.
- **Live Activities:** allow them when iOS asks so an active parking session can appear on the Lock Screen and supported Dynamic Island devices.

The Simulator can simulate a location through **Features → Location**. Test notifications and geofencing with the app configured for the local emulator and with the relevant iOS permissions enabled.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Sign-in or parking requests fail | Keep all three backend emulators running. On an iPhone, check the Mac hostname/IP, Local Network permission, and network connection. |
| Previously added accounts or zones are missing | Restart with the saved export using `--import`. Starting an empty suite does not restore previous sessions automatically. |
| A new zone is not available for parking | Approve a Warden, create an active assignment, and publish/activate the zone. Check its opening hours and stay limit. |
| Start Parking is unavailable | Add a vehicle, select an available duration, confirm that you are parked there, and check the wallet balance. Resolve or end any existing active session. |
| The map shows the correct zone but no arrival alert arrives | Enable arrival alerts separately, allow notifications and Always location access, and check iOS Focus settings. Location updates and notification delivery are separate features. |
| The camera preview is unavailable | Check camera permission and scanner support on the physical device. If screen sharing is active, stop sharing and retry. You can also enter the plate manually. |
| An emulator port is already in use | Stop the existing suite before starting another instance. Use Control-C in the terminal that started it. |
| Xcode reports a locked build database | Stop the other build or test using the same project build directory, then retry a single build. |

## Current scope and limitations

- The local app uses Firebase Emulator Suite services, not a deployed backend. Data created in the Emulator Suite is separate from data in any cloud Firebase project.
- The local Firebase project ID is `demo-spotshield`, configured in `.firebaserc` and `FirebaseConfig.swift`.
- Each Motorist has one primary vehicle. Multiple-vehicle management is outside the current scope.
- Zone location indicators help the Driver choose a zone. Starting parking requires the Driver's confirmation of presence; the backend does not verify GPS coordinates.
- Geofencing sends arrival alerts. A dedicated exit notification is not implemented, although the interface can show whether the device is inside or outside a zone.
- Parking reminders are scheduled locally. Live updates from another user's actions require the app to fetch updated backend data; there is no remote push delivery for tickets or approvals.
- Remote notifications, a production Firebase deployment, and an external payment provider are not configured.
- Camera scanning depends on supported hardware and image quality. The Warden should confirm or correct the plate before checking it.
- The `Documents/` folder is ignored by Git and may contain coursework notes and assessment materials that are not part of the app build.

- **Module:** NB6009CEM
- **Author:** W.P.N.S.M.D.SILVA
- **Coventry ID:** 16602658 · **NIBM ID:** COBSCCOMP25.1P-016
