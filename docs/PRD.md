# Sana: Product Requirements

Sana (from the Kinyarwanda *gusana*, "to repair") is a mobile app for reporting and resolving campus incidents at African Leadership University.

## 1. Problem

Campus issues (water shortages, power cuts, broken furniture, blocked drains, unsafe lighting, dead Wi-Fi) are reported today through WhatsApp groups, hallway conversations and emails to whoever a student happens to know. The result:

- Staff receive the same issue many times from many channels, with no single record.
- Students never learn whether anyone saw their report, so they stop reporting.
- Nobody can answer "what is broken right now, and for how long?"
- Safety concerns are raised in public group chats where the reporter is exposed.

## 2. Users and roles

| Role | Who | How they get the role |
|---|---|---|
| Student | Anyone with a verified `@alustudent.com` or `@alueducation.com` email | Default role at sign-up |
| Staff | Facilities, IT, Residence Life, Security staff | Their email is placed in the `staffAllowlist` collection by a campus administrator (Firebase Console). Role is checked against the allowlist on every privileged write, so removing the email revokes access immediately. |

A user can never choose their own role in the app.

## 3. Goals

1. One trusted channel: every report is a single, structured record with a reference code.
2. Visible progress: every status change is timestamped and shown to the reporter in real time.
3. Fewer duplicates: before submitting, students see similar open reports and can add "Affects me too" instead of filing again.
4. Privacy by default: other students never see who filed a report.
5. Resistant to misuse: identity is tied to a verified ALU email, reports are rate-limited server-side, and only staff can move a report through the workflow.

## 4. Functional requirements

### Authentication
- F1 Sign up with name, ALU email and password; inline validation before any network call.
- F2 Email verification is mandatory; unverified accounts cannot read or write any data (enforced in security rules, not just UI).
- F3 Sign in, sign out, password reset by email, persistent session across restarts.

### Reporting (students)
- F4 Create an incident: category, title, description, campus area, specific location, severity, optional photo (camera or gallery).
- F5 Photo is compressed on device and uploaded to Firebase Storage with a visible progress bar.
- F6 Draft autosave: a half-written report survives leaving the screen or restarting the app.
- F7 Duplicate hint: open reports in the same category and area from the last 14 days are shown before submitting.
- F8 Edit or delete own report while it is still `Submitted` (before staff have acted on it).
- F9 Reopen own report once it is `Resolved` if the problem came back (maximum two reopens).
- F10 "Affects me too" on other students' open reports.

### Browsing
- F11 Campus feed of recent reports, live-updating.
- F12 Search (title, description, location, reference code) and filter by category and status; sort by newest, most affected, or severity. Filter choices persist across pages and app restarts.
- F13 "My reports" split into Active and Closed.
- F14 Incident detail: photo (pinch to zoom), status rail, full timeline of events.

### Staff
- F15 Triage queue ordered by severity, then age, with counts per status and median time to resolve.
- F16 Update status along the allowed workflow with a note; a note is required to resolve or reject.
- F17 Re-grade severity during triage.
- F18 See the reporter's name and email (students never can).

## 5. Status workflow

```
submitted -> acknowledged | in_progress | resolved | rejected
acknowledged -> in_progress | resolved | rejected
in_progress -> resolved
resolved -> in_progress   (staff, or the reporter reopening)
rejected -> acknowledged  (staff correcting a mistake)
```

The same table is implemented in `lib/features/incidents/logic/status_workflow.dart` and in `firestore.rules`, and both are covered by tests.

## 6. Non-functional requirements

- Runs on Android (minSdk 24) and iOS emulators or devices.
- Works on weak campus Wi-Fi: fonts are bundled, Firestore offline cache is on, writes made offline are shown as "Syncing" and complete when the connection returns.
- Every list has loading, empty and error states. No blank screens.
- Responsive: phone portrait, landscape and tablet layouts (navigation rail and two-column grid at 720 px and wider).
- Light and dark theme, user choice persisted.

## 7. Out of scope (stated, not hidden)

- Push notifications (needs Cloud Functions on the Blaze plan to send them).
- In-app staff administration; the allowlist is edited in the Firebase Console.
- Full-text search across the entire history; search runs over the 200 most recent reports held on device.
