#!/bin/bash

set -e

# Directorio base del proyecto
BASE_DIR="/mnt/d/PC/Descargas/Pipeline_acinetobacter/results"

# Obtener la fecha actual en formato DD_MM_YY
CURRENT_DATE=$(date +"%d_%m_%y")

# Función para seleccionar el directorio de ensamblaje
select_assembly_dir() {
    echo "Directorios de ensamblaje disponibles:"
    local dirs=($(ls -d ${BASE_DIR}/assembly_* 2>/dev/null | sort -r))
    if [ ${#dirs[@]} -eq 0 ]; then
        echo "No se encontraron directorios de ensamblaje."
        exit 1
    fi
    for i in "${!dirs[@]}"; do
        echo "[$((i+1))] $(basename "${dirs[$i]}")"
    done
    
    while true; do
        read -p "Seleccione el número del directorio que desea usar (1-${#dirs[@]}): " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#dirs[@]}" ]; then
            echo "${dirs[$((selection-1))]}"
            return 0
        else
            echo "Selección inválida. Por favor, elija un número entre 1 y ${#dirs[@]}."
        fi
    done
}

# Buscar el directorio de ensamblaje de hoy
TODAY_ASSEMBLY_DIR="${BASE_DIR}/assembly_${CURRENT_DATE}"
if [ -d "$TODAY_ASSEMBLY_DIR" ]; then
    echo "Se encontró el directorio de ensamblaje de hoy: $TODAY_ASSEMBLY_DIR"
    ASSEMBLY_DIR="$TODAY_ASSEMBLY_DIR"
else
    echo "No se encontró un directorio de ensamblaje para la fecha de hoy."
    ASSEMBLY_DIR=$(select_assembly_dir)
fi

echo "Usando el directorio de ensamblaje: $ASSEMBLY_DIR"

# Directorio para los resultados de QUAST
QUAST_DIR="${BASE_DIR}/quast_results_${CURRENT_DATE}"
mkdir -p "$QUAST_DIR"

# Ruta a mamba
MAMBA_PATH="/home/paula/conda/bin/mamba"

# Ejecutar QUAST
echo "Ejecutando QUAST..."
$MAMBA_PATH run -n quast_env quast.py \
    "$ASSEMBLY_DIR"/*.fasta \
    -o "$QUAST_DIR" \
    --threads 8 \
    --labels $(ls "$ASSEMBLY_DIR"/*.fasta | xargs -n 1 basename | sed 's/_assembly.fasta//') \

echo "Análisis de QUAST completado. Los resultados se encuentran en $QUAST_DIR"