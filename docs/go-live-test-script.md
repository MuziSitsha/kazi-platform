# KAZI Go-Live Test Script

Run this script against staging first, then production. Do not mark launch-ready until every item below passes.

## Test Accounts

- one customer account with a South African phone number
- one provider account with approved verification status
- one admin account with dashboard access

## Customer Flow

1. Sign in with OTP.
Expected result: OTP is delivered and login completes successfully.

2. Update customer profile.
Expected result: name and contact details save correctly.

3. Browse service categories and services.
Expected result: categories and Johannesburg launch services are visible.

4. Create an instant booking.
Expected result: booking is created, appears in customer bookings, and a notification is stored.

5. Create a scheduled booking.
Expected result: scheduled time is stored and visible in the booking summary.

6. Apply a promo or referral benefit where applicable.
Expected result: discount or wallet reward is reflected correctly.

7. Open booking chat.
Expected result: customer can send and read booking messages.

8. Trigger a booking call.
Expected result: Twilio bridge works if configured, otherwise the defined fallback works.

9. Track the provider after assignment.
Expected result: provider movement updates are visible and the map or tracking action opens correctly.

10. Complete payment using each enabled method.
Expected result: booking payment status updates correctly and no duplicate settlement occurs.

11. Receive booking status notifications.
Expected result: stored notifications update and push delivery works on device if Firebase is configured.

12. Leave a review after completion.
Expected result: rating and review are saved and visible in provider review history.

## Provider Flow

1. Sign in as provider.
Expected result: provider role session loads correctly.

2. Complete onboarding profile.
Expected result: service area, experience, and profile details save correctly.

3. Upload verification documents.
Expected result: files upload successfully and document status is visible.

4. Toggle availability.
Expected result: provider availability changes without error.

5. View incoming or open jobs.
Expected result: assignable bookings appear correctly.

6. Accept a booking.
Expected result: booking moves from pending to assigned and customer is notified.

7. Update booking status through the service lifecycle.
Expected result: accepted, en route, arrived, in progress, and completed states save correctly.

8. Share live tracking during the active booking.
Expected result: provider location updates are stored and visible to the customer.

9. Use booking chat and call.
Expected result: provider can message and initiate or receive the booking call flow.

10. Confirm earnings and wallet history after completion.
Expected result: provider earnings reflect the completed booking and commission split.

## Admin Flow

1. Open admin dashboard.
Expected result: settings, metrics, and recent payments load correctly.

2. Review pending provider verification.
Expected result: uploaded documents are visible and approval or rejection works.

3. Change commission and booking settings.
Expected result: updated settings save successfully and remain persisted after refresh.

4. Inspect analytics summary.
Expected result: customer, provider, booking, payment, and ratings metrics display correctly.

5. Review recent payments.
Expected result: transaction values, payout values, and booking references are accurate.

## Failure Checks

1. Invalid OTP attempt.
Expected result: login is rejected safely.

2. Unapproved provider tries to operate as live provider.
Expected result: restricted actions remain blocked.

3. Wallet payment with insufficient balance.
Expected result: payment is rejected with a clear error.

4. Booking cancellation from each allowed role.
Expected result: cancellation state and notifications update correctly.

5. Payment callback replay or duplicate settlement attempt.
Expected result: booking and wallet records stay idempotent.

## Launch Sign-Off

Mark launch-ready only when:

- all customer tests pass
- all provider tests pass
- all admin tests pass
- all enabled payment methods pass
- push notifications pass on device
- call flow passes with the configured live path
- no blocking issues remain open