# AIML Golden Notebook Image

This repository builds the **golden, pinned, GPU-enabled Jupyter notebook image**
used across AIML projects.

The image is:
- CUDA **12.2** (runtime, cuDNN 8)
- Python **3.10.13** (via `uv`)
- Fully pinned ML / DL / CV stack (Torch, TensorFlow, ONNX, OpenCV, FAISS, etc.)
- JupyterLab-based, Kubeflow / JupyterHub compatible
- Debug-friendly (faulthandler + core dumps)
- Reproducible and Harbor-ready

---

## Image Repository

Images are published to:

```
lokeshkurre/notebooks
```

---

## Tagging Convention

Tags must be **explicit and immutable**.

Recommended format:

```
golden-cuda12.2-py3.10-YYYY.MM[-rN]
```

Examples:
```
golden-cuda12.2-py3.10-2024.09
golden-cuda12.2-py3.10-2024.09-r1
```

Rules:
- Do NOT use `latest`
- Do NOT retag existing images
- New build = new tag

---

## Build Requirements

- Docker Engine **24.0.x**
- NVIDIA Container Runtime
- Git access to this repository
- Network access to:
  - PyPI
  - PyTorch CUDA wheel index
  - Harbor registry

---

## Build Command (GitHub / CI)

Run from the **repository root**:

```bash
docker build \
  -f docker/Dockerfile \
  --build-arg BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --build-arg GIT_COMMIT=$(git rev-parse HEAD) \
  -t lokeshkurre/notebooks:golden-cuda12.2-py3.10-2024.09 \
  .
```

## Push to Harbor
```
docker push lokeshkurre/notebooks:golden-cuda12.2-py3.10-2024.09
```

## Runtime Validation

Run inside a notebook terminal:
```
nvidia-smi
python -c "import torch; print(torch.cuda.is_available())"
python -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
python -c "import cv2; print(cv2.__version__)"
```

On shell startup, the image also prints:
- OS version
- Python + virtualenv info
- GPU visibility
- Torch / TensorFlow / ONNX Runtime status

## Important Notes

- CUDA is pinned via base image
  - Do NOT install or upgrade CUDA via apt, conda, or pip
- All Python dependencies are pinned via constraints
- Any dependency change requires a new image tag
- This image is infrastructure, not a project sandbox


## Debugging Kernel Crashes
If a kernel crashes due to native code (CUDA / FAISS / OpenMP):

Core dumps are written to:
```
~/coredump/
```

Files are named:
```
core.<executable>.<pid>.<timestamp>
```

These are visible to users and can be:

- inspected with gdb
- deleted manually when no longer needed

## Ownership & Governance

This image is owned by the AIML Platform team.

Rules:

- Changes require review
- No ad-hoc rebuilds
- No mutable tags

If something breaks:
- Check the image tag
- Check host driver version (must be >= 525)
- Check ~/coredump

If all three look fine, it’s probably the code.
