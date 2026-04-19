FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

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

# Install PyTorch with CUDA 12.4
RUN pip install --no-cache-dir \
    torch==2.6.0+cu124 \
    torchvision==0.21.0+cu124 \
    torchaudio==2.6.0+cu124 \
    --index-url https://download.pytorch.org/whl/cu124

# Install sox python package first (funasr dependency, fails with numpy 2.x during setup)
RUN pip install --no-cache-dir sox || true

# Install Python dependencies (excluding torch and pyopenjtalk which needs special handling)
COPY requirements.txt .
RUN grep -viE "^(torch|pyopenjtalk|#|$)" requirements.txt \
    > /tmp/filtered_requirements.txt \
    && pip install --no-cache-dir -r /tmp/filtered_requirements.txt \
    && rm /tmp/filtered_requirements.txt

# Install pyopenjtalk (Japanese TTS support)
RUN pip install --no-cache-dir pyopenjtalk || echo "WARNING: pyopenjtalk failed"

# Install chatterbox-tts
RUN pip install --no-cache-dir chatterbox-tts || \
    (pip install --no-cache-dir chatterbox-tts --no-deps || true)

# Install scipy (needed by pocket-tts)
RUN pip install --no-cache-dir scipy

# Install hf_xet for faster HuggingFace downloads
RUN pip install --no-cache-dir hf_xet || true

# Copy application code
COPY . .

# Create data directories
RUN mkdir -p data/voice_prompts data/output

EXPOSE 5000

CMD ["python", "app.py"]
