#!/bin/bash

# Configuratie
TARGET_DIR="/app/ComfyUI/models"
BASE_PATH_TO_STRIP="/app/ComfyUI/" # Dit deel wordt weggelaten in de weergave (zodat je 'models/...' ziet)

# Kleuren voor output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Zorg dat Ctrl+C het script netjes afsluit
trap "echo -e '\n${YELLOW}Script afgebroken door gebruiker.${NC}'; exit" INT

# Check of de map bestaat
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Fout: De map $TARGET_DIR bestaat niet.${NC}"
    exit 1
fi

echo "Bezig met scannen van $TARGET_DIR (dit kan even duren)..."

# We gebruiken mapfile (bash 4.0+) om de output van find in een array te zetten.
# find output format: [bytes] [tab] [filepath]
# sort -rn: numeriek sorteren, aflopend (grootste eerst)
# head -n 10: alleen de top 10
mapfile -t files < <(find "$TARGET_DIR" -type f -printf "%s\t%p\n" | sort -rn | head -n 10)

if [ ${#files[@]} -eq 0 ]; then
    echo "Geen bestanden gevonden."
    exit 0
fi

# Loop voor het menu
while true; do
    clear
    echo -e "${YELLOW}Top 10 Grootste Bestanden in ComfyUI:${NC}"
    echo "--------------------------------------------------------"
    echo -e "   NR  |  SIZE (GB) | PAD"
    echo "--------------------------------------------------------"

    # Itereren over de gevonden bestanden
    i=1
    for line in "${files[@]}"; do
        # Data parsen: grootte en pad scheiden
        size_bytes=$(echo "$line" | cut -f1)
        full_path=$(echo "$line" | cut -f2)
        
        # Relatief pad maken voor weergave
        display_path="${full_path#$BASE_PATH_TO_STRIP}"
        
        # Grootte naar GB converteren (met 2 decimalen)
        size_gb=$(awk "BEGIN {printf \"%.2f\", $size_bytes/1073741824}")

        # Checken of bestand nog bestaat (voor status weergave)
        if [ -f "$full_path" ]; then
            printf "[%2d] | %6s GB | %s\n" "$i" "$size_gb" "$display_path"
        else
            # Als bestand gewist is, toon dit in rood
            printf "[%2d] | ${RED}%6s    | %s [VERWIJDERD]${NC}\n" "$i" "---" "$display_path"
        fi
        ((i++))
    done
    echo "--------------------------------------------------------"
    
    # Gebruikersinput vragen
    echo -e "${GREEN}Typ het nummer om te verwijderen, of 'q' om te stoppen.${NC}"
    
    # Aangepast: read checkt nu exit status (|| break) om loops bij EOF te voorkomen
    # -r zorgt dat backslashes letterlijk worden genomen
    if ! read -r -p "Keuze: " choice; then
        echo # Nieuwe regel bij EOF
        break
    fi

    # Lege input opvangen (gewoon enter drukken) -> herlaadt menu zonder foutmelding
    if [[ -z "$choice" ]]; then
        continue
    fi

    # Stoppen als q wordt getypt
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo "Afsluiten..."
        break
    fi

    # Validatie: is het een nummer?
    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Ongeldige invoer.${NC}"
        sleep 1
        continue
    fi

    # Validatie: is het nummer binnen bereik?
    if (( choice < 1 || choice > 10 )); then
        echo -e "${RED}Kies een nummer tussen 1 en 10.${NC}"
        sleep 1
        continue
    fi

    # Bestand ophalen uit de array (array index is keuze - 1)
    index=$((choice-1))
    selected_line="${files[$index]}"
    file_to_delete=$(echo "$selected_line" | cut -f2)

    # Checken of bestand al weg is
    if [ ! -f "$file_to_delete" ]; then
        echo -e "${RED}Dit bestand is al verwijderd.${NC}"
        sleep 1.5
        continue
    fi

    # Bevestiging en verwijderen
    display_name="${file_to_delete#$BASE_PATH_TO_STRIP}"
    echo -e "Je staat op het punt te verwijderen: ${YELLOW}$display_name${NC}"
    
    # Ook hier veilig lezen
    if ! read -r -p "Weet je het zeker? (y/n): " confirm; then
        echo; break
    fi
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        rm "$file_to_delete"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Bestand verwijderd.${NC}"
            sleep 1
        else
            echo -e "${RED}Fout bij verwijderen (rechten probleem?).${NC}"
            read -r -p "Druk op enter om door te gaan." _
        fi
    else
        echo "Geannuleerd."
        sleep 1
    fi
done
