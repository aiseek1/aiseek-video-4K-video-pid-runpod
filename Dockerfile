FROM ghcr.io/ashleykleynhans/comfyui:cu128-py312-v0.37.0

LABEL org.opencontainers.image.title="AISEEK Video PID 4K Upscaler"
LABEL org.opencontainers.image.description="One-click RunPod template for the AISEEK Video PID 4K Upscaler workflow"
LABEL org.opencontainers.image.vendor="AISEEK"
LABEL org.opencontainers.image.version="2.0.0"

USER root

ENV AISEEK_TEMPLATE_NAME="AISEEK Video PID 4K Upscaler"
ENV AISEEK_TEMPLATE_VERSION="2.0.0"

# Small utilities used by the first-boot provisioner.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       aria2 \
       ca-certificates \
       git \
       ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install required ComfyUI custom nodes into the IMAGE copy of ComfyUI.
# Ashley's RunPod startup syncs /ComfyUI to /workspace/ComfyUI on first boot.
RUN set -eux; \
    mkdir -p /ComfyUI/custom_nodes; \
    if [ ! -d /ComfyUI/custom_nodes/ComfyUI-Manager ]; then \
      git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git /ComfyUI/custom_nodes/ComfyUI-Manager; \
    fi; \
    if [ ! -d /ComfyUI/custom_nodes/ComfyUI-KJNodes ]; then \
      git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git /ComfyUI/custom_nodes/ComfyUI-KJNodes; \
    fi; \
    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git /ComfyUI/custom_nodes/ComfyUI-VideoHelperSuite; \
    git clone --depth 1 https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git /ComfyUI/custom_nodes/ComfyUI-Frame-Interpolation; \
    git clone --depth 1 https://github.com/rgthree/rgthree-comfy.git /ComfyUI/custom_nodes/rgthree-comfy; \
    git clone --depth 1 https://github.com/AlexYez/comfyui-timesaver.git /ComfyUI/custom_nodes/comfyui-timesaver

# Install node dependencies at IMAGE BUILD time into Ashley's existing ComfyUI venv.
# Do not replace Torch/CUDA: the cu128 base is specifically the RTX 5090 variant.
RUN set -eux; \
    PY=/ComfyUI/venv/bin/python; \
    "$PY" -m pip install --no-input --prefer-binary --upgrade-strategy only-if-needed \
      -r /ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt; \
    "$PY" -m pip install --no-input --prefer-binary --upgrade-strategy only-if-needed \
      -r /ComfyUI/custom_nodes/ComfyUI-KJNodes/requirements.txt; \
    "$PY" -m pip install --no-input --prefer-binary --upgrade-strategy only-if-needed \
      -r /ComfyUI/custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt; \
    "$PY" -m pip install --no-input --prefer-binary --upgrade-strategy only-if-needed \
      -r /ComfyUI/custom_nodes/ComfyUI-Frame-Interpolation/requirements-no-cupy.txt; \
    if [ -f /ComfyUI/custom_nodes/rgthree-comfy/requirements.txt ]; then \
      "$PY" -m pip install --no-input --prefer-binary --upgrade-strategy only-if-needed \
        -r /ComfyUI/custom_nodes/rgthree-comfy/requirements.txt; \
    fi; \
    if [ -f /ComfyUI/custom_nodes/comfyui-timesaver/requirements.txt ]; then \
      "$PY" -m pip install --no-input --prefer-binary --upgrade-strategy only-if-needed \
        -r /ComfyUI/custom_nodes/comfyui-timesaver/requirements.txt; \
    fi

COPY aiseek/ /opt/aiseek/
RUN chmod +x /opt/aiseek/provision.sh /opt/aiseek/start_comfyui.sh

# Ashley's image launches ComfyUI through /start_comfyui.sh after workspace sync
# and venv fixing. Wrap that exact launch point so AISEEK provisioning runs
# AFTER /workspace/ComfyUI is ready but BEFORE ComfyUI starts.
RUN mv /start_comfyui.sh /start_comfyui_base.sh \
    && cp /opt/aiseek/start_comfyui.sh /start_comfyui.sh \
    && chmod +x /start_comfyui.sh /start_comfyui_base.sh

# Keep the base image CMD (/start.sh) unchanged.
