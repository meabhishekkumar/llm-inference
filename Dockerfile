ARG CUDA_VERSION="11.8.0"
ARG CUDNN_VERSION="8"
ARG UBUNTU_VERSION="22.04"
ARG VLLM_VERSION="v0.1.7"

# Base NVidia CUDA Ubuntu image
#FROM nvidia/cuda:$CUDA_VERSION-cudnn$CUDNN_VERSION-devel-ubuntu$UBUNTU_VERSION as builder
FROM nvidia/cuda:$CUDA_VERSION-devel-ubuntu$UBUNTU_VERSION as builder
ARG VLLM_VERSION
ENV PATH="/usr/local/cuda/bin:${PATH}"
WORKDIR /app
RUN apt update -y && \
    apt install -y python3 python3-pip git && \
    python3 -m pip install --upgrade pip && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* && \
    git clone https://github.com/vllm-project/vllm && \
    cd vllm && \
    git checkout ${VLLM_VERSION} && \
    pip wheel --no-cache-dir --no-deps --wheel-dir dist -r requirements.txt .

#FROM nvidia/cuda:$CUDA_VERSION-cudnn$CUDNN_VERSION-runtime-ubuntu$UBUNTU_VERSION
#FROM nvidia/cuda:$CUDA_VERSION-base-ubuntu$UBUNTU_VERSION
FROM ubuntu:$UBUNTU_VERSION
ENV MAX_NUM_BATCHED_TOKENS=2048
ENV DOWNLOAD_DIR=/models
ENV MODEL=lmsys/vicuna-7b-v1.5
ENV GPU_MEMORY_UTILIZATION=0.9
COPY --from=builder /app/vllm/requirements.txt /tmp/requirements.txt
COPY --from=builder /app/vllm/dist /tmp/dist  

RUN apt update -y && \
    apt install -y python3 python3-pip && \
    python3 -m pip install --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt && \
    pip install fschat==0.2.23 && \
    find /tmp/dist/*.whl | xargs pip install --no-cache-dir && \
    rm -f /tmp/requirements.txt && \
    rm -rf /tmp/dist && \
    # apt remove -y python3-pip && \
    apt autoremove -y && \
    apt clean && \
    mkdir /models

EXPOSE 8000
ENTRYPOINT [ "sh", "-c" ]
CMD [ "python3 -m vllm.entrypoints.openai.api_server --host 0.0.0.0 --port 8000 --model $MODEL --download-dir $DOWNLOAD_DIR --max-num-batched-tokens $MAX_NUM_BATCHED_TOKENS --gpu-memory-utilization $GPU_MEMORY_UTILIZATION"]