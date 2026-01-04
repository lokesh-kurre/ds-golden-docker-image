#!/usr/bin/env bash

echo "--------------------------------------------------"
echo "📦 Runtime Environment"
echo "--------------------------------------------------"
echo "OS        : $(lsb_release -ds 2>/dev/null || uname -a)"
echo "Python    : $(python --version 2>&1)"
echo "Venv      : /opt/venv"

if command -v nvidia-smi >/dev/null 2>&1; then
  echo "Driver    : $(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)"
  echo "GPU(s)    :"
  nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader | sed 's/^/  - /'
else
  echo "CUDA      : not visible"
fi

python - <<EOF
import torch, tensorflow as tf, onnxruntime as ort
print("Torch     :", torch.__version__, "| CUDA:", torch.cuda.is_available())
print("TF        :", tf.__version__, "| GPUs:", len(tf.config.list_physical_devices('GPU')))
print("ONNX RT   :", ort.__version__, "| providers:", ort.get_available_providers())
EOF
echo "--------------------------------------------------"

