# Runpod Serverless worker for our Krea 2 / Kroma int8 workflows (no models inside; start-worker.sh fetches them).
# Base: Runpod's official ComfyUI worker (queue handler, start.sh), with ComfyUI and torch swapped for the versions our
# pods run (comfyui-mcp cloud/custom_nodes.json): the base ships ComfyUI 0.34.0, too old for Krea 2.
FROM runpod/worker-comfyui:5.11.0-base

ARG COMFYUI_REF=v0.39.2
ARG COMFYUI_COMMIT=3c1b7a17fdf239d35ce98cc777756f572d089795
ARG DEGRID_COMMIT=8082f8b04e0b4a79220e493d5647a0c32e1ff855
ENV PY=/opt/venv/bin/python

RUN git clone -q --depth 1 --branch ${COMFYUI_REF} https://github.com/comfyanonymous/ComfyUI.git /tmp/comfyui \
    && [ "$(git -C /tmp/comfyui rev-parse HEAD)" = "${COMFYUI_COMMIT}" ] \
    && cp /comfyui/extra_model_paths.yaml /tmp/comfyui/ \
    && rm -rf /comfyui && mv /tmp/comfyui /comfyui

# torch as on the pods. cu130 wheels need a CUDA 13 driver: the endpoint sets minCudaVersion 13.0.
# torchaudio 2.11 from the base would not match torch 2.14, and ComfyUI does not need it.
RUN uv pip uninstall --python $PY torchaudio \
    && uv pip install --python $PY --no-cache torch==2.14.1 torchvision==0.29.1 \
         --index-url https://download.pytorch.org/whl/cu130 \
    && uv pip install --python $PY --no-cache -r /comfyui/requirements.txt hf_xet

RUN git init -q /comfyui/custom_nodes/ComfyUI-DeGrid \
    && cd /comfyui/custom_nodes/ComfyUI-DeGrid \
    && git remote add origin https://github.com/lunaaispace-eng/ComfyUI-DeGrid.git \
    && git fetch -q --depth 1 origin ${DEGRID_COMMIT} && git checkout -q FETCH_HEAD

# Import every node on CPU so a broken dependency fails the build, not a live worker.
RUN cd /comfyui && timeout 300 $PY main.py --quick-test-for-ci --cpu

COPY models.json fetch_models.py start-worker.sh /
RUN chmod +x /start-worker.sh
CMD ["/start-worker.sh"]
