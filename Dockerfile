# This file is licensed under the public domain.

FROM --platform=${BUILDPLATFORM} alpine:edge AS llvm-builder

RUN apk add --no-cache \
  bash ca-certificates curl git cmake ninja python3 openssh-client

SHELL [ "/bin/bash", "-o", "pipefail", "-c" ]

ARG MISE_VERSION=""
ARG MISE_CACHE_DIR=/cache/mise
ENV PATH="$PATH:/mise/shims"
ENV MISE_DATA_DIR=/mise
ENV MISE_CONFIG_DIR=/mise
ENV MISE_INSTALL_PATH=/usr/local/bin/mise
ENV MISE_CACHE_DIR=${MISE_CACHE_DIR}
ENV MISE_VERSION=${MISE_VERSION}
RUN --mount=type=cache,target=${MISE_CACHE_DIR} \
  curl https://mise.run | sh

ARG MISE_SCCACHE_VERSION=0.12.0
ARG MISE_ZIG_VERSION=master
RUN --mount=type=cache,target=${MISE_CACHE_DIR} \
  mise use --global --pin \
  zig@${MISE_ZIG_VERSION} sccache@${MISE_SCCACHE_VERSION}


ARG SSH_KEYSCAN_HOSTS=
RUN mkdir -p -m 0700 /root/.ssh \
  && if [ x${SSH_KEYSCAN_HOSTS} != x ]; then \
  ssh-keyscan ${SSH_KEYSCAN_HOSTS} >> /root/.ssh/known_hosts; fi

ARG BOOTSTRAP_REPO=https://codeberg.org/ziglang/zig-bootstrap.git
ARG BOOTSTRAP_COMMIT=master
RUN --mount=type=ssh git clone --depth=1 --revision=${BOOTSTRAP_COMMIT} \
  ${BOOTSTRAP_REPO} /build/zig-bootstrap

ARG PARALLEL=""
ARG SCCACHE_DIR=/cache/sccache
ARG ZIG_LOCAL_CACHE_DIR=/cache/zig-local
ARG ZIG_GLOBAL_CACHE_DIR=/cache/zig-global
# Set to a non-empty value if the Zig version downloaded with Mise can compile the given Zig commit
ARG USE_ZIG_BUILD=""
ENV SCCACHE_DIR=${SCCACHE_DIR}
ENV ZIG_LOCAL_CACHE_DIR=${ZIG_LOCAL_CACHE_DIR}
ENV ZIG_GLOBAL_CACHE_DIR=${ZIG_GLOBAL_CACHE_DIR}
ENV CMAKE_GENERATOR=Ninja
ENV CMAKE_BUILD_PARALLEL_LEVEL=${PARALLEL}
ENV USE_ZIG_BUILD=${USE_ZIG_BUILD}

COPY ./common.sh /build/

COPY ./build_host_deps.sh /build/
RUN --mount=type=cache,target=${SCCACHE_DIR} \
  --mount=type=cache,target=${ZIG_LOCAL_CACHE_DIR} \
  --mount=type=cache,target=${ZIG_GLOBAL_CACHE_DIR} \
  . /build/common.sh && /build/build_host_deps.sh

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


FROM --platform=${BUILDPLATFORM} scratch AS host-llvm
COPY --from=llvm-builder /build/zig-bootstrap/out/host /

FROM scratch AS target-llvm
COPY --from=llvm-builder /build/zig-bootstrap/out/target /

FROM --platform=${BUILDPLATFORM} alpine:edge AS zig-builder

RUN apk add --no-cache \
  bash ca-certificates curl git cmake ninja python3 openssh-client

SHELL [ "/bin/bash", "-o", "pipefail", "-c" ]

ARG ZIG_REPO=https://codeberg.org/ziglang/zig.git
ARG ZIG_COMMIT=master
COPY --from=llvm-builder /root/.ssh /root/.ssh
# --revision breaks the version resolution logic
RUN --mount=type=ssh git clone ${ZIG_REPO} /build/zig \
  && cd /build/zig && git checkout ${ZIG_COMMIT}

ARG PARALLEL=""
ARG SCCACHE_DIR=/cache/sccache
ARG ZIG_LOCAL_CACHE_DIR=/cache/zig-local
ARG ZIG_GLOBAL_CACHE_DIR=/cache/zig-global
ENV SCCACHE_DIR=${SCCACHE_DIR}
ENV ZIG_LOCAL_CACHE_DIR=${ZIG_LOCAL_CACHE_DIR}
ENV ZIG_GLOBAL_CACHE_DIR=${ZIG_GLOBAL_CACHE_DIR}
ENV CMAKE_GENERATOR=Ninja
ENV CMAKE_BUILD_PARALLEL_LEVEL=${PARALLEL}

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
# If not specified, will try to build for the target docker platform(s)
ARG TARGET=""
ARG MCPU=baseline
ARG OPTIMIZE=ReleaseFast
# Unless USE_ZIG_BUILD is set, this is passed to CMake, and must use ';' instead of ' ' as seperator
ARG ZIG_EXTRA_BUILD_ARGS=""
# Set to a non-empty value if the Zig version downloaded with Mise can compile the given Zig commit
ARG USE_ZIG_BUILD=""
ENV TARGET=${TARGET}
ENV TARGETOS=${TARGETOS}
ENV TARGETARCH=${TARGETARCH}
ENV TARGETVARIANT=${TARGETVARIANT}
ENV MCPU=${MCPU}
ENV OPTIMIZE=${OPTIMIZE}
ENV ZIG_EXTRA_BUILD_ARGS=${ZIG_EXTRA_BUILD_ARGS}
ENV USE_ZIG_BUILD=${USE_ZIG_BUILD}

COPY --from=llvm-builder /mise /mise
COPY --from=llvm-builder /usr/local/bin/mise /usr/local/bin/mise
COPY --from=host-llvm / /build/llvm/host
COPY --from=target-llvm / /build/llvm/target
ENV MISE_DATA_DIR=/mise
ENV MISE_CONFIG_DIR=/mise
ENV PATH="$PATH:/mise/shims"

COPY ./common.sh /build/
COPY ./target.sh /build/
COPY ./build_zig.sh /build/

RUN --mount=type=cache,target=${SCCACHE_DIR} \
  --mount=type=cache,target=${ZIG_LOCAL_CACHE_DIR} \
  --mount=type=cache,target=${ZIG_GLOBAL_CACHE_DIR} \
  . /build/common.sh && . /build/target.sh && /build/build_zig.sh

FROM scratch AS stage3
COPY --from=zig-builder /build/zig/stage3 /
ENTRYPOINT [ "/bin/zig" ]
