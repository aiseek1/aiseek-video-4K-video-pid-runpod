#!/usr/bin/env bash
set -Eeuo pipefail

COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"
PYTHON="$COMFY_ROOT/venv/bin/python"

STATE_DIR="/workspace/.aiseek"
VERSION="${AISEEK_TEMPLATE_VERSION:-2.0.0}"
READY_MARKER="$STATE_DIR/video-pid-4k-${VERSION}.ready"

WORKFLOW_SOURCE="/opt/aiseek/AISEEK Video PID 4K Upscaler.json"
WORKFLOW_TARGET="$COMFY_ROOT/user/default/workflows/AISEEK Video PID 4K Upscaler.json"

PID_FILE="pid_flux1_1024_to_4096_4step_bf16.safetensors"
PID_URL="https://huggingface.co/Comfy-Org/PixelDiT/resolve/main/diffusion_models/$PID_FILE"

PID_ENCODER="gemma_2_2b_it_elm_bf16.safetensors"
PID_ENCODER_URL="https://huggingface.co/Comfy-Org/PixelDiT/resolve/main/text_encoders/$PID_ENCODER"

PID_VAE="ae.safetensors"
PID_VAE_URL="https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/$PID_VAE"

RIFE_FILE="rife47.pth"
RIFE_URL="https://huggingface.co/marduk191/rife/resolve/main/$RIFE_FILE"

log()  { echo "[AISEEK] $*"; }
warn() { echo "[AISEEK WARNING] $*" >&2; }
die()  { echo "[AISEEK ERROR] $*" >&2; exit 1; }

mkdir -p "$STATE_DIR"

if [[ -f "$READY_MARKER" ]]; then
    log "Version $VERSION is already installed. Skipping provisioning."
    exit 0
fi

[[ -f "$COMFY_ROOT/main.py" ]] || die "ComfyUI workspace is not ready: $COMFY_ROOT"
[[ -x "$PYTHON" ]] || die "ComfyUI venv was not found: $PYTHON"
[[ -f "$WORKFLOW_SOURCE" ]] || die "Baked AISEEK workflow is missing."

log "ComfyUI root: $COMFY_ROOT"
log "Python: $PYTHON"

# Fail early and clearly before downloading multi-GB models if the GPU/Torch
# combination is not actually usable.
log "Checking GPU / PyTorch compatibility..."
"$PYTHON" - <<'PY'
import sys, torch
print(f"[AISEEK] Torch: {torch.__version__}")
print(f"[AISEEK] Torch CUDA: {torch.version.cuda}")
print(f"[AISEEK] CUDA available: {torch.cuda.is_available()}")
if not torch.cuda.is_available():
    raise SystemExit("CUDA is not available in PyTorch.")
print(f"[AISEEK] GPU: {torch.cuda.get_device_name(0)}")
major, minor = torch.cuda.get_device_capability(0)
print(f"[AISEEK] Compute capability: sm_{major}{minor}")
# Force CUDA initialization now so driver/runtime failures happen before downloads.
x = torch.empty(1, device="cuda")
del x
PY

if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_NAME="$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1 | xargs || true)"
    GPU_MEM="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1 | tr -d ' ' || true)"
    DRIVER="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1 | xargs || true)"
    log "NVIDIA driver: ${DRIVER:-Unknown}"
    log "GPU: ${GPU_NAME:-Unknown}"
    if [[ -n "${GPU_MEM:-}" ]]; then
        log "VRAM: ${GPU_MEM} MiB"
        if (( GPU_MEM < 24000 )); then
            warn "Less than ~24 GB VRAM detected. This workflow is intended for 24 GB+ GPUs."
        fi
    fi
fi

command -v aria2c >/dev/null 2>&1 || die "aria2c is missing."

valid_size() {
    local file="$1"
    local min_bytes="$2"
    [[ -f "$file" ]] || return 1
    local size
    size="$(stat -c%s "$file" 2>/dev/null || echo 0)"
    (( size >= min_bytes ))
}

grab() {
    local target="$1"
    local url="$2"
    local min_bytes="$3"
    local dir name part size timestamp

    dir="$(dirname "$target")"
    name="$(basename "$target")"
    part="$target.part"

    mkdir -p "$dir"

    if valid_size "$target" "$min_bytes"; then
        log "[SKIP] $name already exists."
        return 0
    fi

    if [[ -f "$target" ]]; then
        size="$(stat -c%s "$target" 2>/dev/null || echo 0)"
        timestamp="$(date +%Y%m%d-%H%M%S)"
        warn "$name exists but is too small (${size} bytes); preserving it."
        mv "$target" "$target.invalid-$timestamp"
    fi

    log "[DOWNLOAD] $name"
    (
        cd "$dir"
        aria2c \
          --continue=true \
          --max-connection-per-server=16 \
          --split=16 \
          --min-split-size=1M \
          --file-allocation=none \
          --auto-file-renaming=false \
          --allow-overwrite=true \
          --max-tries=10 \
          --retry-wait=5 \
          --connect-timeout=30 \
          --timeout=60 \
          --summary-interval=2 \
          --console-log-level=warn \
          --out="$name.part" \
          "$url"
    )

    valid_size "$part" "$min_bytes" || die "Downloaded file failed validation: $part"
    mv -f "$part" "$target"
    rm -f "$part.aria2"
    log "[OK] $name"
}

log "Checking required custom nodes copied from the image..."
for node in \
    ComfyUI-Manager \
    ComfyUI-KJNodes \
    ComfyUI-VideoHelperSuite \
    ComfyUI-Frame-Interpolation \
    rgthree-comfy \
    comfyui-timesaver
do
    [[ -d "$COMFY_ROOT/custom_nodes/$node" ]] || die "Missing custom node after workspace sync: $node"
done

log "Downloading / validating models..."
mkdir -p \
    "$COMFY_ROOT/models/diffusion_models" \
    "$COMFY_ROOT/models/text_encoders" \
    "$COMFY_ROOT/models/vae" \
    "$COMFY_ROOT/user/default/workflows"

# Official PiD BF16 file is ~2.72 GB; use a conservative 2 GiB lower bound.
grab "$COMFY_ROOT/models/diffusion_models/$PID_FILE" "$PID_URL" $((2 * 1024 * 1024 * 1024))
grab "$COMFY_ROOT/models/text_encoders/$PID_ENCODER" "$PID_ENCODER_URL" $((3 * 1024 * 1024 * 1024))
grab "$COMFY_ROOT/models/vae/$PID_VAE" "$PID_VAE_URL" $((200 * 1024 * 1024))

RIFE_DIR="$COMFY_ROOT/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife"
mkdir -p "$RIFE_DIR"
grab "$RIFE_DIR/$RIFE_FILE" "$RIFE_URL" $((1 * 1024 * 1024))

log "Installing AISEEK workflow..."
cp -f "$WORKFLOW_SOURCE" "$WORKFLOW_TARGET"
[[ -s "$WORKFLOW_TARGET" ]] || die "Workflow installation failed."

cat > "$READY_MARKER" <<EOF
AISEEK_TEMPLATE_VERSION=$VERSION
PROVISIONED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
WORKFLOW=$WORKFLOW_TARGET
EOF

echo
echo "============================================================"
echo " AISEEK INSTALLATION COMPLETE"
echo "============================================================"
echo " Workflow: $WORKFLOW_TARGET"
echo " ComfyUI will now start automatically."
echo "============================================================"
