#!/bin/bash

set -e

# Directorio base del proyecto
BASE_DIR="/mnt/d/PC/Descargas/Pipeline_acinetobacter/results"

# Obtener la fecha actual en formato DD_MM_YY
CURRENT_DATE=$(date +"%d_%m_%y")

# Número de hilos a usar
THREADS=12

# Ruta a mamba y nombre del environment
MAMBA_PATH="/home/paula/conda/bin/mamba"
CHECKM2_ENV="checkm_env"

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

# Directorio para los resultados de CheckM2
CHECKM2_DIR="${BASE_DIR}/checkm2_${CURRENT_DATE}"
mkdir -p "$CHECKM2_DIR"

# Función para ejecutar CheckM2
run_checkm2() {
    local input_file="$1"
    local output_dir="$2"
    
    echo "Ejecutando CheckM2 para $(basename "$input_file")..."
    $MAMBA_PATH run -n $CHECKM2_ENV checkm2 predict --threads $THREADS --input "$input_file" --output-directory "$output_dir" --force
}

# Buscar archivos .fasta en subcarpetas
fasta_files=($(find "$ASSEMBLY_DIR" -type f -name "*assembly.fasta"))
echo "Archivos .fasta encontrados: ${#fasta_files[@]}"

if [ ${#fasta_files[@]} -eq 0 ]; then
    echo "No se encontraron archivos .fasta en el directorio de ensamblaje o sus subcarpetas."
    exit 1
fi

# Ejecutar CheckM2 para cada muestra
for fasta_file in "${fasta_files[@]}"; do
    sample_name=$(basename "$(dirname "$fasta_file")")
    output_dir="${CHECKM2_DIR}/${sample_name}"
    echo "Procesando muestra: $sample_name"
    run_checkm2 "$fasta_file" "$output_dir"
done

# Combinar los resultados de CheckM2
echo "Combinando resultados de CheckM2..."
combined_report="${CHECKM2_DIR}/combined_checkm2_results.tsv"

# Usar awk para combinar los resultados
awk '
    FNR==1 && NR!=1 { next; }
    {
        if (NR == 1) {
            print "Sample\t" $0;
        } else {
            sample = FILENAME;
            sub(/^.*\//, "", sample);
            sub(/_quality_report\.tsv$/, "", sample);
            print sample "\t" $0;
        }
    }
' "${CHECKM2_DIR}"/*/*.tsv > "$combined_report"

echo "Resultados combinados de CheckM2 guardados en $combined_report"
echo "Análisis de CheckM2 completado."