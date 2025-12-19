#!/bin/sh
# This file is licensed under the public domain.
set -eu

TARGET=${TARGET:-}
if [ "$TARGET" = "" ]; then
  # Try to map from docker platform to target, this wont work in many cases
  os=$TARGETOS
  arch=$TARGETARCH
  cabi=musl

  if [ "$os" = "darwin" ]; then
    os=macos
    cabi=none
  elif [ "$os" = "windows" ]; then
    cabi=gnu
  fi

  if [ "$arch" = "arm" ]; then
    if [ "$TARGETVARIANT" = "v7" ]; then
      cabi=musleabihf
    else
      cabi=musleabi
    fi
  elif [ "$arch" = "arm64" ]; then
    arch=aarch64
  elif [ "$arch" = "amd64" ]; then
    arch=x86_64
  fi

  TARGET="$arch-$os-$cabi"
fi
export TARGET

TARGET_OS_AND_ABI=${TARGET#*-} # Example: linux-gnu

# Here we map the OS from the target triple to the value that CMake expects.
TARGET_OS_CMAKE=${TARGET_OS_AND_ABI%-*} # Example: linux
case $TARGET_OS_CMAKE in
macos*) TARGET_OS_CMAKE="Darwin" ;;
freebsd*) TARGET_OS_CMAKE="FreeBSD" ;;
netbsd*) TARGET_OS_CMAKE="NetBSD" ;;
openbsd*) TARGET_OS_CMAKE="OpenBSD" ;;
windows*) TARGET_OS_CMAKE="Windows" ;;
linux*) TARGET_OS_CMAKE="Linux" ;;
native) TARGET_OS_CMAKE="" ;;
esac
export TARGET_OS_CMAKE
