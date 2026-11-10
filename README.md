# Sana

**Campus incident reporting for African Leadership University.**
Students report broken facilities, water and power outages, sanitation problems, Wi-Fi failures and safety concerns. Campus staff triage them, update their status, and every change reaches the reporter in real time.

*Sana* comes from the Kinyarwanda *gusana*, "to repair".

Flutter · Firebase Authentication · Cloud Firestore · Firebase Storage · flutter_bloc

---
## Demo Video
You can watch the full 10-minute feature walkthrough and backend architecture explanation here:
**[Sana Demo Video - Google Drive](https://drive.google.com/file/d/1HiUjz2DH52hMzvV_Sq9lJJCun0BmwILt/view?usp=sharing)**

## What it does

| Students | Campus staff |
|---|---|
| Sign up with an ALU email; email verification is required | Triage queue ordered by severity, then waiting time |
| Report an issue: category, area and exact spot, description, severity, optional photo | Live numbers: open, critical, in progress, median time to fix |
| See similar open reports before sending, and tap **Affects me too** instead of duplicating | Move a report along the workflow, with a note the reporter reads |
| Draft autosave: an unfinished report survives leaving the screen or restarting | Re-grade severity during triage |
| Search, filter and sort the campus feed; choices persist across pages and restarts | See who filed a report (students never can) |
| Follow each report on a status rail and a timestamped timeline | Close as **Not actioned** with a reason instead of deleting |
| Edit or delete a report until staff pick it up; reopen it if the problem comes back | |

Works offline: reports written without a connection are shown as **Syncing** and sent on reconnect. Light and dark themes, phone and tablet layouts.

## Architecture

```
lib/
  main.dart, bootstrap.dart      Firebase init, offline cache, hydrated storage, DI
  app.dart                       Theme, root navigator driven by AuthBloc
  core/
    theme/                       Design tokens (docs/DESIGN.md), ThemeCubit
    utils/                       Validators, Failure (error mapping), time formatting
    widgets/                     Reusable UI: buttons, state views, responsive helpers
  features/
    auth/      data/ models/ bloc/ cubit/ view/
    incidents/ data/ models/ logic/ bloc/ cubit/ view/ view/widgets/
    shell/     Session-scoped blocs, student/staff navigation shell
    profile/
```

Three layers, one direction: **widgets → blocs/cubits → repositories → Firebase**. No widget imports a Firebase package. Pure logic (filtering, triage order, duplicate detection, stats, status workflow) lives in `features/incidents/logic/` with no Flutter or Firebase dependency.

State management is **flutter_bloc**:

- `AuthBloc` owns the session and the verified-email gate; the root navigator swaps the whole stack on every status change.
- `FeedBloc` and `MyReportsBloc` (one live Firestore stream each) are created once per session above all tabs, so one snapshot updates the feed, the tracker, the staff queue and the stats together.
- `IncidentFilterCubit`, `ReportFormCubit` (create mode) and `ThemeCubit` are `HydratedCubit`s: their state persists across pages and app restarts.
- `IncidentDetailCubit`, `StatusUpdateCubit` and `AuthFormCubit` are screen-scoped.

The full rationale, data model and diagrams are in the technical report. Product scope is in [`docs/PRD.md`](docs/PRD.md) and the design system in [`docs/DESIGN.md`](docs/DESIGN.md).

## Firestore data model

```
users/{uid}                     email, displayName, role, department?, lastReportAt?, createdAt
staffAllowlist/{email}          department                    (console-managed)
incidents/{id}                  title, description, category, severity, locationArea,
                                locationDetail, photoUrl?, photoPath?, status, statusNote?,
                                reporterId, affectedBy[], reopenCount, resolvedAt?,
                                createdAt, updatedAt
incidents/{id}/history/{eid}    type, from?, to, note?, actorRole, actorName?, createdAt   (append-only)
incidents/{id}/private/reporter uid, name, email                (staff + reporter only)
```

Storage: `incidents/{uid}/{incidentId}_{millis}.{jpg|png|webp}`

## Security

All access control is enforced in [`firestore.rules`](firestore.rules) and [`storage.rules`](storage.rules), not only in the UI:

- Every read and write requires a verified email on `@alustudent.com` / `@alueducation.com`, or an address on the staff allowlist.
- Staff powers come from the allowlist on every request; deleting an entry revokes them immediately. A user can never write their own role.
- Status changes are staff-only and must follow the workflow table; resolving or closing requires a note; the timeline entry must match the change made in the same batch.
- Reporter identity is stored in a subcollection that other students cannot read.
- One report per minute per user, enforced server-side.
- Photos: owner-only upload into their own folder, images only, under 5 MB.

These guarantees are covered by 41 emulator tests in `firebase_rules_test/`.

## Setup

### 1. Tools
- Flutter 3.47 stable or newer (`flutter upgrade`), Android Studio or Xcode with an emulator
- Node.js 18+ and the Firebase CLI: `npm install -g firebase-tools`
- FlutterFire CLI: `dart pub global activate flutterfire_cli`

### 2. Firebase project
1. Create a project in the [Firebase Console](https://console.firebase.google.com).
2. **Authentication** → Sign-in method → enable **Email/Password**.
3. **Firestore Database** → Create database (production mode).
4. **Storage** → Get started. Cloud Storage for Firebase now requires the **Blaze** (pay-as-you-go) plan; usage at this scale stays inside the no-cost tier. Choose a `us-central1`, `us-east1` or `us-west1` bucket location for the always-free quota, and set a budget alert under Billing.

### 3. Connect the app
```bash
firebase login
flutterfire configure          # pick your project; overwrites lib/firebase_options.dart
firebase use --add             # same project
firebase deploy --only firestore:rules,storage
flutter pub get
flutter run
```

### 4. Create a staff account
Staff cannot sign themselves up as staff. In the Firebase Console → Firestore, create:

```
Collection: staffAllowlist
Document ID: the staff member's email, lowercase (e.g. facilities.lead@alueducation.com)
Field: department (string) = Facilities
```

Then sign up in the app with that email. A non-ALU address (for example a contractor) is accepted only if it is on this list.

## Tests

```bash
flutter analyze                # 0 issues
flutter test                   # 54 tests: validators, contrast, workflow, query logic, persistence, blocs, widgets

cd firebase_rules_test
npm install
npm test                       # 41 tests against the Firestore + Storage emulators (needs Java 11+)
```

`test/features/incidents/status_workflow_test.dart` parses `firestore.rules` and fails if the server workflow and the app workflow ever disagree.

## Known limitations

- **Feed window.** The feed streams the 200 most recent reports and filters on the device. This needs no composite indexes and makes search instant, but older reports are reachable only through "My reports". The next step is server-side queries with composite indexes and cursor pagination.
- **No push notifications.** Updates are real time while the app is open. Sending FCM pushes needs Cloud Functions.
- **Search is substring matching** over the loaded window, not full-text search.
- **Staff administration** happens in the Firebase Console (allowlist), not in the app.
- **Offline reports** that later fail server validation (for example, the cooldown) disappear from the list when the server rejects them.

## Licence

Code: MIT. Fonts: Space Grotesk and IBM Plex, SIL Open Font License (see `assets/fonts/`).
