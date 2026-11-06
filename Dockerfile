<<<<<<< HEAD
=======
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
      -DGGML_CUDA=ON \
      -DGGML_CUDA_NO_VMM=ON \
      -DCMAKE_CUDA_ARCHITECTURES=86 \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLAMA_CURL=OFF
    && cmake --build build -j 8 --target llama-server
>>>>>>> 3e44405 (Fix CUDA driver linking on GitHub Actions)

# syntax=docker/dockerfile:1

FROM nvidia/cuda:13.0.3-devel-ubuntu24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    cmake \
    ninja-build \
    build-essential \
    python3 \
    ca-certificates \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/llama-src

ARG LLAMA_REF=eaf9376

RUN git clone https://github.com/unslothai/llama.cpp.git .

RUN git checkout "${LLAMA_REF}"

RUN cmake -S . -B build -G Ninja \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES=86 \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_CURL=OFF

RUN cmake --build build --parallel 4 --target llama-server

RUN ./build/bin/llama-server --version

# Runtime
FROM nvidia/cuda:13.0.3-runtime-ubuntu24.04

RUN apt-get update && apt-get install -y \
    libgomp1 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/llama-src/build/bin/ /opt/llama/bin/
COPY --from=builder /opt/llama-src/build/src/ \
    /opt/llama/lib/src/
COPY --from=builder /opt/llama-src/build/ggml/src/ \
    /opt/llama/lib/ggml/

ENV LD_LIBRARY_PATH=/opt/llama/lib/src:/opt/llama/lib/ggml:/opt/llama/lib/ggml/ggml-cuda

WORKDIR /workspace

EXPOSE 8000

CMD ["/bin/bash"]
