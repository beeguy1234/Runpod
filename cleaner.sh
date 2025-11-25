#!/bin/bash

# Configuratie
TARGET_DIR="/app/ComfyUI/models"
BASE_PATH_TO_STRIP="/app/ComfyUI/"

# Kleuren
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Trap voor netjes afsluiten bij Ctrl+C
trap "echo -e '\n${YELLOW}Script afgebroken.${NC}'; exit" INT

# --- JUPYTER/RUNPOD SPECIFIEKE FIX ---
# We bepalen de invoerbron. In Jupyter terminals is stdin soms afgesloten of omgeleid.
# We proberen expliciet /dev/tty te gebruiken als dat bestaat.
if [ -c /dev/tty ]; then
    INPUT_SOURCE="/dev/tty"
else
    INPUT_SOURCE="/dev/stdin"
    # Als we geen TTY hebben en ook geen interactieve stdin, waarschuw de gebruiker
    if [ ! -t 0 ]; then
        echo -e "${RED}LET OP: Geen interactieve terminal gedetecteerd!${NC}"
        echo "Draai dit script in een 'Terminal' tabblad in JupyterLab, niet in een Notebook cell."
        echo "Probeer: File -> New -> Terminal"
        sleep 2
    fi
fi
# -------------------------------------

if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Fout: De map $TARGET_DIR bestaat niet.${NC}"
    exit 1
fi

echo "Bezig met scannen van $TARGET_DIR..."

# Bestanden zoeken (top 10 grootste)
mapfile -t files < <(find "$TARGET_DIR" -type f -printf "%s\t%p\n" | sort -rn | head -n 10)

if [ ${#files[@]} -eq 0 ]; then
    echo "Geen bestanden gevonden."
    exit 0
fi

while true; do
    clear
    echo -e "${YELLOW}Top 10 Grootste Bestanden in ComfyUI:${NC}"
    echo "--------------------------------------------------------"
    echo -e "   NR  |  SIZE (GB) | PAD"
    echo "--------------------------------------------------------"

    i=1
    for line in "${files[@]}"; do
        size_bytes=$(echo "$line" | cut -f1)
        full_path=$(echo "$line" | cut -f2)
        display_path="${full_path#$BASE_PATH_TO_STRIP}"
        size_gb=$(awk "BEGIN {printf \"%.2f\", $size_bytes/1073741824}")

        if [ -f "$full_path" ]; then
            printf "[%2d] | %6s GB | %s\n" "$i" "$size_gb" "$display_path"
        else
            printf "[%2d] | ${RED}%6s    | %s [VERWIJDERD]${NC}\n" "$i" "---" "$display_path"
        fi
        ((i++))
    done
    echo "--------------------------------------------------------"
    
    echo -e "${GREEN}Typ nummer om te verwijderen, of 'q' om te stoppen.${NC}"
    
    # We lezen expliciet van de gedetecteerde INPUT_SOURCE
    if ! read -r -p "Keuze: " choice < "$INPUT_SOURCE"; then
        echo; break
    fi

    if [[ -z "$choice" ]]; then continue; fi

    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo "Afsluiten..."
        break
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > 10 )); then
        echo -e "${RED}Ongeldige keuze. Kies 1-10.${NC}"
        sleep 1
        continue
    fi

    index=$((choice-1))
    selected_line="${files[$index]}"
    file_to_delete=$(echo "$selected_line" | cut -f2)

    if [ ! -f "$file_to_delete" ]; then
        echo -e "${RED}Reeds verwijderd.${NC}"
        sleep 1
        continue
    fi

    display_name="${file_to_delete#$BASE_PATH_TO_STRIP}"
    echo -e "Verwijderen: ${YELLOW}$display_name${NC}"
    
    read -r -p "Zeker weten? (y/n): " confirm < "$INPUT_SOURCE"
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        rm "$file_to_delete" && echo -e "${GREEN}Verwijderd.${NC}" || echo -e "${RED}Fout bij verwijderen.${NC}"
        sleep 1
    else
        echo "Geannuleerd."
        sleep 1
    fi
done
