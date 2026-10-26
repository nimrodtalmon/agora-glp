#!/bin/bash
# AGORA, locally on a Mac or Linux: fetches the GLP repository at the pinned
# commit (once), lays this repository's files over it, and starts the server
# on http://localhost:8080.  Needs git and the Dart SDK.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
GLP="$HERE/glp"
COMMIT=71b98414ec91ad669a790284373c068086754e8d
if [ ! -d "$GLP/.git" ]; then
  git init -q "$GLP"
  git -C "$GLP" remote add origin https://github.com/EShapiro2/GLP.git
  git -C "$GLP" fetch --depth 1 origin "$COMMIT"
  git -C "$GLP" checkout -q FETCH_HEAD
fi
cp -R "$HERE/overlay/." "$GLP/"
bash "$HERE/tools/add_to_cascade.sh" "$GLP" 2>/dev/null || true
cd "$GLP/agora_server"
dart pub get
echo
echo "Starting AGORA (the first start compiles the platform; give it a minute)..."
echo "Then open http://localhost:8080"
GLP_ROOT="$GLP" PORT="${PORT:-8080}" exec dart run bin/server.dart
