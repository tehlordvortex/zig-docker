#!/bin/sh
# This file is licensed under the public domain.
set -eu

export BUILD_DIR="${BUILD_DIR:-/build}"
export BOOTSTRAP_DIR=$BUILD_DIR/zig-bootstrap
export ZIG_DIR=$BUILD_DIR/zig

export ZIG=$(which zig)
create_alias() {
  local out_file=$1
  shift

  sh -c "cat > $out_file" <<EOT
#!/bin/sh -u
$ZIG ${@} \${@}
EOT

  chmod +x $out_file
}

export CC=/usr/local/bin/clang
export CXX=/usr/local/bin/clang++
export AR=/usr/local/bin/ar
export RC=/usr/local/bin/rc
export RANLIB=/usr/local/bin/ranlib
create_alias $BUILD_DIR/clang cc -fno-sanitize=all -s -target \${TARGET} -mcpu=\${MCPU}
create_alias $BUILD_DIR/clang++ c++ -fno-sanitize=all -s -target \${TARGET} -mcpu=\${MCPU}
create_alias $AR ar
create_alias $RC rc
create_alias $RANLIB ranlib

export SCCACHE=$(which sccache)
create_sccache_alias() {
  local out_file=$1

  sh -c "cat > $out_file" <<EOT
#!/bin/sh -u
sccache $2 \${@}
EOT

  chmod +x $out_file
}
create_sccache_alias $CC $BUILD_DIR/clang
create_sccache_alias $CXX $BUILD_DIR/clang++
