FROM nvidia/cuda:12.2.0-cudnn8-runtime-ubuntu22.04

ARG BUILD_DATE
ARG GIT_COMMIT

LABEL org.opencontainers.image.title="AIML Golden Notebook Image"
LABEL org.opencontainers.image.description="Pinned CUDA 12.2, Python 3.10, Torch+TF, JupyterLab runtime"
LABEL org.opencontainers.image.vendor="AIML Platform"
LABEL org.opencontainers.image.cuda.version="12.2.0"
LABEL org.opencontainers.image.cudnn.version="8"
LABEL org.opencontainers.image.python.version="3.10.13"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"
LABEL ai.platform.type="notebook"
LABEL ai.platform.cuda="true"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata

# ---------------- OS + system deps ----------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo ca-certificates curl wget git git-lfs vim bash bash-completion \
    build-essential tzdata tini \
    net-tools iputils-ping dnsutils lsof strace pciutils \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    poppler-utils tesseract-ocr libtesseract-dev ghostscript antiword unrtf \
    libpq-dev librdkafka-dev libxml2 libxslt1.1 \
    fuse s3fs gdb libc6-dbg \
    && rm -rf /var/lib/apt/lists/*

RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

RUN git lfs install

# ---------------- kubectl ----------------
RUN curl -L https://dl.k8s.io/release/v1.27.0/bin/linux/amd64/kubectl \
    -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

# ---------------- uv + Python ----------------
RUN curl -Ls https://astral.sh/uv/install.sh | bash
ENV PATH="/root/.cargo/bin:${PATH}"

RUN uv python install 3.10.13
RUN uv venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# ---------------- Python deps ----------------
COPY pip_requirements/pinned /opt/venv/pinned
COPY pip_requirements /tmp/requirements

ENV PIP_CONSTRAINT=/opt/venv/pinned

RUN uv pip install --system -r /tmp/requirements/core.txt
RUN uv pip install --system -r /tmp/requirements/ml.txt
RUN uv pip install --system --index-url https://download.pytorch.org/whl/cu122 \
    -r /tmp/requirements/dl-torch.txt
RUN uv pip install --system -r /tmp/requirements/dl-tf.txt
RUN uv pip install --system -r /tmp/requirements/serving.txt
RUN uv pip install --system -r /tmp/requirements/jupyter.txt
RUN uv pip install --system -r /tmp/requirements/extras.txt

RUN jupyter nbextension enable --py widgetsnbextension --sys-prefix

# ---------------- Home template & scripts ----------------
COPY docker/tmphome /opt/tmphome
COPY docker/env_info.sh /opt/tmphome/.env_info.sh
RUN chmod +x /opt/tmphome/.env_info.sh

COPY docker/jupyter_server_config.py /etc/jupyter/jupyter_server_config.py

# ---------------- Runtime env ----------------
ENV PYTHONUNBUFFERED=1
ENV PYTHONFAULTHANDLER=1
ENV CUDA_LAUNCH_BLOCKING=1
ENV OMP_NUM_THREADS=1
ENV MKL_NUM_THREADS=1
ENV OPENBLAS_NUM_THREADS=1
ENV NUMEXPR_NUM_THREADS=1

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

ENV SHELL=/bin/bash
ENV SERVE_DIR=/home/jovyan
ENV SVC_PORT=8888
ENV NB_PREFIX=/

# ---------------- jovyan user ----------------
RUN useradd -m -u 1000 -g 0 jovyan && \
    echo "jovyan ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jovyan && \
    chmod 0440 /etc/sudoers.d/jovyan

# ---------------- Entrypoint ----------------
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER jovyan
WORKDIR /home/jovyan

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${SVC_PORT}${NB_PREFIX}api/status" || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/entrypoint.sh"]

