# Pinned rendering QA container for Tile Waifu (P96 / T13)
# Goldens MUST be captured ONLY inside this image so Mesa/LLVM/Godot/fontconfig
# versions are identical across local and CI runs.
#
# Base image pinned to official ubuntu:24.04 manifest list digest (noble-20261110.1, updated 2026-11-23).
FROM ubuntu:24.04@sha256:562111b88caa79c71391c0c4d3c2114a7d5c35915c20561fd893cb1e07929e6b

ARG APT_SNAPSHOT=20261124T000000Z
ARG GODOT_VERSION=4.5.1
ARG GODOT_SHA256="02ec53d1cc7dbb9cc6355393c61b9ab43d1244751a124f10248a4802830788cd"
ARG MESA_PKG_VERSION="25.2.8-0ubuntu0.24.04.5"
ARG LLVM_VERSION=18
ARG LLVM_PKG_VERSION="1:18.1.3-1ubuntu1"
ARG XVFB_PKG_VERSION="2:21.1.12-1ubuntu1.9"
ARG FONTCONFIG_PKG_VERSION="2.15.0-1.1ubuntu2"
ARG FONTS_DEJAVU_PKG_VERSION="2.37-8"
ARG FONTS_NOTO_PKG_VERSION="20201225-2"

LABEL org.opencontainers.image.title="tile-waifu-qa-render" \
      org.opencontainers.image.description="Pinned xvfb + Mesa llvmpipe + Godot ${GODOT_VERSION} rendering CI image for Tile Waifu (P96)" \
      tw.qa.render.profile="llvmpipe-gl33-v1" \
      tw.qa.godot.version="${GODOT_VERSION}" \
      tw.qa.apt.snapshot="${APT_SNAPSHOT}"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    # Deterministic software OpenGL 3.3 via Mesa llvmpipe (no GPU driver drift)
    LIBGL_ALWAYS_SOFTWARE=1 \
    GALLIUM_DRIVER=llvmpipe \
    LP_NUM_THREADS=1 \
    MESA_GL_VERSION_OVERRIDE=3.3 \
    MESA_GLSL_VERSION_OVERRIDE=330 \
    # Godot & QA markers
    GODOT_VERSION=${GODOT_VERSION} \
    GODOT_BIN=/usr/local/bin/godot4 \
    TW_QA_RENDER_IMAGE=1 \
    TW_QA_RENDER_PROFILE=llvmpipe-gl33-v1 \
    TW_QA_ENV_MANIFEST=/etc/tw-qa-render/env.json \
    # Expected pinned package versions enforced by tw-verify-qa-image
    TW_QA_APT_SNAPSHOT=${APT_SNAPSHOT} \
    TW_QA_PIN_MESA=${MESA_PKG_VERSION} \
    TW_QA_PIN_LLVM18=${LLVM_PKG_VERSION} \
    TW_QA_PIN_XVFB=${XVFB_PKG_VERSION} \
    TW_QA_PIN_FONTCONFIG=${FONTCONFIG_PKG_VERSION} \
    TW_QA_PIN_FONTS_DEJAVU=${FONTS_DEJAVU_PKG_VERSION} \
    TW_QA_PIN_FONTS_NOTO=${FONTS_NOTO_PKG_VERSION}

# 1. Pin apt sources to Ubuntu Snapshot Service (${APT_SNAPSHOT}) and install pinned rendering stack
RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends ca-certificates; \
    rm -f /etc/apt/sources.list /etc/apt/sources.list.d/ubuntu.sources; \
    printf '%s\n' \
      'Types: deb' \
      "URIs: https://snapshot.ubuntu.com/ubuntu/${APT_SNAPSHOT}/" \
      'Suites: noble noble-updates noble-security' \
      'Components: main restricted universe multiverse' \
      'Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg' \
      > /etc/apt/sources.list.d/ubuntu.sources; \
    apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get -o Acquire::Check-Valid-Until=false install -y --no-install-recommends \
        curl \
        unzip \
        git \
        python3 \
        python3-pip \
        python3-venv \
        xvfb=${XVFB_PKG_VERSION} \
        xauth \
        mesa-utils \
        libgl1 \
        libgl1-mesa-dri=${MESA_PKG_VERSION} \
        libglx-mesa0=${MESA_PKG_VERSION} \
        libegl1 \
        libegl-mesa0=${MESA_PKG_VERSION} \
        libgles2 \
        libllvm${LLVM_VERSION}=${LLVM_PKG_VERSION} \
        libxcursor1 \
        libxinerama1 \
        libxi6 \
        libxrandr2 \
        libxkbcommon0 \
        libasound2t64 \
        libfontconfig1 \
        fontconfig=${FONTCONFIG_PKG_VERSION} \
        fonts-dejavu-core=${FONTS_DEJAVU_PKG_VERSION} \
        fonts-noto-core=${FONTS_NOTO_PKG_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# 2. Deterministic fontconfig (no subpixel/hinting drift; game UI uses bundled fonts in game/assets/**/fonts/)
COPY fonts.conf /etc/fonts/local.conf
RUN fc-cache -f

# 3. Pinned Python QA dependencies
COPY requirements.txt /tmp/qa-requirements.txt
RUN python3 -m pip install --no-cache-dir --break-system-packages -r /tmp/qa-requirements.txt \
    && rm -f /tmp/qa-requirements.txt

# 4. Pinned Godot 4.5.1 official Linux x86_64 binary (FAIL CLOSED if GODOT_SHA256 is empty or mismatches)
RUN set -eux; \
    test -n "${GODOT_SHA256}"; \
    printf '%s\n' "${GODOT_SHA256}" | grep -Eq '^[0-9a-f]{64}$'; \
    url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"; \
    curl -fsSL -o /tmp/godot.zip "$url"; \
    echo "${GODOT_SHA256}  /tmp/godot.zip" | sha256sum -c -; \
    unzip -q -o /tmp/godot.zip -d /opt/godot; \
    chmod +x "/opt/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64"; \
    ln -sf "/opt/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot4; \
    rm -f /tmp/godot.zip

# 5. Helper runner & image verification scripts
COPY run_render_godot.sh /usr/local/bin/tw-render-godot
COPY verify_image.sh /usr/local/bin/tw-verify-qa-image
RUN chmod +x /usr/local/bin/tw-render-godot /usr/local/bin/tw-verify-qa-image

# 6. Record exact pinned versions (Mesa, LLVM, Godot, Xvfb, fontconfig, fonts, Python) in /etc/tw-qa-render/env.json
RUN mkdir -p /etc/tw-qa-render && /usr/local/bin/tw-verify-qa-image --write-manifest /etc/tw-qa-render/env.json

WORKDIR /workspace
CMD ["/usr/local/bin/tw-verify-qa-image"]
