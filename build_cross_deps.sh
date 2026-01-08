#!/bin/sh
# This file is licensed under the public domain.
set -eu

# Cross compile zlib for the target, as we need the LLVM linked into
# the final zig binary to have zlib support enabled.
# cmake will fail to find zlib if the path doesn't include the target, /shrug
mkdir -p "$BOOTSTRAP_DIR/out/build-zlib-$TARGET-$MCPU"
cd "$BOOTSTRAP_DIR/out/build-zlib-$TARGET-$MCPU"
cmake "$BOOTSTRAP_DIR/zlib" \
  -DCMAKE_INSTALL_PREFIX="$BOOTSTRAP_DIR/out/$TARGET-$MCPU" \
  -DCMAKE_PREFIX_PATH="$BOOTSTRAP_DIR/out/$TARGET-$MCPU" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CROSSCOMPILING=True \
  -DCMAKE_SYSTEM_NAME="$TARGET_OS_CMAKE" \
  -DCMAKE_C_COMPILER=$CC \
  -DCMAKE_CXX_COMPILER=$CXX \
  -DCMAKE_ASM_COMPILER=$CC \
  -DCMAKE_LINK_DEPENDS_USE_LINKER=OFF \
  -DCMAKE_RC_COMPILER=$RC \
  -DCMAKE_AR=$AR \
  -DCMAKE_RANLIB=$RANLIB
cmake --build . --target install

# Same deal for zstd.
# The build system for zstd is whack so I just put all the files here.
mkdir -p "$BOOTSTRAP_DIR/out/$TARGET-$MCPU/lib"
cp "$BOOTSTRAP_DIR/zstd/lib/zstd.h" "$BOOTSTRAP_DIR/out/$TARGET-$MCPU/include/zstd.h"
cd "$BOOTSTRAP_DIR/out/$TARGET-$MCPU/lib"
$ZIG build-lib \
  --name zstd \
  -target $TARGET \
  -mcpu=$MCPU \
  -fstrip -OReleaseFast \
  -lc \
  "$BOOTSTRAP_DIR/zstd/lib/decompress/zstd_ddict.c" \
  "$BOOTSTRAP_DIR/zstd/lib/decompress/zstd_decompress.c" \
  "$BOOTSTRAP_DIR/zstd/lib/decompress/huf_decompress.c" \
  "$BOOTSTRAP_DIR/zstd/lib/decompress/huf_decompress_amd64.S" \
  "$BOOTSTRAP_DIR/zstd/lib/decompress/zstd_decompress_block.c" \
  "$BOOTSTRAP_DIR/zstd/lib/compress/zstdmt_compress.c" \
  "$BOOTSTRAP_DIR/zstd/lib/compress/zstd_opt.c" \
  "$BOOTSTRAP_DIR/zstd/lib/compress/hist.c" \
  "$BOOTSTRAP_DIR/zstd/lib/compress/zstd_ldm.c" \
  "$BOOTSTRAP_DIR/zstd/lib/compress/zstd_fast.c" \
  "$BOOTSTRAP_DIR/zstd/lib/compress/zstd_compress_literals.c" \
  "$BOOTSTRAP_DIR/zstd/lib/compress/zstd_double_fast.c" \
  "$BOOTSTRAP_DIR/zstd/lib/compress/huf_compress.c" \
  "$BOOTSTRAP_DIR/zstd/lib/compress/fse_compress.c" \
  "$BOOTSTRAP_DIR/zstd/lib/compress/zstd_lazy.c" \
  "$BOOTSTRAP_DIR/zstd/lib/compress/zstd_compress.c" \
  "$BOOTSTRAP_DIR/zstd/lib/compress/zstd_compress_sequences.c" \
  "$BOOTSTRAP_DIR/zstd/lib/compress/zstd_compress_superblock.c" \
  "$BOOTSTRAP_DIR/zstd/lib/deprecated/zbuff_compress.c" \
  "$BOOTSTRAP_DIR/zstd/lib/deprecated/zbuff_decompress.c" \
  "$BOOTSTRAP_DIR/zstd/lib/deprecated/zbuff_common.c" \
  "$BOOTSTRAP_DIR/zstd/lib/common/entropy_common.c" \
  "$BOOTSTRAP_DIR/zstd/lib/common/pool.c" \
  "$BOOTSTRAP_DIR/zstd/lib/common/threading.c" \
  "$BOOTSTRAP_DIR/zstd/lib/common/zstd_common.c" \
  "$BOOTSTRAP_DIR/zstd/lib/common/xxhash.c" \
  "$BOOTSTRAP_DIR/zstd/lib/common/debug.c" \
  "$BOOTSTRAP_DIR/zstd/lib/common/fse_decompress.c" \
  "$BOOTSTRAP_DIR/zstd/lib/common/error_private.c" \
  "$BOOTSTRAP_DIR/zstd/lib/dictBuilder/zdict.c" \
  "$BOOTSTRAP_DIR/zstd/lib/dictBuilder/divsufsort.c" \
  "$BOOTSTRAP_DIR/zstd/lib/dictBuilder/fastcover.c" \
  "$BOOTSTRAP_DIR/zstd/lib/dictBuilder/cover.c"

# Cross-compile LLVM with Zig.
mkdir -p "$BOOTSTRAP_DIR/out/build-llvm-$TARGET-$MCPU"
cd "$BOOTSTRAP_DIR/out/build-llvm-$TARGET-$MCPU"
cmake "$BOOTSTRAP_DIR/llvm" \
  -DCMAKE_INSTALL_PREFIX="$BOOTSTRAP_DIR/out/$TARGET-$MCPU" \
  -DCMAKE_PREFIX_PATH="$BOOTSTRAP_DIR/out/$TARGET-$MCPU" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CROSSCOMPILING=True \
  -DCMAKE_SYSTEM_NAME="$TARGET_OS_CMAKE" \
  -DCMAKE_C_COMPILER=$CC \
  -DCMAKE_CXX_COMPILER=$CXX \
  -DCMAKE_ASM_COMPILER=$CC \
  -DCMAKE_LINK_DEPENDS_USE_LINKER=OFF \
  -DCMAKE_RC_COMPILER=$RC \
  -DCMAKE_AR=$AR \
  -DCMAKE_RANLIB=$RANLIB \
  -DLLVM_ENABLE_BACKTRACES=OFF \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_ENABLE_CRASH_OVERRIDES=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_LIBPFM=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_OCAMLDOC=OFF \
  -DLLVM_ENABLE_PLUGINS=OFF \
  -DLLVM_ENABLE_PROJECTS="lld;clang" \
  -DLLVM_ENABLE_Z3_SOLVER=OFF \
  -DLLVM_ENABLE_ZLIB=FORCE_ON \
  -DLLVM_ENABLE_ZSTD=FORCE_ON \
  -DLLVM_USE_STATIC_ZSTD=ON \
  -DLLVM_BUILD_UTILS=OFF \
  -DLLVM_BUILD_TOOLS=OFF \
  -DLLVM_BUILD_STATIC=ON \
  -DLLVM_INCLUDE_UTILS=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_DEFAULT_TARGET_TRIPLE="$TARGET" \
  -DLLVM_TOOL_LLVM_LTO2_BUILD=OFF \
  -DLLVM_TOOL_LLVM_LTO_BUILD=OFF \
  -DLLVM_TOOL_LTO_BUILD=OFF \
  -DLLVM_TOOL_REMARKS_SHLIB_BUILD=OFF \
  -DLLVM_TABLEGEN="$BOOTSTRAP_DIR/out/build-llvm-host/bin/llvm-tblgen" \
  -DCLANG_BUILD_TOOLS=OFF \
  -DCLANG_INCLUDE_DOCS=OFF \
  -DCLANG_INCLUDE_TESTS=OFF \
  -DCLANG_ENABLE_OBJC_REWRITER=ON \
  -DCLANG_TOOL_CLANG_IMPORT_TEST_BUILD=OFF \
  -DCLANG_TOOL_CLANG_LINKER_WRAPPER_BUILD=OFF \
  -DCLANG_TOOL_C_INDEX_TEST_BUILD=OFF \
  -DCLANG_TOOL_LIBCLANG_BUILD=OFF \
  -DCLANG_TABLEGEN="$BOOTSTRAP_DIR/out/build-llvm-host/bin/clang-tblgen" \
  -DLLD_BUILD_TOOLS=OFF
cmake --build . --target install

mv $BOOTSTRAP_DIR/out/$TARGET-$MCPU $BOOTSTRAP_DIR/out/target
