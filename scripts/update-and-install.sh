#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

echo "=== Fetching upstream ==="
git fetch upstream

# Check if there are new commits
LOCAL=$(git rev-parse HEAD)
UPSTREAM=$(git rev-parse upstream/main)
MERGE_BASE=$(git merge-base HEAD upstream/main)

if [ "$MERGE_BASE" = "$UPSTREAM" ]; then
  echo "Already up to date with upstream/main"
  exit 0
fi

echo "=== New upstream commits found, rebasing ==="
git rebase upstream/main

echo "=== Installing dependencies ==="
yarn install
yarn build:tauri:plugin:api
yarn build:core
yarn build:extensions

echo "=== Downloading binaries ==="
yarn download:bin

# Ensure placeholder resources exist
mkdir -p src-tauri/resources/bin/mlx-swift_Cmlx.bundle
touch src-tauri/resources/bin/mlx-server && chmod +x src-tauri/resources/bin/mlx-server

echo "=== Building web app ==="
yarn build:web

echo "=== Building jan-cli ==="
CLEAN_PATH="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin:$(echo $PATH | tr ':' '\n' | grep -v swiftly | grep -v 'swift-6' | tr '\n' ':')"
export PATH="$CLEAN_PATH"
export SDKROOT="$(xcrun --show-sdk-path)"
export TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault

cd src-tauri && cargo build --features cli --bin jan-cli && cd ..

echo "=== Building .app bundle ==="
yarn tauri build --debug 2>&1 || true

# Install even if DMG fails (the .app is still built)
APP_PATH="src-tauri/target/debug/bundle/macos/Jan.app"
if [ -d "$APP_PATH" ]; then
  echo "=== Installing to /Applications ==="
  rm -rf "/Applications/Jan.app"
  cp -r "$APP_PATH" /Applications/
  echo "=== Done! Jan updated and installed ==="
else
  echo "ERROR: Jan.app not found at $APP_PATH"
  exit 1
fi

echo "=== Pushing to fork ==="
git push origin main --force-with-lease
