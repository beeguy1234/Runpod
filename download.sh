#!/bin/bash

# --- CONFIGURATIE ---

if [ -z "$(command -v aria2c)" ]; then
  echo "aria2 niet gevonden. Bezig met installeren..."
  apt-get update
  apt-get -y install aria2
  fi

# Controleer of de secret is meegegeven
if [ -z "$MIJN_SECRET" ]; then
  echo "Fout: De variabele MIJN_SECRET is niet ingesteld."
  echo "Stel deze in voordat je het script uitvoert:"
  echo "export MIJN_SECRET='jouw_huggingface_token'"
  exit 1
fi
echo "Secret voor huggingface gedetecteerd."

# Basisinstellingen
BASE_MODEL_DIR="/app/ComfyUI/models"
ARIA2_OPTS="-c -x 16 -s 16"
# Wees zeker dat de header-waarde als één string wordt doorgegeven
ARIA2_HEADER="Authorization: Bearer ${MIJN_SECRET}"

# --- 1. MASTER DOWNLOAD LIJST ---
# Definieer hier alle mogelijke downloads.
# Formaat: [key]="URL|bestemmingsmap"
# (De bestemmingsmap is relatief aan $BASE_MODEL_DIR)

declare -A ALL_DOWNLOADS

ALL_DOWNLOADS[SD3_5_CHECKPOINT]="https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/sd3.5_large.safetensors|checkpoints"
ALL_DOWNLOADS[SD3_5_VAE]="https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/vae/diffusion_pytorch_model.safetensors|vae"
ALL_DOWNLOADS[T5]="https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors|text_encoders"
ALL_DOWNLOADS[UMT5]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp16.safetensors|text_encoders"
ALL_DOWNLOADS[WAN_LORA_RELIGHT]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_animate_14B_relight_lora_bf16.safetensors|loras"
ALL_DOWNLOADS[WAN_LORA_I2V_HIGH]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors|loras"
ALL_DOWNLOADS[WAN_LORA_I2V_LOW]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors|loras"
ALL_DOWNLOADS[WAN_LORA_LIGHTX]="https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors|loras"
ALL_DOWNLOADS[WAN_DIFFMOD_I2V_HIGH]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors|diffusion_models"
ALL_DOWNLOADS[WAN_DIFFMOD_I2V_LOW]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors|diffusion_models"
ALL_DOWNLOADS[WAN_DIFFMOD_ANIMATE]="https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Wan22Animate/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors|diffusion_models"
ALL_DOWNLOADS[SEGMENTATION]="https://huggingface.co/VeryAladeen/Sec-4B/resolve/main/SeC-4B-fp16.safetensors|sams"
ALL_DOWNLOADS[WAN_VAE_2_1]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors|vae"
ALL_DOWNLOADS[WAN_VAE_2_2]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors|vae"
ALL_DOWNLOADS[VITPOSE_L]="https://huggingface.co/JunkyByte/easy_ViTPose/resolve/main/onnx/wholebody/vitpose-l-wholebody.onnx|detection"
ALL_DOWNLOADS[YOLOV10M]="https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx|detection"
ALL_DOWNLOADS[UPSCALER_ESRGAN_X2]="https://huggingface.co/dtarnow/UPscaler/resolve/main/RealESRGAN_x2plus.pth|upscale_models"
ALL_DOWNLOADS[UPSCALER_NOMOS_ESRGAN_X2]="https://huggingface.co/Kyca/KycasFiles/resolve/main/2xNomosUni_esrgan_multijpg.pth|upscale_models"


# --- 2. DEFINIEER HIER JE GROEPEN ---
# Vul deze arrays met de 'keys' uit de ALL_DOWNLOADS lijst hierboven.

# Groep 1: SD 3.5 Large (Basis)
GROUP_SD3_5=(
    "SD3_5_CHECKPOINT"
    "T5"
    "SD3_5_VAE"
)

# Groep 2: FLUX (Specifiek)
GROUP_FLUX=(
    "T5"
    "SD3_5_VAE"
)

# Groep 3: Wan 2.2 I2V (Alles voor Wan)
GROUP_WAN_I2V=(
    "UMT5"
    "WAN_LORA_I2V_HIGH"
    "WAN_LORA_I2V_LOW"
    "WAN_VAE_2_2"
    "WAN_DIFFMOD_I2V_HIGH"
    "WAN_DIFFMOD_I2V_LOW"
)

# Groep 4: Upscaler (Algemeen)
GROUP_UPSCALER=(
    "UPSCALER_ESRGAN_X2"
    "UPSCALER_NOMOS_ESRGAN_X2"
)

# Groep 5: Wan Animate
GROUP_WAN_ANIMATE=(
    "UMT5"
    "WAN_DIFFMOD_ANIMATE"
    "WAN_LORA_LIGHTX"
    "WAN_LORA_RELIGHT"
    "WAN_VAE_2_1"
    "VITPOSE_L"
    "YOLOV10M"
    "SEGMENTATION"
)

# icm IPadapters
GROUP_STABLE_YOGI=(
 )


# --- 3. DOWNLOAD FUNCTIE ---
# Deze functie verwerkt het downloaden.
# Gebruik: download_files "key1" "key2" "key3" ...
# -----------------------------
download_files() {
    local keys=("$@") # Ontvang alle argumenten als een array
    local total=${#keys[@]}
    local i=0

    if [ $total -eq 0 ]; then
        echo "Geen bestanden gedefinieerd voor deze groep."
        return
    fi

    echo "--- Starten van $total downloads ---"

    for key in "${keys[@]}"; do
        ((i++))
        
        # Haal URL en map op
        local value="${ALL_DOWNLOADS[$key]}"
        if [ -z "$value" ]; then
            echo "($i/$total) [SKIPPING] Waarschuwing: Geen download-entry gevonden voor key '$key'."
            continue
        fi
        
        # Splits de string op |
        local url=$(echo "$value" | cut -d'|' -f1)
        local dest_folder=$(echo "$value" | cut -d'|' -f2)
        
        local dest_dir="$BASE_MODEL_DIR/$dest_folder"
        local filename=$(basename "$url")
        local dest_file="$dest_dir/$filename"
        
        mkdir -p "$dest_dir"
        
        # Check of bestand al bestaat
        if [ -f "$dest_file" ]; then
            echo "($i/$total) [SKIPPED] $filename bestaat al in $dest_folder."
        else
            echo "($i/$total) [DOWNLOADING] Start download: $filename -> $dest_folder"
            aria2c $ARIA2_OPTS --header="$ARIA2_HEADER" "$url" -d "$dest_dir" -o "$filename"
            
            if [ $? -eq 0 ]; then
                echo "($i/$total) [COMPLETED] Download van $filename voltooid."
            else
                echo "($i/$total) [FAILED] Waarschuwing: Download van $filename is mislukt."
            fi
        fi
    done
    
    echo "--- Downloadtaak voltooid ---"
}


# --- 4. HOOFDMENU LOGICA ---
# Toont het menu en reageert op input.
# -------------------------
function show_menu() {
    echo "====================================="
    echo "  ComfyUI Model Downloader  "
    echo "====================================="
    echo "Kies welke modelsets je wilt downloaden:"
    echo
    echo "  1) SD 3.5 Large"
    echo "  2) FLUX "
    echo "  3) Wan 2.2 I2V "
    echo "  4) Upscalers"
    echo "  5) Wan 2.2 Animate"
    echo
    echo "  q) Stoppen (Quit)"
    echo "-------------------------------------"
    read -p "Maak je keuze (1-5, q): " choice </dev/tty
}

# Main script loop
while true; do
    show_menu
    
    case $choice in
        1)
            download_files "${GROUP_SD3_5[@]}"
            ;;
        2)
            download_files "${GROUP_FLUX[@]}"
            ;;
        3)
            download_files "${GROUP_WAN_I2V[@]}"
            ;;
        4)
            download_files "${GROUP_UPSCALER[@]}"
            ;;
        5)
            download_files "${GROUP_WAN_ANIMATE[@]}"
            ;;
        q|Q)
            echo "Script stoppen."
            break
            ;;
        *)
            echo "Ongeldige keuze '$choice'. Probeer opnieuw."
            sleep 2 # Geef tijd om de fout te lezen
            ;;
    esac
    echo
    echo "----------------------------------------------------"
done

echo "Klaar."
