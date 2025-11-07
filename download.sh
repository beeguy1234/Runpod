#!/bin/bash

# --- CONFIGURATIE ---

if [ -z "$(command -v aria2c)" ]; then
  echo "aria2 niet gevonden. Bezig met installeren..."
  # Aanname dat dit in een omgeving draait waar apt-get beschikbaar is
  apt-get update
  apt-get -y install aria2
  fi

# Controleer Hugging Face Secret
if [ -z "$MIJN_SECRET" ]; then
  echo "Fout: De variabele MIJN_SECRET (voor Hugging Face) is niet ingesteld."
  echo "Stel deze in voordat je het script uitvoert:"
  echo "export MIJN_SECRET='jouw_huggingface_token'"
  exit 1
else
  echo "Secret voor Hugging Face gedetecteerd."
fi

# Controleer Civitai Secret
if [ -z "$CIVITAI_SECRET" ]; then
  echo "Fout: De variabele CIVITAI_SECRET (voor Civitai) is niet ingesteld."
  echo "Stel deze in voordat je het script uitvoert:"
  echo "export CIVITAI_SECRET='jouw_civitai_api_key'"
  exit 1
else
  echo "Secret voor Civitai gedetecteerd."
fi

# Basisinstellingen
BASE_MODEL_DIR="/app/ComfyUI/models"
ARIA2_OPTS="-c -x 16 -s 16"
# Definieer de headers voor de verschillende services
ARIA2_HEADER_HF="Authorization: Bearer ${MIJN_SECRET}"
# ARIA2_HEADER_CIVITAI="Authorization: Bearer ${CIVITAI_SECRET}" # Niet meer nodig, wordt query param


# --- 1. MASTER DOWNLOAD LIJST ---
# Definieer hier alle mogelijke downloads.
# NIEUW FORMAAT: [key]="URL|bestemmingsmap|optionele_bestandsnaam"
# (De bestemmingsmap is relatief aan $BASE_MODEL_DIR)

declare -A ALL_DOWNLOADS

# Voorbeeld met de NIEUWE optie (derde parameter):
ALL_DOWNLOADS[Realism_SDXL_By-Stable_Yogi_V7_BF16]="https://civitai.com/api/download/models/1928565?type=Model&format=SafeTensor&size=pruned&fp=fp16|checkpoints|Realism_SDXL_By-Stable_Yogi_V7_BF16.safetensors"

# Voorbeelden met de OUDE (default) werking:
ALL_DOWNLOADS[SD3_5_CHECKPOINT]="https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/sd3.5_large.safetensors|checkpoints"
ALL_DOWNLOADS[SD3_5_VAE]="https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/vae/diffusion_pytorch_model.safetensors|vae"
ALL_DOWNLOADS[SD3_5_IPADAPTER]="https://huggingface.co/InstantX/SD3.5-Large-IP-Adapter/blob/main/ip-adapter.bin|ipadapter|SD3.5-Large-IP-Adapter"
ALL_DOWNLOADS[SD3_5_CLIPVISION]="https://huggingface.co/Comfy-Org/sigclip_vision_384|clip_vision|SD3.5-clipvision"
ALL_DOWNLOADS[FLUX_DEV]="https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev.safetensors|checkpoints"
ALL_DOWNLOADS[T5]="https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors|text_encoders"
ALL_DOWNLOADS[CLIP_G]="https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/text_encoders/clip_g.safetensors|text_encoders"
ALL_DOWNLOADS[CLIP_L]="https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/text_encoders/clip_l.safetensors|text_encoders"
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
ALL_DOWNLOADS[UPSCALER_NMKD_SIAX_X4]="https://huggingface.co/gemasai/4x_NMKD-Siax_200k/resolve/main/4x_NMKD-Siax_200k.pth|upscale_models"
ALL_DOWNLOADS[ip-adapter-faceid_sdxl_bin]="https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid_sdxl.bin|ipadapter"
ALL_DOWNLOADS[ip-adapter-faceid-plusv2_sdxl]="https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin|ipadapter"
ALL_DOWNLOADS[ip-adapter-faceid-plusv2_sdxl_lora]="https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors|loras"
ALL_DOWNLOADS[ip-adapter-faceid_sdxl_lora]="https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid_sdxl_lora.safetensors|loras"
ALL_DOWNLOADS[ip-adapter-faceid-portrait_sdxl]="https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-portrait_sdxl.bin|ipadapter"
ALL_DOWNLOADS[ip-adapter-faceid-portrait_sdxl_unnorm_bin]="https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-portrait_sdxl_unnorm.bin|ipadapter"
ALL_DOWNLOADS[ip-adapter_sdxl_vit-h]="https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl_vit-h.safetensors|ipadapter"
ALL_DOWNLOADS[ip-adapter-plus_sdxl_vit-h]="https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors|ipadapter"
ALL_DOWNLOADS[ip-adapter-plus-face_sdxl_vit-h]="https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus-face_sdxl_vit-h.safetensors|ipadapter"
ALL_DOWNLOADS[ip-adapter_sdxl]="https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl.safetensors|ipadapter"
ALL_DOWNLOADS[CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors]="https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors|clip_vision|CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors"
ALL_DOWNLOADS[CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors]="https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors|clip_vision|CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"



# --- 2. DEFINIEER HIER JE GROEPEN ---
# Vul deze arrays met de 'keys' uit de ALL_DOWNLOADS lijst hierboven.

# Groep 1: SD 3.5 Large (Basis)
GROUP_SD3_5=(
    "SD3_5_CHECKPOINT"
    "T5"
    "SD3_5_VAE"
    "CLIP_L"
    "CLIP_G"
    "SD3_5_IPADAPTER"
    "SD3_5_CLIPVISION"
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
    "UPSCALER_NMKD_SIAX_X4"
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
 "Realism_SDXL_By-Stable_Yogi_V7_BF16"
 )

 GROUP_IP_ADAPTER=(
    "ip-adapter-faceid-plusv2_sdxl"
    "ip-adapter-faceid-plusv2_sdxl_lora"
    "ip-adapter-faceid_sdxl_lora"
    "ip-adapter-faceid-portrait_sdxl"
    "ip-adapter-faceid_sdxl_bin"
    "ip-adapter-faceid-portrait_sdxl_unnorm_bin"
    "ip-adapter_sdxl_vit-h"
    "ip-adapter-plus_sdxl_vit-h"
    "ip-adapter-plus-face_sdxl_vit-h"
    "ip-adapter_sdxl"
    "CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors"
    "CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"    
 )


# --- 3. DOWNLOAD FUNCTIE (AANGEPAST) ---
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
        
        # --- WIJZIGING START ---
        # Splits de string op | in 3 delen
        local url=$(echo "$value" | cut -d'|' -f1)
        local dest_folder=$(echo "$value" | cut -d'|' -f2)
        local custom_filename=$(echo "$value" | cut -d'|' -f3) # Nieuwe 3e parameter
        
        local dest_dir="$BASE_MODEL_DIR/$dest_folder"
        
        local filename=""
        if [ -n "$custom_filename" ]; then
            # 1. Gebruik de custom naam als deze is opgegeven
            filename="$custom_filename"
        else
            # 2. Geen custom naam, probeer de naam uit de URL te halen
            # Verwijder eerst query-parameters (?...)
            local url_no_query=$(echo "$url" | cut -d'?' -f1)
            filename=$(basename "$url_no_query")
            
            # 3. Fallback: Als de bestandsnaam geen extensie heeft (zoals bij Civitai's /models/12345)
            #    gebruik dan de KEY als bestandsnaam, met een .safetensors fallback.
            if ! [[ "$filename" == *.* ]]; then
                 echo "($i/$total) [INFO] Geen bestandsnaam in URL. Gebruikt key '$key.safetensors' als fallback."
                 filename="$key.safetensors"
            fi
        fi
        
        local dest_file="$dest_dir/$filename"
        
        mkdir -p "$dest_dir"
        
        # --- AANPASSING START: Selecteer header (HF) of pas URL aan (Civitai) ---
        local ARIA2_HEADER_OPT="" # Maak een lege optie-string
        local modified_url="$url" # Gebruik een nieuwe variabele voor de URL

        if [[ "$url" == *"huggingface.co"* ]]; then
            # Hugging Face gebruikt de header
            ARIA2_HEADER_OPT="--header=\"$ARIA2_HEADER_HF\""
            
        elif [[ "$url" == *"civitai.com"* ]]; then
            # Civitai: Header NIET gebruiken, maar token als query parameter toevoegen
            
            # Controleer of de URL al een '?' heeft
            if [[ "$modified_url" == *\?* ]]; then
                # Ja, voeg toe met '&'
                modified_url="${modified_url}&token=${CIVITAI_SECRET}"
            else
                # Nee, voeg toe met '?'
                modified_url="${modified_url}?token=${CIVITAI_SECRET}"
            fi
            
            # ARIA2_HEADER_OPT blijft leeg, dus er wordt geen auth header meegestuurd
        fi
        # --- AANPASSING EINDE ---

        # Check of bestand al bestaat
        if [ -f "$dest_file" ]; then
            echo "($i/$total) [SKIPPED] $filename bestaat al in $dest_folder."
        else
            echo "($i/$total) [DOWNLOADING] Start download: $filename -> $dest_folder"
            
            # Gebruik 'eval' om de string met opties correct te parsen, inclusief de header
            # $ARIA2_HEADER_OPT is leeg als er geen match is, of bevat de --header... string
            # Gebruik $modified_url in plaats van $url
            eval "aria2c $ARIA2_OPTS $ARIA2_HEADER_OPT \"$modified_url\" -d \"$dest_dir\" -o \"$filename\""
            
            if [ $? -eq 0 ]; then
                echo "($i/$total) [COMPLETED] Download van $filename voltooid."
            else
                echo "($i/$total) [FAILED] Waarschuwing: Download van $filename is mislukt."
                # Optioneel: verwijder het mislukte (incomplete) bestand
                # rm -f "$dest_file" 
            fi
        fi
        # --- WIJZIGING EINDE ---
    done
    
    echo "--- Downloadtaak voltooid ---"
}


# --- 4. HOOFDMENU LOGICA ---
# Toont het menu en reageert op input.
# (GEEN WIJZIGINGEN HIER)
# -------------------------
function show_menu() {
    echo "====================================="
    echo "  ComfyUI Model Downloader  "
    echo "====================================="
    echo "Kies welke modelsets je wilt downloaden:"
    echo
    echo "  1) SD 3.5 Large"
    echo "  2) FLUX"
    echo "  3) Wan 2.2 I2V"
    echo "  4) Upscalers"
    echo "  5) Wan 2.2 Animate"
    echo "  6) Stable Yogi Realism met IP Adapter dinges"
    echo "  7) IP Adapter dinges"
    echo
    echo "  q) Stoppen (Quit)"
    echo "-------------------------------------"
    # Zorg ervoor dat 'read' leest van de tty, zelfs als script wordt gepiped
    read -p "Maak je keuze (1-7, q): " choice </dev/tty
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
        6)
            download_files "${GROUP_IP_ADAPTER[@]}"
            download_files "${GROUP_STABLE_YOGI[@]}"
            ;;
        7)
            download_files "${GROUP_IP_ADAPTER[@]}"
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
