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
  	"https://github.com/ltdrdata/ComfyUI-Manager"
  	"https://github.com/kijai/ComfyUI-KJNodes"
  	"https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
  	"https://github.com/yolain/ComfyUI-Easy-Use"
	"https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"
	"https://github.com/Fannovel16/comfyui_controlnet_aux"
	"https://github.com/cubiq/ComfyUI_IPAdapter_plus"
	"https://github.com/chrisgoringe/cg-use-everywhere"
	"https://github.com/ltdrdata/ComfyUI-Impact-Pack"
	"https://github.com/ltdrdata/ComfyUI-Impact-Subpack"
	)

 for repo in "${CUSTOM_NODES[@]}"; do
     repo_name=$(basename "$repo")
     if [ ! -d "/app/ComfyUI/custom_nodes/$repo_name" ]; then
         echo "Downloading $repo_name..."
         cd "/app/ComfyUI/custom_nodes"
         git clone "$repo"
     fi
 done

# uitzonderlijk deze node moet blijkbaar hernoemd worden :
cd /app/ComfyUI/custom_nodes
mv ComfyUI-Impact-Pack comfyui-impact-pack

cd /app/ComfyUI
pip install -U pip
pip install --no-cache -r requirements.txt
pip install --no-cache GitPython numpy pillow opencv-python  # Common dependencies
# pip install --no-cache triton onnx onnxruntime-gpu
# insightface voor ipadapter :
pip install --no-cache insightface
pip install --no-cache sageattention==1.0.6

# Install dependencies for all custom nodes
        cd "/app/ComfyUI/custom_nodes"
        for node_dir in */; do
			echo "***** STARTING INSTALL $node_dir"
            if [ -d "$node_dir" ]; then
                echo "Checking dependencies for $node_dir..."
                cd "/app/ComfyUI/custom_nodes/$node_dir"
                
                # Check for requirements.txt
                if [ -f "requirements.txt" ]; then
                    echo "Installing requirements.txt for $node_dir"
                    #grep -vE '^(torch|torchvision|torchaudio)' requirements.txt pip install --no-cache -r -
									  pip install --no-cache -r requirements.txt
                fi
                
                # Check for install.py
                if [ -f "install.py" ]; then
                    echo "Running install.py for $node_dir"
                    python install.py
                fi
                
                # Check for setup.py
                if [ -f "setup.py" ]; then
                    echo "Running setup.py for $node_dir"
                    pip install --no-cache -e .
                fi
            fi
        done


apt-get update
apt-get -y install aria2

cd /app/ComfyUI
nohup python main.py --listen --port 8188 --use-sage-attention &

curl -sL https://raw.githubusercontent.com/beeguy1234/Runpod/main/download.sh | bash
