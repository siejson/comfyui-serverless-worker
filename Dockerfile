# Runpod Serverless worker for our Krea 2 / Kroma int8 workflows (no models inside; start-worker.sh fetches them).
# Lean image: python slim + torch + ComfyUI as pinned for our pods (comfyui-mcp cloud/custom_nodes.json), plus the queue
# handler and start script of Runpod's official worker-comfyui (job format, base64 image output). Their published
# base image is 14.7 GB and ships ComfyUI 0.34.0, too old for Krea 2.
FROM python:3.12-slim-bookworm

ARG COMFYUI_REF=v0.39.2
ARG COMFYUI_COMMIT=3c1b7a17fdf239d35ce98cc777756f572d089795
ARG DEGRID_COMMIT=8082f8b04e0b4a79220e493d5647a0c32e1ff855
ARG WORKER_COMFYUI_REF=5.11.0
ENV PY=/opt/venv/bin/python PATH=/opt/venv/bin:$PATH PYTHONUNBUFFERED=1 PIP_NO_INPUT=1

# gcc + libc headers: Triton (int8 text encoder path) compiles a small C helper on first use.
RUN apt-get update && apt-get install -y --no-install-recommends git gcc libc6-dev libgl1 libglib2.0-0 libgoogle-perftools4 \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir uv && uv venv /opt/venv

# torch as on the pods. cu130 wheels need a CUDA 13 driver: the endpoint sets minCudaVersion 13.0.
RUN uv pip install --python $PY --no-cache torch==2.14.1 torchvision==0.29.1 --index-url https://download.pytorch.org/whl/cu130

RUN git clone -q --depth 1 --branch ${COMFYUI_REF} https://github.com/comfyanonymous/ComfyUI.git /comfyui \
    && [ "$(git -C /comfyui rev-parse HEAD)" = "${COMFYUI_COMMIT}" ] \
    && uv pip install --python $PY --no-cache -r /comfyui/requirements.txt hf_xet "runpod~=1.7.12" websocket-client requests

RUN git init -q /comfyui/custom_nodes/ComfyUI-DeGrid \
    && cd /comfyui/custom_nodes/ComfyUI-DeGrid \
    && git remote add origin https://github.com/lunaaispace-eng/ComfyUI-DeGrid.git \
    && git fetch -q --depth 1 origin ${DEGRID_COMMIT} && git checkout -q FETCH_HEAD

RUN git clone -q --depth 1 --branch ${WORKER_COMFYUI_REF} https://github.com/runpod-workers/worker-comfyui.git /tmp/w \
    && cp /tmp/w/handler.py /tmp/w/src/network_volume.py /tmp/w/src/start.sh / \
    && cp /tmp/w/src/extra_model_paths.yaml /comfyui/ && rm -rf /tmp/w

# Import every node on CPU so a broken dependency fails the build, not a live worker.
RUN cd /comfyui && timeout 300 $PY main.py --quick-test-for-ci --cpu

COPY models.json fetch_models.py start-worker.sh /
RUN chmod +x /start.sh /start-worker.sh
CMD ["/start-worker.sh"]
