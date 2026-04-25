#!/bin/bash

# Current date in format MM-DD-YYYY
DATE_STR=$(date +%m-%d-%Y)
TAG_PREFIX="release-$DATE_STR"

# Find newest tag of today (e.g. release-04-25-2026-06)
LAST_TAG=$(git tag -l "$TAG_PREFIX-*" | sort -V | tail -n 1)
git tag -l "$TAG_PREFIX-*"
if [ -z "$LAST_TAG" ]; then
    # First tag of today
    NEW_COUNT="01"
else
    # Extract last number and increase by one
    LAST_COUNT=$(echo "$LAST_TAG" | rev | cut -d'-' -f1 | rev)
    NEW_COUNT=$(printf "%02d" $((10#$LAST_COUNT + 1)))
fi

NEW_TAG="$TAG_PREFIX-$NEW_COUNT"

echo "Expected new tag: $NEW_TAG"

# Optional: Create and push?
read -p "Do you want to create and push the tag? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git tag "$NEW_TAG"
    git push origin "$NEW_TAG"
    echo "Tag $NEW_TAG successfully created and pushed!"
fi