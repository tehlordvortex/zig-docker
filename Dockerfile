# This file is licensed under the public domain.

# As at time of writing, using Alpine results in a segfault when building
# stage3 /shrug
FROM --platform=${BUILDPLATFORM} debian:sid-slim AS builder

SHELL [ "/bin/bash", "-o", "pipefail", "-c" ]

RUN apt-get update \
  && apt-get install --no-install-recommends -y \
  ca-certificates curl git cmake ninja-build python3-minimal \
  && rm -rf /var/lib/apt/lists/*

ARG MISE_VERSION=""
ARG MISE_CACHE_DIR=/cache/mise
ARG MISE_SCCACHE_VERSION=0.12.0
ARG MISE_ZIG_VERSION=master
ENV PATH="$PATH:/mise/shims"
ENV MISE_DATA_DIR=/mise
ENV MISE_CONFIG_DIR=/mise
ENV MISE_INSTALL_PATH=/usr/local/bin/mise
ENV MISE_CACHE_DIR=${MISE_CACHE_DIR}
ENV MISE_VERSION=${MISE_VERSION}
RUN --mount=type=cache,target=${MISE_CACHE_DIR} \
  curl https://mise.run | sh
RUN --mount=type=cache,target=${MISE_CACHE_DIR} \
  mise use --global --pin \
  zig@${MISE_ZIG_VERSION} sccache@${MISE_SCCACHE_VERSION}


ARG BOOTSTRAP_REPO=https://codeberg.org/ziglang/zig-bootstrap.git
ARG BOOTSTRAP_COMMIT=master
RUN git clone --depth=1 --revision=${BOOTSTRAP_COMMIT} \
  ${BOOTSTRAP_REPO} /build/zig-bootstrap

ARG ZIG_REPO=https://codeberg.org/ziglang/zig.git
ARG ZIG_COMMIT=master
RUN git clone --depth=1 --revision=${ZIG_COMMIT} \
  ${ZIG_REPO} /build/zig

ARG PARALLEL=""
ARG SCCACHE_DIR=/cache/sccache
ARG ZIG_LOCAL_CACHE_DIR=/cache/zig-local
ENV ZIG_GLOBAL_CACHE_DIR=/cache/zig-global
ENV SCCACHE_DIR=${SCCACHE_DIR}
ENV ZIG_LOCAL_CACHE_DIR=${ZIG_LOCAL_CACHE_DIR}
ENV ZIG_GLOBAL_CACHE_DIR=${ZIG_GLOBAL_CACHE_DIR}
ENV CMAKE_GENERATOR=Ninja
ENV CMAKE_BUILD_PARALLEL_LEVEL=${PARALLEL}

COPY ./common.sh /build/

COPY ./build_host_deps.sh /build/
RUN --mount=type=cache,target=${SCCACHE_DIR} \
  --mount=type=cache,target=${ZIG_LOCAL_CACHE_DIR} \
  --mount=type=cache,target=${ZIG_GLOBAL_CACHE_DIR} \
  . /build/common.sh  && /build/build_host_deps.sh

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
# If not specified, will try to build for the target docker platform(s)
ARG TARGET=""
ARG MCPU=baseline
ENV TARGET=${TARGET}
ENV TARGETOS=${TARGETOS}
ENV TARGETARCH=${TARGETARCH}
ENV TARGETVARIANT=${TARGETVARIANT}
ENV MCPU=${MCPU}

COPY ./target.sh /build/

COPY ./build_cross_deps.sh /build/
RUN --mount=type=cache,target=${SCCACHE_DIR} \
  --mount=type=cache,target=${ZIG_LOCAL_CACHE_DIR} \
  --mount=type=cache,target=${ZIG_GLOBAL_CACHE_DIR} \
  . /build/common.sh && . /build/target.sh && /build/build_cross_deps.sh

ARG OPTIMIZE=ReleaseFast
# Passed to CMake, so this must use ';' instead of ' ' as seperator
ARG ZIG_EXTRA_BUILD_ARGS=""
ENV OPTIMIZE=${OPTIMIZE}
ENV ZIG_EXTRA_BUILD_ARGS=${ZIG_EXTRA_BUILD_ARGS}

COPY ./build_zig.sh /build/
RUN --mount=type=cache,target=${SCCACHE_DIR} \
  --mount=type=cache,target=${ZIG_LOCAL_CACHE_DIR} \
  --mount=type=cache,target=${ZIG_GLOBAL_CACHE_DIR} \
  . /build/common.sh && . /build/target.sh && /build/build_zig.sh

FROM scratch AS stage3
COPY --from=builder /build/zig/stage3 /
ENTRYPOINT [ "/bin/zig" ]
