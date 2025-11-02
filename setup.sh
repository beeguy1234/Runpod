#!/bin/bash

# Controleer of de secret is meegegeven
if [ -z "$MIJN_SECRET" ]; then
  echo "Fout: De variabele MIJN_SECRET is niet ingesteld."
  exit 1
fi
echo "Secret voor huggingface begint met: ${MIJN_SECRET:0:4}..."

mkdir -p /app
cd /app
git clone https://github.com/comfyanonymous/ComfyUI.git

# Install additional custom nodes
 CUSTOM_NODES=(
  "https://github.com/ltdrdata/ComfyUI-Manager.git"
  "https://github.com/kijai/ComfyUI-KJNodes"
  "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
  "https://github.com/yolain/ComfyUI-Easy-Use"
	"https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"
	"https://github.com/Fannovel16/comfyui_controlnet_aux"
  )
  CUSTOM_NODES=()

 for repo in "${CUSTOM_NODES[@]}"; do
     repo_name=$(basename "$repo")
     if [ ! -d "/app/ComfyUI/custom_nodes/$repo_name" ]; then
         echo "Downloading $repo_name..."
         cd "/app/ComfyUI/custom_nodes"
         git clone "$repo"
     fi
 done



cd /app/ComfyUI
python -m venv venv
source venv/bin/activate
pip install -U pip
pip install uv
uv pip install --no-cache -r requirements.txt
uv pip install --no-cache torch torchvision torchaudio
uv pip install --no-cache GitPython numpy pillow opencv-python  # Common dependencies
uv pip install sageattention==2.2.0 --no-build-isolation

# Install dependencies for all custom nodes
        cd "/app/ComfyUI/custom_nodes"
        for node_dir in */; do
            if [ -d "$node_dir" ]; then
                echo "Checking dependencies for $node_dir..."
                cd "app/ComfyUI/custom_nodes/$node_dir"
                
                # Check for requirements.txt
                if [ -f "requirements.txt" ]; then
                    echo "Installing requirements.txt for $node_dir"
                    uv pip install --no-cache -r requirements.txt
                fi
                
                # Check for install.py
                if [ -f "install.py" ]; then
                    echo "Running install.py for $node_dir"
                    python install.py
                fi
                
                # Check for setup.py
                if [ -f "setup.py" ]; then
                    echo "Running setup.py for $node_dir"
                    uv pip install --no-cache -e .
                fi
            fi
        done


apt-get update
apt-get -y install aria2

cd /app/ComfyUI
python main.py --listen --port 8188  --use-sage-attention &

declare -A DOWNLOADS
DOWNLOADS=(
    ["https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"]="text_encoders"
	["https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_animate_14B_relight_lora_bf16.safetensors"]="loras"
	["https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors"]="loras"
	["https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors"]="loras"
	["https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"]="loras"
	["https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"]="vae"
	["https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors"]="vae"
	["https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/vae/diffusion_pytorch_model.safetensors"]="vae"
	["https://huggingface.co/dtarnow/UPscaler/resolve/main/RealESRGAN_x2plus.pth"]="upscale_models"
	["https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp16.safetensors"]="text_encoders"
	["https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/sd3.5_large.safetensors"]="checkpoints"
 )

i=0
total_downloads=${#DOWNLOADS[@]}
for url in "${!DOWNLOADS[@]}"; do
    ((i++))
    dest_dir="/app/ComfyUI/models/${DOWNLOADS[$url]}"
    filename=$(basename "$url")
    mkdir -p "$dest_dir"
    aria2c -c -x 16 -s 16 --header "Authorization: Bearer ${MIJN_SECRET}" $url -d $dest_dir -o $filename
    # Controleer de exit-status van het commando
    if [ $? -eq 0 ]; then
        echo "Download van $filename voltooid."
    else
        echo "Waarschuwing: Download van $filename is mislukt."
    fi
done
 
