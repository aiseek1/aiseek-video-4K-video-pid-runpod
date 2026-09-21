# AISEEK Video PID 4K Upscaler

One-click RunPod template for AISEEK's Video PID 4K Upscaler workflow.

## Recommended GPU

RTX 5090 32 GB VRAM is recommended.

Minimum template requirement:
- 24 GB VRAM
- CUDA 12.8 compatible host

## How to use

1. Select a compatible GPU.
2. Deploy the Pod.
3. Wait for the automatic first-time setup to complete.
4. Open the ComfyUI service.
5. Load `AISEEK Video PID 4K Upscaler.json`.
6. Add your video and run the workflow.

No Jupyter, terminal commands, manual model downloads, or custom-node installation are required.

The first launch is slower because the required model files are downloaded automatically.
Future restarts are much faster because the files are stored on the persistent `/workspace` volume.

## AISEEK

YouTube: https://www.youtube.com/@aiseek1

Patreon: https://patreon.com/aiseek1
