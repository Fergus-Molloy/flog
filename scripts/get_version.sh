#!/usr/bin/env bash

TAGS=$(git describe --tags --abbrev=0)
VERSION=$(echo "$TAGS" | sed 's/^v\(.*\)/\1/')

if [ -z "$(git tag --points-at 'HEAD') 2>&1/dev/null" ]; then
COMMIT=$(git rev-parse --short HEAD)
    echo "$VERSION-$COMMIT"
else
    echo "$VERSION"
fi

