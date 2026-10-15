# comfyui-serverless-worker

Runpod Serverless worker for Krea 2 Turbo and Kroma v0.3.1 Turbo (int8 convrot) in ComfyUI v0.39.2.

- Base: [runpod/worker-comfyui](https://github.com/runpod-workers/worker-comfyui) `5.11.0-base` (queue handler,
  job format), with ComfyUI v0.39.2, torch 2.14.1 (cu130) and [ComfyUI-DeGrid](https://github.com/lunaaispace-eng/ComfyUI-DeGrid).
- No model weights in the image: `start-worker.sh` downloads the four files in `models.json` (33 GB, Hugging Face) when a
  worker starts, then runs the base `/start.sh`. Workers on hosts that download under 4 GB in the first 60 s exit.
- Needs a host with a CUDA 13 driver (endpoint `minCudaVersion` 13.0).
- Build: push a `v*` tag; GitHub Actions publishes `ghcr.io/siejson/comfyui-serverless-worker:<tag>`.

Job input: `{"input": {"workflow": <ComfyUI API-format workflow>}}`; output images come back base64 in `output.images`.
