# Pinned rendering QA container for Tile Waifu (P96 / T13)
# Goldens MUST be captured ONLY inside this image so Mesa/LLVM/Godot/fontconfig
# versions are identical across local and CI runs.
#
# Pin base digest on first registry build, e.g.:
#   FROM ubuntu:24.04@sha256:<digest>
FROM ubuntu:24.04

ARG GODOT_VERSION=4.5.1
ARG GODOT_SHA256=""
ARG MESA_PKG_VERSION=""
ARG LLVM_VERSION=18

LABEL org.opencontainers.image.title="tile-waifu-qa-render" \
      org.opencontainers.image.description="Pinned xvfb + Mesa llvmpipe + Godot ${GODOT_VERSION} rendering CI image for Tile Waifu (P96)" \
      tw.qa.render.profile="llvmpipe-gl33-v1" \
      tw.qa.godot.version="${GODOT_VERSION}"

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
    TW_QA_ENV_MANIFEST=/etc/tw-qa-render/env.json

# 1. System packages: xvfb, Mesa llvmpipe/GL, X11, fontconfig, pinned base fonts, Python 3.12, curl/unzip
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
        git \
        python3 \
        python3-pip \
        python3-venv \
        xvfb \
        xauth \
        mesa-utils \
        libgl1 \
        libgl1-mesa-dri \
        libglx-mesa0 \
        libegl1 \
        libegl-mesa0 \
        libgles2 \
        libllvm${LLVM_VERSION} \
        libxcursor1 \
        libxinerama1 \
        libxi6 \
        libxrandr2 \
        libxkbcommon0 \
        libasound2t64 \
        libfontconfig1 \
        fontconfig \
        fonts-dejavu-core \
        fonts-noto-core \
    && rm -rf /var/lib/apt/lists/*

# 2. Deterministic fontconfig (no subpixel/hinting drift; game UI uses bundled fonts in game/assets/**/fonts/)
COPY fonts.conf /etc/fonts/local.conf
RUN fc-cache -f

# 3. Pinned Python QA dependencies
COPY requirements.txt /tmp/qa-requirements.txt
RUN python3 -m pip install --no-cache-dir --break-system-packages -r /tmp/qa-requirements.txt \
    && rm -f /tmp/qa-requirements.txt

# 4. Pinned Godot 4.5.1 official Linux x86_64 binary
RUN set -eux; \
    url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"; \
    curl -fsSL -o /tmp/godot.zip "$url"; \
    if [ -n "${GODOT_SHA256}" ]; then \
        echo "${GODOT_SHA256}  /tmp/godot.zip" | sha256sum -c -; \
    fi; \
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
