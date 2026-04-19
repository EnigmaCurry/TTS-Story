ARG GPU_TYPE=cpu

# Base image selection per GPU type
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04 AS base-nvidia
FROM rocm/pytorch:rocm6.2_ubuntu22.04_py3.10_pytorch_release_2.3.0 AS base-rocm
FROM ubuntu:22.04 AS base-cpu

FROM base-${GPU_TYPE} AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv python3.11-dev python3-pip \
    espeak-ng sox libsox-dev ffmpeg rubberband-cli \
    git build-essential g++ \
    && rm -rf /var/lib/apt/lists/*

# Use python3.11 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

WORKDIR /app

# Upgrade pip and setuptools (Ubuntu 22.04 ships old versions that break sox build)
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install PyTorch (version and index URL depend on GPU type)
ARG GPU_TYPE=cpu
RUN case "${GPU_TYPE}" in \
      nvidia) pip install --no-cache-dir \
                torch==2.6.0+cu124 torchvision==0.21.0+cu124 torchaudio==2.6.0+cu124 \
                --index-url https://download.pytorch.org/whl/cu124 ;; \
      rocm)   pip install --no-cache-dir \
                torch==2.6.0+rocm6.2.4 torchvision==0.21.0+rocm6.2.4 torchaudio==2.6.0+rocm6.2.4 \
                --index-url https://download.pytorch.org/whl/rocm6.2.4 ;; \
      *)      pip install --no-cache-dir \
                torch==2.6.0+cpu torchvision==0.21.0+cpu torchaudio==2.6.0+cpu \
                --index-url https://download.pytorch.org/whl/cpu ;; \
    esac

# Install core Python dependencies (excluding engines and packages needing special handling)
COPY requirements.txt .
RUN grep -viE "^(torch|pyopenjtalk|funasr|voxcpm|qwen-tts|pocket-tts|chatterbox|#)" requirements.txt \
    | grep -v "^$" \
    > /tmp/filtered_requirements.txt \
    && pip install --no-cache-dir -r /tmp/filtered_requirements.txt \
    && rm /tmp/filtered_requirements.txt

# Install TTS engine packages separately (they have conflicting deps)
RUN pip install --no-cache-dir chatterbox-tts || \
    (pip install --no-cache-dir chatterbox-tts --no-deps || true)
RUN pip install --no-cache-dir voxcpm --no-deps || echo "WARNING: voxcpm failed"
RUN pip install --no-cache-dir qwen-tts || echo "WARNING: qwen-tts failed"
RUN pip install --no-cache-dir pocket-tts || echo "WARNING: pocket-tts failed"
RUN pip install --no-cache-dir funasr || echo "WARNING: funasr failed"

# Install pyopenjtalk (Japanese TTS support)
RUN pip install --no-cache-dir pyopenjtalk || echo "WARNING: pyopenjtalk failed"

# Install scipy and hf_xet
RUN pip install --no-cache-dir scipy
RUN pip install --no-cache-dir hf_xet || true

# Copy application code
COPY . .

# Create data directories
RUN mkdir -p data/voice_prompts data/output

EXPOSE 5000

CMD ["python", "app.py"]
