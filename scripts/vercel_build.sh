#!/usr/bin/env bash
# Builds the Flutter web version on Vercel (no Flutter preinstalled there).
# Vercel runs it on every push: main → clubera.vercel.app, other branches →
# a Preview link.
set -euo pipefail

FLUTTER_DIR="${HOME}/flutter"
if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "${FLUTTER_DIR}"
fi
export PATH="${FLUTTER_DIR}/bin:${PATH}"
flutter --version
flutter config --enable-web --no-analytics

# lib/core/config/app_config.dart is gitignored (API keys). The weather key
# comes from the Vercel environment variable OPENWEATHER_API_KEY; without it
# the app builds and only the weather card stays empty.
mkdir -p lib/core/config
cat > lib/core/config/app_config.dart <<EOT
class AppConfig {
  static const String openWeatherApiKey = '${OPENWEATHER_API_KEY:-}';
}
EOT

flutter pub get
flutter build web --release --no-tree-shake-icons
