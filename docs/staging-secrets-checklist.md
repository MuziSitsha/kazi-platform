# KAZI Staging And Secrets Checklist

Use this before staging deployment and secret loading. This is the operational version of the client checklist.

## Application URLs

- `PUBLIC_API_URL`
- admin site URL
- mobile app API base URL for test devices
- Peach return URL
- Peach webhook callback URL

## Backend Core

- `DATABASE_URL`
- `JWT_SECRET`
- `JWT_REFRESH_SECRET`
- `REDIS_HOST`
- `REDIS_PORT`
- `REDIS_PASSWORD`

## South Africa Launch Integrations

- `CLICKATELL_API_KEY`
- `PEACH_PAYMENTS_ENTITY_ID`
- `PEACH_PAYMENTS_SECRET`
- `PEACH_PAYMENTS_MODE`
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_PHONE_NUMBER`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

## Storage And File Uploads

- `AWS_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_S3_BUCKET`

## Maps And Tracking

- Google Maps API key if embedded maps are required for launch
- confirmed fallback decision if open-map tracking is acceptable for MVP launch

## CI And Deployment

- `AWS_ECR_REPOSITORY`
- `AWS_ECS_CLUSTER`
- `AWS_ECS_SERVICE`
- `AWS_ECS_TASK_DEFINITION`
- `AWS_ADMIN_S3_BUCKET`
- `AWS_ADMIN_CLOUDFRONT_DISTRIBUTION_ID`
- `TEST_DATABASE_URL`

## Mobile Runtime Inputs

- `KAZI_API_BASE_URL`
- `KAZI_PAYMENT_RETURN_URL`
- Firebase Android app values
- Firebase iPhone app values

## Admin Access

- one staging admin user
- one production admin user
- bearer token or login path for dashboard validation

## Launch Decisions To Confirm

- launch service categories in Johannesburg
- payment methods enabled on day one
- default commission rate
- referral reward amount
- promo rules and expiry windows
- provider document list required for approval
- cancellation policy copy
- customer support contact details

## Sign-Off Before Staging QA

- all secrets loaded into GitHub or the deployment platform
- staging API reachable externally
- staging admin reachable externally
- one customer test device ready
- one provider test device ready
- one admin tester assigned