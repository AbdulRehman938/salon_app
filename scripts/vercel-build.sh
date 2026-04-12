#!/usr/bin/env bash
set -euo pipefail

./.flutter-sdk/bin/flutter --version
./.flutter-sdk/bin/flutter config --no-analytics
./.flutter-sdk/bin/flutter pub get
./.flutter-sdk/bin/flutter build web --release \
  --dart-define=BREVO_API_KEY="$BREVO_API_KEY" \
  --dart-define=BREVO_SENDER_EMAIL="$BREVO_SENDER_EMAIL"
