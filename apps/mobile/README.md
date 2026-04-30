# KAZI App

Flutter application for the KAZI customer and provider MVP on Android and iPhone.

## Scope

This app is currently focused on the launch MVP surfaces required by the brief:

- Android phones and tablets
- iPhone and iPad

The admin dashboard remains a separate web application in the monorepo.

## Local Validation

Use the selected Puro-managed Flutter SDK for local checks:

```powershell
$flutter = 'C:\Users\nkazi\.puro\envs\stable\flutter\bin\flutter.bat'
Set-Location 'c:\Users\nkazi\OneDrive\Desktop\kazi\apps\mobile'
& $flutter pub get
& $flutter analyze
& $flutter test
```

## Runtime Configuration

Use `--dart-define` values when testing against a reachable backend or when preparing Firebase push:

```powershell
$flutter = 'C:\Users\nkazi\.puro\envs\stable\flutter\bin\flutter.bat'
Set-Location 'c:\Users\nkazi\OneDrive\Desktop\kazi\apps\mobile'
& $flutter run \
	--dart-define=KAZI_API_BASE_URL=https://your-api.example.com/api/v1 \
	--dart-define=KAZI_PAYMENT_RETURN_URL=https://your-api.example.com/api/v1/payments/checkout/result \
	--dart-define=FIREBASE_API_KEY=... \
	--dart-define=FIREBASE_PROJECT_ID=... \
	--dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
	--dart-define=FIREBASE_STORAGE_BUCKET=... \
	--dart-define=FIREBASE_ANDROID_APP_ID=... \
	--dart-define=FIREBASE_IOS_APP_ID=... \
	--dart-define=FIREBASE_IOS_BUNDLE_ID=...
```

## Runtime Targets

Responsive behavior inside the app should cover:

- small Android phones
- larger Android phones
- Android tablets
- iPhone sizes
- iPad sizes

## Delivery Notes

- Customer and provider journeys share the same Flutter codebase.
- The admin dashboard remains the dedicated browser-first operations console under `apps/admin`.
- Hosted checkout opens in the external browser, then returns to the backend checkout result page unless you override it with `KAZI_PAYMENT_RETURN_URL`.
- Firebase push wiring is in place, but real device delivery still depends on valid Firebase project credentials.
