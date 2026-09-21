# AISEEK Video PID 4K Upscaler — RunPod Template V2

This is the rebuilt AISEEK one-click RunPod image for the Video PID 4K Upscaler.

## Critical change from V1

V1 extended the wrong RunPod CUDA-13 image family and could be scheduled on RTX 5090 hosts whose driver exposed CUDA 12.8, causing a driver/runtime failure.

V2 uses the Ashley Kleynhans ComfyUI Docker family that was tested directly on the live RTX 5090 RunPod.

Base:

`ghcr.io/ashleykleynhans/comfyui:cu128-py312-v0.37.0`

Do not change this to the `cu124` variant for the public RTX 5090 template.

## Why cu128 instead of the cu124 image that was manually inspected?

The manually inspected `cu124-py312-v0.37.0` Pod successfully started, but its Torch 2.6 build printed a warning that RTX 5090 compute capability `sm_120` was not supported by that PyTorch build.

The upstream ComfyUI Docker project explicitly provides its CUDA 12.8 variant for RTX 5090. V2 therefore uses `cu128-py312-v0.37.0`.

## How V2 starts

The base image already has its own RunPod startup system.

V2 does NOT replace `/start.sh`.

Instead, during the Docker build it saves the base `/start_comfyui.sh` as:

`/start_comfyui_base.sh`

and installs a tiny AISEEK wrapper at:

`/start_comfyui.sh`

The base image performs its normal workspace sync and venv repair first. At the exact moment it is ready to launch ComfyUI, the AISEEK wrapper:

1. verifies CUDA/PyTorch/GPU compatibility,
2. checks custom nodes,
3. downloads/resumes the required large model files into `/workspace/ComfyUI`,
4. installs the workflow,
5. writes a persistent version marker,
6. launches the original base ComfyUI startup script.

This preserves the upstream RunPod services.

## Custom nodes baked into the image

- ComfyUI-Manager
- ComfyUI-KJNodes
- ComfyUI-VideoHelperSuite
- ComfyUI-Frame-Interpolation
- rgthree-comfy
- comfyui-timesaver

Their Python requirements are installed at Docker build time into the base ComfyUI venv.

## First boot downloads

- PiD 1024-to-4096 BF16 diffusion model
- Gemma 2 2B BF16 text encoder
- `ae.safetensors`
- `rife47.pth`

Downloads use aria2 with resume support.

## Workflow

`AISEEK Video PID 4K Upscaler.json`

## RunPod settings

See:

`RUNPOD_TEMPLATE_SETTINGS.txt`

Key settings:

- RTX 5090 recommended
- 24 GB minimum VRAM
- CUDA 12.8 minimum
- Container Disk 40 GB
- Volume Disk 100 GB
- `/workspace`
- ComfyUI HTTP port 3000
- Start command blank

## Build on your new GitHub account

1. Create a new PUBLIC or PRIVATE source repository.
2. Upload all files in this package to its root.
3. Make sure `.github/workflows/build-image.yml` exists.
   If browser upload skips `.github`, use `BUILD_IMAGE_YML_CREATE_MANUALLY.txt`.
4. Commit to `main`.
5. GitHub Actions builds:
   `ghcr.io/YOUR_GITHUB_USERNAME/aiseek-video-pid-4k-upscaler:v2.0.0`
6. Open the resulting GitHub Container package and set its visibility to Public.
7. Create the RunPod template using `RUNPOD_TEMPLATE_SETTINGS.txt`.
8. Test it on RTX 5090 before publishing the RunPod template publicly.

## Expected first-boot log

You should see:

`[AISEEK] Torch: ...+cu128`

`[AISEEK] Torch CUDA: 12.8`

`[AISEEK] GPU: NVIDIA GeForce RTX 5090`

and eventually:

`AISEEK INSTALLATION COMPLETE`

After that the base image starts ComfyUI automatically.
