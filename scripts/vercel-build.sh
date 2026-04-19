#!/usr/bin/env bash
set -euo pipefail

# Flutter assets include `.env` in pubspec. Vercel builds from git where
# `.env` is usually absent, so create a minimal CI-safe placeholder when needed.
if [ ! -f .env ]; then
  cat > .env <<EOF
BREVO_API_KEY=${BREVO_API_KEY:-}
BREVO_SENDER_EMAIL=${BREVO_SENDER_EMAIL:-no-reply@salonapp.local}
APPLE_SERVICE_ID=${APPLE_SERVICE_ID:-}
APPLE_REDIRECT_URI=${APPLE_REDIRECT_URI:-}
EOF
fi

./.flutter-sdk/bin/flutter --version
./.flutter-sdk/bin/flutter config --no-analytics
./.flutter-sdk/bin/flutter pub get
./.flutter-sdk/bin/flutter build web --release \
  --dart-define=BREVO_API_KEY="${BREVO_API_KEY:-}" \
  --dart-define=BREVO_SENDER_EMAIL="${BREVO_SENDER_EMAIL:-no-reply@salonapp.local}" \
  --dart-define=APPLE_SERVICE_ID="${APPLE_SERVICE_ID:-}" \
  --dart-define=APPLE_REDIRECT_URI="${APPLE_REDIRECT_URI:-}"
