#!/bin/bash

set -e

VERSION="1.0.0"
DMG_FILE="SitReminder.dmg"
REPO="ihugang/sitreminder"

if [ ! -f "$DMG_FILE" ]; then
  echo "❌ $DMG_FILE not found."
  exit 1
fi

# Create Git tag and push (optional, can comment out if already tagged)
git tag -f "v$VERSION"
git push origin "v$VERSION"

# Create GitHub release using GitHub CLI
echo "🚀 Creating GitHub release..."
gh release create "v$VERSION" \
  "$DMG_FILE" \
  --repo "$REPO" \
  --title "SitReminder v$VERSION" \
  --notes "🎉 New release of SitReminder!

- Signed & Notarized
- Customizable reminder intervals
- Menu bar countdown and full-screen rest prompts"

echo "✅ Release v$VERSION published to GitHub!"