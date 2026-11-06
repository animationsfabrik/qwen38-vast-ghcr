# Qwen3.8 Flash Next – Vast.ai / llama.cpp / GHCR

Builds the special `qwen4exp` llama.cpp fork for RTX 3090 (SM 86) inside a Vast.ai CUDA 13.2 image. No model weights are embedded in the image. Uses an OpenAI-compatible llama-server on port 8000.

**Status:** scaffold, not yet CI-validated. A GitHub-hosted runner has no NVIDIA GPU, and upstream reports that its CUDA link can require NVIDIA driver injection. If GitHub Actions fails with `cuMemCreate`/`libcuda` errors, build on a GPU-equipped self-hosted runner or revise link setup; do not treat a successful `llama-server --version` as an inference test.

## Publish

1. Create an empty **public** GitHub repository (e.g. `qwen38-vast-ghcr`).
2. Upload this tree, including `.github/workflows/publish.yml`, and push to `main`.
3. GitHub → Actions → **Build and publish to GHCR** → Run workflow.
4. In GitHub → Packages, set image visibility to public if Vast should pull it anonymously.
5. Image name will be `ghcr.io/YOUR_USER/qwen38-vast-ghcr:latest` (all-lowercase repository name).

Image contains the compiled executable, **not** the 93.7 GB GGUF model.

## Vast.ai

Choose 4× RTX 3090, enough host RAM and **at least 200 GB disk** (300 GB recommended). Template/image: `ghcr.io/YOUR_USER/qwen38-vast-ghcr:latest`; environment `-p 8000:8000 -e DOWNLOAD_MODEL=1 -e CONTEXT_SIZE=32768`; set startup/entrypoint to the default image entrypoint rather than the Vast template's `entrypoint.sh`. Model download may take a while. Store models in persistent `/workspace` if available.

The startup will first download all current `UD-IQ4_XS/*.gguf` shards from `unsloth/Qwen3.8-Flash-Next-GGUF`, then invoke the custom llama-server. For completely reproducible model files, set `HF_REVISION` to a pinned Hugging Face commit SHA.

Local Docker smoke test on a GPU machine:

```bash
docker run --rm --gpus all -p 127.0.0.1:8000:8000 \
  -v "$PWD/models:/workspace/models" \
  -e DOWNLOAD_MODEL=1 ghcr.io/YOUR_USER/qwen38-vast-ghcr:latest
```

Verify:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/v1/models
```

For remote Continue, use an SSH tunnel instead of publicly exposing the unauthenticated API:

```bash
ssh -N -L 8000:127.0.0.1:8000 -p YOUR_SSH_PORT root@YOUR_VAST_IP
```

### Continue `~/.continue/config.yaml`

```yaml
name: Vast Qwen
version: 1.0.0
schema: v1
models:
  - name: Qwen3.8 Flash Next
    provider: openai
    model: qwen3.8-flash-next
    apiBase: http://localhost:8000/v1
    apiKey: unused
    roles: [chat, edit, apply]
    defaultCompletionOptions:
      contextLength: 32768
      maxTokens: 4096
```

## Caveats

- Build uses exact llama.cpp commit `eaf9376`; upstream can change or remove it.
- The `vastai/llama-cpp` base image is a third-party image and could change or become unavailable.
- GHCR CI build needs verification; special CUDA linking can fail without a GPU runtime. A self-hosted GPU runner is the fallback.
- Four GPUs / 96 GB VRAM alone are insufficient to guarantee model load: host RAM, memory mapping, and GPU splits affect success.
- First launch downloads ~93.7 GB and needs adequate bandwidth and disk. This is a runtime cost, not a GitHub Actions artifact.
- `--tensor-split 1,1,1,1` is based on the documented four-RTX-3090 profile. Start at 32K context, then tune.
# qwen38-vast-ghcr
# qwen38-vast-ghcr
