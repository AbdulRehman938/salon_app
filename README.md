# salon_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Environment Variables

This project keeps secrets in local environment files that are ignored by git.

1. Create `.env` in the project root.
2. Create `functions/.env`.
3. Fill the values with your real keys.

Flutter now reads Brevo values from `.env` at app startup.

Note for Flutter Web: hidden `.env` assets are not loaded from `assets/.env`, so provide Brevo values via `--dart-define` when running/building on web.

For Apple web sign-in values (if needed), pass variables using `--dart-define`, for example:

```bash
flutter run -d chrome \
	--dart-define=APPLE_SERVICE_ID=your.apple.service.id \
	--dart-define=APPLE_REDIRECT_URI=https://your-app.firebaseapp.com/__/auth/handler
```