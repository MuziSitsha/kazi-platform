# KAZI Secrets Remediation Runbook

This runbook covers the remaining manual work after the repository cleanup.

## Completed In Source Control

- Firebase native config files were removed from the repository.
- Firebase native config paths were added to mobile gitignore rules.
- Plain-text admin password references were removed from tracked docs.
- The API example env file now uses a placeholder instead of a real bootstrap password.

## Remaining Manual Actions

These actions require access to external consoles or local secret stores and cannot be completed from repository edits alone.

### 1. Rotate Firebase Credentials

Affected surfaces:

- Android `google-services.json`
- iOS `GoogleService-Info.plist`
- any Firebase service-account private key previously exported for backend usage

Recommended sequence:

1. Open the Firebase console for the staging project.
2. Review Project settings and confirm the Android app `za.co.kazi.mobile` and the iOS app `za.co.kazi.mobile` bundle entry.
3. Rotate or regenerate the Firebase Web API key if it was exposed.
4. If a service-account private key was ever exported, create a new private key and revoke the old one in Google Cloud IAM.
5. Download a fresh `google-services.json` for Android.
6. Download a fresh `GoogleService-Info.plist` for iOS.
7. Store both files locally only; do not commit them.
8. Update backend secret storage for any Firebase service-account values used by the API.
9. Validate push initialization on a local device or staging build.

Local file placement after rotation:

- `apps/mobile/android/app/google-services.json`
- `apps/mobile/ios/Runner/GoogleService-Info.plist`

These files are now gitignored and should remain untracked.

### 2. Rotate The Admin Bootstrap Password

The API bootstraps the admin account from environment variables. The relevant tracked reference is:

- `apps/api/.env.example`

The runtime logic that applies the configured password is in:

- `apps/api/src/modules/auth/auth.service.ts`

Behavior summary:

- admin login calls `ensureConfiguredAdminAccount()` first
- that function hashes `ADMIN_PASSWORD` from the environment and upserts the admin user record
- after the environment password is changed and the API restarts, the new configured password becomes the valid bootstrap password for that admin email

Recommended sequence:

1. Generate a new strong password in a password manager.
2. Update `ADMIN_PASSWORD` in local secret storage or deployment secrets.
3. If present, update the ignored local file `apps/api/.env.local`.
4. Update staging and production secret managers or deployment environment variables.
5. Restart the API in each environment where the password was changed.
6. Log in once using the new password to ensure the upsert path has refreshed the stored hash.
7. Remove the old password from any notes, chat logs, or shared documents.

### 3. Validate Post-Rotation

After steps 1 and 2:

1. Confirm admin login works with the new password.
2. Confirm the old password no longer works.
3. Confirm mobile builds initialize Firebase with the new native config files.
4. Confirm push registration still succeeds.

## Local Secret Follow-Up

The repository cleanup does not automatically edit ignored secret files. If `apps/api/.env.local` still contains the old admin password, update it manually before the next API run.