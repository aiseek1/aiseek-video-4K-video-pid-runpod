#!/usr/bin/env bash
set -Eeuo pipefail

echo "============================================="
echo " AISEEK automatic first-boot setup"
echo " Base: ComfyUI CUDA 12.8 / RTX 5090"
echo "============================================="

/opt/aiseek/provision.sh

echo "[AISEEK] Provisioning complete. Starting base ComfyUI launcher..."
exec /start_comfyui_base.sh "$@"
