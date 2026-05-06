# KAZI Handover

## Delivered State

KAZI is handing over as a working MVP codebase for three surfaces:

- Flutter customer and provider app in [apps/mobile](c:\Users\nkazi\OneDrive\Desktop\kazi\apps\mobile)
- NestJS API in [apps/api](c:\Users\nkazi\OneDrive\Desktop\kazi\apps\api)
- React admin console in [apps/admin](c:\Users\nkazi\OneDrive\Desktop\kazi\apps\admin)

The current `main` branch has passing GitHub CI and includes:

- OTP auth and role-aware access
- provider onboarding and admin verification review
- service catalogue and booking creation
- provider accept, decline, cancel, and progress lifecycle
- customer cancel and two-way reviews
- payment transaction tracking and wallet ledger bookkeeping
- hosted Peach checkout initiation for supported payment methods
- admin payout profile capture for the business banking destination
- AWS-oriented deployment workflows and supporting docs

## Access And Default Local Details

- API base URL: `http://127.0.0.1:3002/api/v1`
- API Swagger docs: `http://127.0.0.1:3002/docs`
- Admin dev server: `http://127.0.0.1:5173`
- Mobile web build has been validated locally through Flutter web build
- Admin login for current handover: `sales@gubudo.com` with password stored out-of-band only

## What Was Completed Before Handover

- customer storefront redesigned to a more premium Justlife-like experience while keeping KAZI brand colors
- Uber-style dispatch behaviors added for live service flow
- provider/customer ratings and reviews completed
- admin auth simplified from bearer-token entry to standard email/password sign-in
- CI break fixed in Flutter tests by aligning the widget test with the current UI and removing featured-card overflow
- business payout profile fields added to admin settings and persisted in API settings

## What Is Still Pending

These items are not missing because of code breakage. They are the remaining go-live integrations and operational completion steps.

1. Wire real payment settlement so hosted checkout and final payment reconciliation route into the business payout destination.
2. Load real Peach Payments merchant credentials and validate hosted checkout end to end.
3. Load real Firebase credentials and validate push notifications on devices.
4. Load real Twilio credentials and validate calling or call bridge behavior.
5. Run the production or staging migration for the new payout settings fields.
6. Complete final AWS staging and production deployment.
7. Perform real-device QA for one customer flow and one provider flow against a reachable hosted API.

## Required Post-Handover Commands

Before staging or production rollout, run:

```bash
yarn install
yarn workspace @kazi/api migration:run
yarn workspace @kazi/api build
yarn workspace @kazi/admin build
cd apps/mobile && flutter pub get
```

## Recommended Verification Before Release

These checks passed locally before handover and should be reused on staging:

```bash
yarn workspace @kazi/api test --passWithNoTests
yarn workspace @kazi/api build
yarn workspace @kazi/admin build
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
cd apps/mobile && flutter build web
```

## Handover Notes For The Client Or Ops Team

- The business banking destination can now be stored in the admin settings UI, but this is not the same as a completed live settlement integration.
- Payment gateway secrets should remain in server environment variables or AWS secrets storage, not in the admin UI.
- The platform is ready for staging and launch hardening once third-party credentials are available.
- The docs folder already contains the AWS architecture, staging secrets checklist, go-live test script, and third-party account bootstrap sequence.

## Primary Handover References

- [README.md](c:\Users\nkazi\OneDrive\Desktop\kazi\README.md)
- [docs/aws-architecture.md](c:\Users\nkazi\OneDrive\Desktop\kazi\docs\aws-architecture.md)
- [docs/staging-secrets-checklist.md](c:\Users\nkazi\OneDrive\Desktop\kazi\docs\staging-secrets-checklist.md)
- [docs/go-live-test-script.md](c:\Users\nkazi\OneDrive\Desktop\kazi\docs\go-live-test-script.md)
- [docs/third-party-account-bootstrap.md](c:\Users\nkazi\OneDrive\Desktop\kazi\docs\third-party-account-bootstrap.md)