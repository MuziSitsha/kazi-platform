# KAZI Staging Secrets Register

Use this as the working register for staging setup.

Status values:

- missing
- provided
- loaded
- validated
- redacted

## Environment Owner

- primary business email: sales@gubudo.com
- bootstrap password: redacted from source control; store in a password manager or secret vault

## Public URLs

| Item | Value | Status | Notes |
|------|-------|--------|-------|
| Staging API URL | https://api-staging.kazi.co.za | provided | Swap only if final domain naming changes |
| Staging admin URL | https://admin-staging.kazi.co.za | provided | Swap only if final domain naming changes |
| Mobile API base URL | https://api-staging.kazi.co.za/api/v1 | provided | Use for real-device staging builds |
| Peach return URL | https://api-staging.kazi.co.za/api/v1/payments/checkout/result | provided | Confirm against final Peach setup |
| Peach webhook callback URL | https://api-staging.kazi.co.za/api/v1/payments/webhooks/peach | provided | Confirm against final Peach setup |

## Backend Core

| Item | Value | Status | Notes |
|------|-------|--------|-------|
| DATABASE_URL | pending | missing | AWS staging PostgreSQL |
| JWT_SECRET | pending | missing | Generate long random secret |
| JWT_REFRESH_SECRET | pending | missing | Generate long random secret |
| REDIS_HOST | pending | missing | AWS staging Redis |
| REDIS_PORT | 6379 | missing | Confirm if custom |
| REDIS_PASSWORD | pending | missing | Load only after Redis provision |

## Firebase

| Item | Value | Status | Notes |
|------|-------|--------|-------|
| FIREBASE_PROJECT_ID | kazi-staging | provided | Preferred staging project name |
| FIREBASE_CLIENT_EMAIL | pending | missing | From service account |
| FIREBASE_PRIVATE_KEY | pending | missing | From service account |
| FIREBASE_API_KEY | pending | missing | Firebase app config |
| FIREBASE_MESSAGING_SENDER_ID | pending | missing | Firebase app config |
| FIREBASE_STORAGE_BUCKET | pending | missing | Firebase project bucket |
| FIREBASE_ANDROID_APP_ID | pending | missing | Android app registration |
| FIREBASE_IOS_APP_ID | pending | missing | iPhone app registration |
| FIREBASE_IOS_BUNDLE_ID | pending | missing | Confirm iPhone bundle id |

## Google Maps

| Item | Value | Status | Notes |
|------|-------|--------|-------|
| GOOGLE_MAPS_API_KEY | pending | missing | Required if embedded maps launch path is used |

## Clickatell

| Item | Value | Status | Notes |
|------|-------|--------|-------|
| CLICKATELL_API_KEY | pending | missing | South African OTP delivery |

## Twilio

| Item | Value | Status | Notes |
|------|-------|--------|-------|
| TWILIO_ACCOUNT_SID | pending | missing | Voice-capable account |
| TWILIO_AUTH_TOKEN | pending | missing | Secure secret |
| TWILIO_PHONE_NUMBER | pending | missing | Voice-capable number |

## Peach Payments

| Item | Value | Status | Notes |
|------|-------|--------|-------|
| PEACH_PAYMENTS_ENTITY_ID | pending | missing | Merchant credential |
| PEACH_PAYMENTS_SECRET | pending | missing | Merchant secret |
| PEACH_PAYMENTS_MODE | staging | provided | Switch to production later |

## AWS And Storage

| Item | Value | Status | Notes |
|------|-------|--------|-------|
| AWS_REGION | af-south-1 | provided | Johannesburg latency target |
| AWS_ACCESS_KEY_ID | pending | missing | Deployment access |
| AWS_SECRET_ACCESS_KEY | pending | missing | Deployment access |
| AWS_S3_BUCKET | kazi-staging-uploads | provided | Confirm actual bucket creation |
| AWS_ECR_REPOSITORY | pending | missing | Staging deployment |
| AWS_ECS_CLUSTER | pending | missing | Staging deployment |
| AWS_ECS_SERVICE | pending | missing | Staging deployment |
| AWS_ECS_TASK_DEFINITION | pending | missing | Staging deployment |
| AWS_ADMIN_S3_BUCKET | pending | missing | Admin hosting if using S3 |
| AWS_ADMIN_CLOUDFRONT_DISTRIBUTION_ID | pending | missing | Admin CDN |

## Admin Access

| Item | Value | Status | Notes |
|------|-------|--------|-------|
| Staging admin email | sales@gubudo.com | provided | Bootstrap admin |
| Staging admin password | redacted | redacted | Rotate out-of-band and do not commit passwords |
| Production admin email | sales@gubudo.com | provided | Confirm before production |
| Production admin password | pending rotation | missing | Do not reuse staging bootstrap password |

## Launch Scope Notes

Initial Johannesburg staging and launch focus:

- Rosebank
- Sandton
- Hyde Park
- Illovo
- Melrose
- Melrose Arch
- Parkhurst
- Parktown North
- Bryanston
- Morningside
- Rivonia