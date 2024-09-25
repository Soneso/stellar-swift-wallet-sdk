#!/bin/zsh

echo "Looking for problematic dirs..."

find ~/Library/Caches/org.swift.swiftpm/ -name remotes -type d
find ~/Library/Developer/Xcode/DerivedData/ -name remotes -type d | grep -vw checkouts

echo "Getting rid of them..."

find ~/Library/Caches/org.swift.swiftpm/ -name remotes -type d | xargs rm -r
find ~/Library/Developer/Xcode/DerivedData/ -name remotes -type d | grep -vw checkouts | xargs rm -r
