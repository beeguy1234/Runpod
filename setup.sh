#!/bin/bash

# Controleer of de secret is meegegeven
if [ -z "$MIJN_SECRET" ]; then
  echo "Fout: De variabele MIJN_SECRET is niet ingesteld."
  exit 1
fi
echo "Het ontvangen (deels verborgen) secret begint met: ${MIJN_SECRET:0:4}..."

mkdir -p /app
cd /app
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI
python -m venv venv
source venv/bin/activate
pip install -U pip
pip install uv
uv pip install --no-cache -r requirements.txt
uv pip install --no-cache torch torchvision torchaudio
uv pip install --no-cache GitPython numpy pillow opencv-python  # Common dependencies

apt-get update
apt-get -y install aria2

python main.py --listen --port 8188 &

aria2c –c –x 16 –s 16 --header="Authorization: Bearer ${MIJN_SECRET}" https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/sd3.5_large.safetensors -d /app/ComfyUI/models/checkpoints -o sd3.5_large.safetensors
