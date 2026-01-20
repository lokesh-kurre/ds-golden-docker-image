FROM --platform=linux/amd64 nvidia/cuda:12.2.2-cudnn8-devel-ubuntu22.04

LABEL org.opencontainers.image.title="AIML Golden Notebook Image"
LABEL org.opencontainers.image.description="Pinned CUDA 12.2, Python 3.10, Torch+TF, JupyterLab runtime"
LABEL org.opencontainers.image.vendor="AIML Platform"
LABEL org.opencontainers.image.cuda.version="12.2.2"
LABEL org.opencontainers.image.cudnn.version="8"
LABEL org.opencontainers.image.python.version="3.10.13"
LABEL ai.platform.type="notebook"
LABEL ai.platform.cuda="true"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV XDG_DATA_HOME=/opt/share
ENV TORCH_EXTENSIONS_DIR=/opt/torch_extensions

RUN mkdir -p /opt /opt/share /opt/torch_extensions \
    && chown -R root:0 /opt /opt/share /opt/torch_extensions \
    && chmod 2775 /opt /opt/share /opt/torch_extensions

# ---------------- OS + system deps ----------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo apt-utils ca-certificates openssl openssh-client curl wget git git-lfs vim nano tmux bash bash-completion \
    build-essential gnupg make gettext cmake ninja-build gcc g++ pkg-config locales lsb-release tzdata tini \
    telnet traceroute net-tools iputils-ping procps dnsutils lsof strace pciutils \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 libboost-all-dev libeigen3-dev autotools-dev libicu-dev libbz2-dev  \
    graphviz poppler-utils tesseract-ocr libtesseract-dev ghostscript antiword unrtf \
    libpq-dev librdkafka-dev libxml2 libxslt1.1 tree \
    fuse s3fs gdb libc6-dbg gfortran gpg jq less perl rsync sed xxd zlib1g-dev \
    zip unzip unrar tar gzip bzip2 xz-utils p7zip-full p7zip-rar binutils nodejs python3-dev \
    && rm -rf /var/lib/apt/lists/*

RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

RUN git lfs install

# ---------------- kubectl ----------------
RUN curl -L https://dl.k8s.io/release/v1.27.0/bin/linux/amd64/kubectl \
    -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

# ---------------- uv + Python ----------------
RUN curl -Ls https://astral.sh/uv/install.sh |  \
    UV_INSTALL_DIR=/usr/local/bin bash

RUN uv python install 3.10.13
RUN uv venv /opt/venv
ENV VIRTUAL_ENV=/opt/venv
ENV UV_LINK_MODE=copy
ENV PATH="/opt/venv/bin:$PATH"

# ---------------- Python deps ----------------
RUN echo opencv-python-headless==0 > /opt/venv/pinned \
    && echo opencv-contrib-python==0 >> /opt/venv/pinned \
    && echo opencv-python==0 >> /opt/venv/pinned \
    && chmod 0644 /opt/venv/pinned
ENV PIP_CONSTRAINT=/opt/venv/pinned \
    UV_CONSTRAINT=/opt/venv/pinned

COPY pip_requirements/core.txt /tmp/requirements/core.txt 
RUN uv pip install -r /tmp/requirements/core.txt \
    && cat /tmp/requirements/core.txt | tee -a /opt/venv/pinned

COPY pip_requirements/ml.txt /tmp/requirements/ml.txt
RUN uv pip install -r /tmp/requirements/ml.txt \
    && cat /tmp/requirements/ml.txt | tee -a /opt/venv/pinned

COPY pip_requirements/dl-torch.txt /tmp/requirements/dl-torch.txt
RUN uv pip install --index-url https://download.pytorch.org/whl/cu121 \
    --extra-index-url https://pypi.org/simple --index-strategy unsafe-best-match \
    -r /tmp/requirements/dl-torch.txt  \
    && cat /tmp/requirements/dl-torch.txt | tee -a /opt/venv/pinned

COPY pip_requirements/dl-tf.txt /tmp/requirements/dl-tf.txt
RUN uv pip install -r /tmp/requirements/dl-tf.txt \
    && cat /tmp/requirements/dl-tf.txt | tee -a /opt/venv/pinned

COPY pip_requirements/serving.txt /tmp/requirements/serving.txt
RUN uv pip install -r /tmp/requirements/serving.txt \
    && cat /tmp/requirements/serving.txt | tee -a /opt/venv/pinned

COPY pip_requirements/extras.txt /tmp/requirements/extras.txt
RUN uv pip install -r /tmp/requirements/extras.txt \
    && cat /tmp/requirements/extras.txt | tee -a /opt/venv/pinned

COPY pip_requirements/llm.txt /tmp/requirements/llm.txt
RUN uv pip install -r /tmp/requirements/llm.txt \
    && cat /tmp/requirements/llm.txt | tee -a /opt/venv/pinned

RUN uv pip uninstall onnxruntime-gpu && uv pip install --index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/ onnxruntime-gpu==1.18.0

COPY pip_requirements/jupyter.txt /tmp/requirements/jupyter.txt
RUN uv pip install -r /tmp/requirements/jupyter.txt  \
    && cat /tmp/requirements/jupyter.txt | tee -a /opt/venv/pinned


# ---------------- Home template & scripts ----------------
COPY scripts/tmphome /opt/tmphome
COPY scripts/env_info.sh /opt/tmphome/.env_info.sh
RUN chmod +x /opt/tmphome/.env_info.sh

COPY jupyter/jupyter_server_config.py /opt/venv/etc/jupyter/jupyter_server_config.py
COPY jupyter/jupyterlab_config.json /opt/venv/share/jupyter/lab/settings/overrides.json

# ---------------- Runtime env ----------------
ENV PYTHONUNBUFFERED=1
ENV PYTHONFAULTHANDLER=1
ENV CUDA_LAUNCH_BLOCKING=1
ENV TF_CPP_MIN_LOG_LEVEL=2
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

RUN find /opt/ -type d -exec chmod g+rws {} \;

# ---------------- Entrypoint ----------------
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER jovyan
WORKDIR /home/jovyan

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${SVC_PORT}${NB_PREFIX}api/status" || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

CMD ["jupyter", "notebook"]

ARG BUILD_DATE
ARG GIT_COMMIT

LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"

