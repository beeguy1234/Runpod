#!/bin/bash

sage_two=false;

# --- De argumenten-loop ---
# Blijf loopen zolang er argumenten ($#) zijn
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    --sage2)
      # Dit is een 'boolean' vlag. We zetten FORCE op 1 (true).
      sage_two=true;
      shift # Ga naar het volgende argument
      ;;
    *)
      # Dit is een onbekende optie OF een positioneel argument
      # We slaan het op voor later gebruik.
      echo "ONBEKEND ARGUMENT"
      shift # Ga naar het volgende argument
      ;;
  esac
done

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
	"https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
	"https://github.com/Slickytail/ComfyUI-InstantX-IPAdapter-SD3"
	"https://github.com/kijai/ComfyUI-segment-anything-2"
	"https://github.com/kijai/ComfyUI-WanVideoWrapper"
	"https://github.com/kijai/ComfyUI-WanAnimatePreprocess"
	"https://github.com/cubiq/ComfyUI_essentials"
	)

 for repo in "${CUSTOM_NODES[@]}"; do
     repo_name=$(basename "$repo")
     if [ ! -d "/app/ComfyUI/custom_nodes/$repo_name" ]; then
         echo "Downloading $repo_name..."
         cd "/app/ComfyUI/custom_nodes"
         git clone "$repo"
     fi
 done

apt-get update
apt-get -y install aria2

# uitzonderlijk deze node moet blijkbaar hernoemd worden :
#cd /app/ComfyUI/custom_nodes
#mv ComfyUI-Impact-Pack comfyui-impact-pack

cd /app/ComfyUI
pip install -U pip
pip install --no-cache -r requirements.txt
pip install --no-cache GitPython numpy pillow opencv-python  # Common dependencies
# pip install --no-cache onnxruntime-gpu    : dit op de pod zelf installeren vanwege afhankelijkheid van de GPU in kwestie !
# insightface voor ipadapter :
pip install --no-cache insightface
# installeer sage1 ifv de flag, want misschien heeft docker build voordien al gezorgd voor sage2 installatie.
if [[ "$sage_two" == "false" ]]; then
	pip install --no-cache sageattention==1.0.6
	fi

# Install dependencies for all custom nodes
        cd "/app/ComfyUI/custom_nodes"
        for node_dir in */; do
			echo "***** STARTING INSTALL $node_dir"
            if [ -d "$node_dir" ]; then
				(
                	echo "Checking dependencies for $node_dir..."
                	cd "$node_dir"
                
                	# Check for requirements.txt
                	if [ -f "requirements.txt" ]; then
                   	 	echo "Installing requirements.txt for $node_dir"
						# sam2 uitsluiten want het wijzigt de torch versie (en is heel langzaam om te installeren).  Dit is normaal deel van impact-pack node.
                    	pip install --no-cache -r <(grep -vE '(^torch|^torchvision|^torchaudio|facebookresearch/sam2)' requirements.txt)
						#pip install --no-cache -r requirements.txt
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
				)
            fi
        done

