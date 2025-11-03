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



cd /app/ComfyUI
python -m venv venv
source venv/bin/activate
pip install -U pip
pip install uv

echo "Installing ComfyUI main requirements (filtering torch)..."
# Filter torch, torchvision, en torchaudio uit de main requirements
grep -vE '^(torch|torchvision|torchaudio)' requirements.txt | uv pip install --no-cache -r -

echo "Installing common dependencies..."
uv pip install --no-cache GitPython numpy pillow opencv-python  # Common dependencies
uv pip install --no-cache triton onnx onnxruntime-gpu
# insightface voor ipadapter :
uv pip install --no-cache insightface
uv pip install --no-cache sageattention==1.0.6

# Install dependencies for all custom nodes
echo "Installing dependencies for custom nodes..."
cd "/app/ComfyUI/custom_nodes"
for node_dir in */; do
    if [ -d "$node_dir" ]; then
        echo "Checking dependencies for $node_dir..."
        cd "/app/ComfyUI/custom_nodes/$node_dir"
        
        # Check for requirements.txt
        if [ -f "requirements.txt" ]; then
            echo "Installing requirements.txt for $node_dir (filtering torch)..."
            # Filter torch, torchvision, en torchaudio om conflicten te vermijden
            grep -vE '^(torch|torchvision|torchaudio)' requirements.txt | uv pip install --no-cache -r -
        fi
        
        # Check for install.py
        if [ -f "install.py" ]; then
            echo "Running install.py for $node_dir"
            # WAARSCHUWING: install.py kan nog steeds 'pip install torch' draaien.
            # Als de problemen aanhouden, moet dit bestand handmatig worden gecontroleerd.
            python install.py
        fi
        
        # Check for setup.py
        if [ -f "setup.py" ]; then
            echo "Running setup.py for $node_dir (installing with --no-deps)..."
            # Installeer in editable mode, maar negeer dependencies.
            # We gaan ervan uit dat de (gefilterde) requirements.txt dit al heeft afgehandeld.
            uv pip install --no-cache --no-deps -e .
        fi
    fi
done


apt-get update
apt-get -y install aria2

cd /app/ComfyUI

# --- START VEILIGHEIDSCONTROLE (FAIL FAST) ---
echo "Checking CUDA availability before starting ComfyUI..."
# Probeer te valideren dat PyTorch de GPU kan zien
CUDA_CHECK=$(python -c "import torch; print(torch.cuda.is_available())" 2>/dev/null)

if [ "$CUDA_CHECK" != "True" ]; then
    echo "------------------------------------------------------"
    echo "FATAL ERROR: PyTorch cannot detect CUDA (torch.cuda.is_available() failed)."
    echo "Dit is waarschijnlijk een driver/CUDA mismatch."
    echo "Output was: '$CUDA_CHECK'"
    echo "ComfyUI wordt NIET gestart om kosten te besparen."
    echo "------------------------------------------------------"
    
    # Toon diagnostische info
    echo "Diagnostische info:"
    nvidia-smi
    
    exit 1
else
    echo "CUDA check OK. Starting ComfyUI..."
    # Start ComfyUI
    nohup python main.py --listen --port 8188 --use-sage-attention &
fi
# --- EINDE VEILIGHEIDSCONTROLE ---


curl -sL https://raw.githubusercontent.com/beeguy1234/Runpod/main/download.sh | bash
