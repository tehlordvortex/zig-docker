#!/bin/sh
# This file is licensed under the public domain.
set -eu

build_type=
release_safe=OFF

case $OPTIMIZE in
Debug) build_type=Debug ;;
ReleaseFast) build_type=Release ;;
ReleaseSafe)
  build_type=Release
  release_safe=ON
  ;;
ReleaseSmall) build_type=MinSizeRel ;;
*)
  >&2 echo "unrecognized optimize mode: $OPTIMIZE"
  exit 2
  ;;
esac

# Build Zig with cmake. stage2 will link to the host libs then build stage3, linking
# it to the cross-compiled libs for the target
mkdir -p "$ZIG_DIR/build"
cd "$ZIG_DIR/build"
TARGET=native MCPU=native cmake "$ZIG_DIR" \
  -DCMAKE_INSTALL_PREFIX="$ZIG_DIR/stage3" \
  -DCMAKE_PREFIX_PATH="$BOOTSTRAP_DIR/out/host" \
  -DCMAKE_BUILD_TYPE=$build_type \
  -DZIG_TARGET_TRIPLE=$TARGET \
  -DZIG_TARGET_MCPU=$MCPU \
  -DZIG_USE_LLVM_CONFIG=OFF \
  -DZIG_RELEASE_SAFE=$release_safe \
  -DZIG_EXTRA_BUILD_ARGS="--search-prefix;$BOOTSTRAP_DIR/out/$TARGET-$MCPU;-Dstatic-llvm;-Duse-zig-libcxx;$ZIG_EXTRA_BUILD_ARGS"
TARGET=native MCPU=native cmake --build . --target install
