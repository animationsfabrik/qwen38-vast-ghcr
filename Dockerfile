# CUDA 13.2 environment corresponding to the Vast.ai llama.cpp template.
# Runtime startup is overridden deliberately; no default model is downloaded.
FROM vastai/llama-cpp:b11876-mix-ec42614-cuda-13.2 AS builder
ARG LLAMA_REF=eaf9376
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake ninja-build build-essential pkg-config ca-certificates libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/llama-src
RUN git clone https://github.com/unslothai/llama.cpp.git . \
    && git checkout "$LLAMA_REF" \
    && cmake -S . -B build -G Ninja \
      -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86 \
      -DCMAKE_BUILD_TYPE=Release -DLLAMA_CURL=OFF \
    && cmake --build build -j 8 --target llama-server

# Retain matching CUDA/driver-facing environment; COPY runtime binaries and shared libs.
FROM vastai/llama-cpp:b11876-mix-ec42614-cuda-13.2
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates python3 python3-venv curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /opt/llama-src/build/bin/ /opt/qwen-llama/bin/
COPY --from=builder /opt/llama-src/build/src/ /opt/qwen-llama/lib-src/
COPY --from=builder /opt/llama-src/build/ggml/src/ /opt/qwen-llama/lib-ggml/
RUN mkdir -p /workspace/models \
    && python3 -m venv /opt/hfvenv \
    && /opt/hfvenv/bin/pip install --no-cache-dir 'huggingface_hub[cli]>=0.34,<2'
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/qwen-start /usr/local/bin/qwen-download
ENV PATH="/opt/hfvenv/bin:/opt/qwen-llama/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/qwen-llama/bin:/opt/qwen-llama/lib-src:/opt/qwen-llama/lib-ggml:${LD_LIBRARY_PATH}" \
    MODEL_DIR=/workspace/models/qwen38fn/UD-IQ4_XS \
    MODEL_ALIAS=qwen3.8-flash-next \
    HOST=0.0.0.0 PORT=8000 CONTEXT_SIZE=32768 PARALLEL=1 \
    HF_REPO=unsloth/Qwen3.8-Flash-Next-GGUF \
    HF_REVISION=main \
    HF_PATTERN='UD-IQ4_XS/*.gguf'
WORKDIR /workspace
EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/qwen-start"]
