#!/bin/sh
# This file is licensed under the public domain.
set -eu

# First build the libraries for stage2 to link against, as well as native `llvm|clang-tblgen`.
llvm_targets=install
llvm_enable_projects="lld;clang"
if [ "$USE_ZIG_BUILD" != "" ]; then
  # If we're building with Zig, we only need llvm/clang-tblgen on the host side
  # so we can cross-compile LLVM for the target
  llvm_targets="llvm-tblgen clang-tblgen"
  llvm_enable_projects="clang"
fi

mkdir -p "$BOOTSTRAP_DIR/out/build-llvm-host"
# This folder must exist for the host-llvm stage, but it may not be created
# if USE_ZIG_BUILD is set
mkdir -p "$BOOTSTRAP_DIR/out/host"
cd "$BOOTSTRAP_DIR/out/build-llvm-host"
TARGET=native MCPU=native cmake "$BOOTSTRAP_DIR/llvm" \
  -DCMAKE_INSTALL_PREFIX="$BOOTSTRAP_DIR/out/host" \
  -DCMAKE_PREFIX_PATH="$BOOTSTRAP_DIR/out/host" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=$CC \
  -DCMAKE_CXX_COMPILER=$CXX \
  -DCMAKE_ASM_COMPILER=$CC \
  -DCMAKE_LINK_DEPENDS_USE_LINKER=OFF \
  -DCMAKE_RC_COMPILER=$RC \
  -DCMAKE_AR=$AR \
  -DCMAKE_RANLIB=$RANLIB \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_LIBPFM=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_OCAMLDOC=OFF \
  -DLLVM_ENABLE_PLUGINS=OFF \
  -DLLVM_ENABLE_PROJECTS=$llvm_enable_projects \
  -DLLVM_ENABLE_Z3_SOLVER=OFF \
  -DLLVM_ENABLE_ZSTD=OFF \
  -DLLVM_INCLUDE_UTILS=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_TOOL_LLVM_LTO2_BUILD=OFF \
  -DLLVM_TOOL_LLVM_LTO_BUILD=OFF \
  -DLLVM_TOOL_LTO_BUILD=OFF \
  -DLLVM_TOOL_REMARKS_SHLIB_BUILD=OFF \
  -DCLANG_BUILD_TOOLS=OFF \
  -DCLANG_INCLUDE_DOCS=OFF \
  -DCLANG_INCLUDE_TESTS=OFF \
  -DCLANG_TOOL_CLANG_IMPORT_TEST_BUILD=OFF \
  -DCLANG_TOOL_CLANG_LINKER_WRAPPER_BUILD=OFF \
  -DCLANG_TOOL_C_INDEX_TEST_BUILD=OFF \
  -DCLANG_TOOL_LIBCLANG_BUILD=OFF
TARGET=native MCPU=native cmake --build . --target $llvm_targets
