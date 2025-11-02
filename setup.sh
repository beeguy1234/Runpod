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
#uv pip install sageattention==2.2.0 --no-build-isolation

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
python main.py --listen --port 8188 &

declare -A DOWNLOADS
DOWNLOADS=(

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
 
