#!/bin/bash
set -e

CURRENT=$(grep 'VERSION' lib/sendkit/version.rb | sed 's/.*VERSION = "\(.*\)"/\1/')
MAJOR=$(echo "$CURRENT" | cut -d. -f1)
MINOR=$(echo "$CURRENT" | cut -d. -f2)
PATCH=$(echo "$CURRENT" | cut -d. -f3)
VERSION="$MAJOR.$MINOR.$((PATCH + 1))"

echo "Current version: $CURRENT"
echo "New version: $VERSION"

sed -i '' "s/VERSION = \".*\"/VERSION = \"$VERSION\"/" lib/sendkit/version.rb

git add lib/sendkit/version.rb
git commit -m "bump version to $VERSION"
git push

git tag "$VERSION"
git push origin "$VERSION"

echo "Released $VERSION successfully!"
