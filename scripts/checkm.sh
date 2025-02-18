#!/bin/bash

set -e

# Configuración base
RESULTS_DIR="/mnt/d/PC/Descargas/Pipeline_acinetobacter/results"
THREADS=12
MAMBA_PATH="/home/paula/conda/bin/mamba"
CHECKM_ENV="checkm_env"

# Obtener la fecha actual en formato DD_MM_YY
CURRENT_DATE=$(date +"%d_%m_%y")

# Verificar el directorio de ensamblaje de hoy
TODAY_ASSEMBLY_DIR="${RESULTS_DIR}/assembly_${CURRENT_DATE}"

if [ -d "$TODAY_ASSEMBLY_DIR" ]; then
    ASSEMBLY_DIR="$TODAY_ASSEMBLY_DIR"
    echo "Se encontró el directorio de ensamblaje de hoy: $(basename "$ASSEMBLY_DIR")"
else
    echo "No se encontró un directorio de ensamblaje para la fecha de hoy."
    echo "Buscando otros directorios de assembly..."
    
    # Encontrar todas las carpetas de assembly y almacenarlas
    assembly_dirs=()
    while IFS= read -r -d '' dir; do
        assembly_dirs+=("$dir")
    done < <(find "$RESULTS_DIR" -maxdepth 1 -type d -name "assembly_*" -print0 | sort -z)

    # Si no se encontraron carpetas
    if [ ${#assembly_dirs[@]} -eq 0 ]; then
        echo "No se encontraron carpetas de assembly en $RESULTS_DIR"
        exit 1
    fi

    # Selección de la carpeta
    if [ ${#assembly_dirs[@]} -eq 1 ]; then
        # Si solo hay una carpeta, usarla automáticamente
        ASSEMBLY_DIR="${assembly_dirs[0]}"
        echo "Única carpeta de assembly encontrada, usando: $(basename "$ASSEMBLY_DIR")"
    else
        # Si hay más de una carpeta, mostrar opciones
        echo "Carpetas de assembly disponibles:"
        for i in "${!assembly_dirs[@]}"; do
            echo "$((i+1))) $(basename "${assembly_dirs[$i]}")"
        done
        
        echo
        echo "Por favor, seleccione el número de la carpeta de assembly (1-${#assembly_dirs[@]}):"
        read -r selection
        
        # Validar la selección
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#assembly_dirs[@]} ]; then
            echo "Selección inválida: $selection"
            exit 1
        fi
        
        ASSEMBLY_DIR="${assembly_dirs[$((selection-1))]}"
        echo "Seleccionada: $(basename "$ASSEMBLY_DIR")"
    fi
fi

# Directorio para los resultados de CheckM
CHECKM_DIR="${ASSEMBLY_DIR}/checkm_results"
mkdir -p "$CHECKM_DIR"

# Buscar archivos .fasta en subcarpetas
fasta_files=($(find "$ASSEMBLY_DIR" -type f -name "*assembly.fasta"))
echo "Archivos .fasta encontrados: ${#fasta_files[@]}"

if [ ${#fasta_files[@]} -eq 0 ]; then
    echo "No se encontraron archivos .fasta en el directorio de ensamblaje o sus subcarpetas."
    exit 1
fi

# Crear un directorio temporal para los enlaces simbólicos
TEMP_FASTA_DIR="${CHECKM_DIR}/bins"
mkdir -p "$TEMP_FASTA_DIR"

# Crear enlaces simbólicos para todos los archivos fasta
for fasta_file in "${fasta_files[@]}"; do
    sample_name=$(basename "$(dirname "$fasta_file")")
    ln -sf "$fasta_file" "${TEMP_FASTA_DIR}/${sample_name}.fasta"
done

# Ejecutar CheckM con los mismos argumentos que el script original
echo "Ejecutando CheckM..."
$MAMBA_PATH run -n $CHECKM_ENV checkm lineage_wf \
    "$TEMP_FASTA_DIR" \
    "$CHECKM_DIR" \
    -t $THREADS \
    -x fasta \
    --reduced_tree \
    --tab_table \
    --file "${CHECKM_DIR}/checkm_results.tsv"

# Limpiar el directorio temporal
rm -rf "$TEMP_FASTA_DIR"

echo "Análisis de CheckM completado. Resultados en: ${CHECKM_DIR}/checkm_results.tsv"