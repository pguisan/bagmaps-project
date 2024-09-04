#!/bin/bash

# Activar el modo de depuración
set -x

# Directorio base del proyecto
BASE_DIR="/mnt/d/PC/Descargas/Pipeline_acinetobacter/results"
echo "Directorio base del proyecto: $BASE_DIR"

# Crear un directorio de resultados para Bakta con marca de tiempo
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BAKTA_RESULTS_DIR="${BASE_DIR}/Bakta_anotaciones_${TIMESTAMP}"
echo "Directorio de resultados de Bakta: $BAKTA_RESULTS_DIR"

# Ruta completa a mamba
MAMBA_PATH="/home/paula/conda/bin/mamba"
echo "Ruta de mamba: $MAMBA_PATH"

# Configuración de paralelización
TOTAL_CORES=16
CORES_TO_USE=12
PARALLEL_JOBS=2
CPUS_PER_JOB=$((CORES_TO_USE / PARALLEL_JOBS))

# Variables para opciones de Bakta
BAKTA_DB="/mnt/d/PC/bakta_db/db"
echo "Base de datos de Bakta: $BAKTA_DB"
MIN_CONTIG_LENGTH=200
TRANSLATION_TABLE=11

# Comprobar la versión de Bakta
BAKTA_VERSION=$("$MAMBA_PATH" run -n bakta_env bakta --version)
echo "Versión de Bakta: $BAKTA_VERSION"

# Listar carpetas de ensamblaje y permitir al usuario elegir
echo "Carpetas de ensamblaje disponibles:"
ASSEMBLY_DIRS=($(find "$BASE_DIR" -maxdepth 1 -type d -name "assembly_*"))
for i in "${!ASSEMBLY_DIRS[@]}"; do
    echo "$((i+1)). ${ASSEMBLY_DIRS[$i]##*/}"
done

echo "Por favor, elige el número de la carpeta de ensamblaje que deseas anotar:"
read -r choice

if [[ $choice -lt 1 || $choice -gt ${#ASSEMBLY_DIRS[@]} ]]; then
    echo "Selección inválida. Saliendo."
    exit 1
fi

SELECTED_DIR="${ASSEMBLY_DIRS[$((choice-1))]}"
echo "Has seleccionado: $SELECTED_DIR"

# Crear directorio de resultados para Bakta
mkdir -p "$BAKTA_RESULTS_DIR"

# Buscar subdirectorios en la carpeta seleccionada
SUBDIRS=($(find "$SELECTED_DIR" -maxdepth 1 -type d))
echo "Subdirectorios encontrados: ${SUBDIRS[*]}"

# Iterar sobre los subdirectorios
for subdir in "${SUBDIRS[@]}"; do
    echo "Procesando subdirectorio: $subdir"
    
    # Buscar archivos FASTA en el subdirectorio
    FASTA_FILES=($(find "$subdir" -maxdepth 1 -type f \( -name "*.fasta" -o -name "*.fa" \)))
    echo "Archivos FASTA encontrados en $subdir: ${FASTA_FILES[*]}"
    
    for fasta_file in "${FASTA_FILES[@]}"; do
        if [[ -f "$fasta_file" ]]; then
            assembly_name=$(basename "$subdir")
            
            echo "Procesando $assembly_name"
            echo "Archivo FASTA: $fasta_file"
            
            echo "Anotando $assembly_name con Bakta..."
            
            # Ejecutar Bakta con mamba run
            "$MAMBA_PATH" run -n bakta_env bakta \
                --db "$BAKTA_DB" \
                --min-contig-length "$MIN_CONTIG_LENGTH" \
                --translation-table "$TRANSLATION_TABLE" \
                --keep-contig-headers \
                --threads "$CPUS_PER_JOB" \
                --output "${BAKTA_RESULTS_DIR}/${assembly_name}" \
                --locus-tag "${assembly_name}" \
                --genus "Acinetobacter" \
                --species "sp." \
                --gram "?" \
                --skip-plot \
                --force \
                "$fasta_file"
            
            # Comprobar si Bakta se ejecutó correctamente
            if [ $? -eq 0 ]; then
                echo "Bakta se ejecutó correctamente para $assembly_name"
            else
                echo "Error: Bakta falló para $assembly_name"
            fi
        else
            echo "Archivo no encontrado: $fasta_file"
        fi
    done
done

# Desactivar el modo de depuración
set +x

echo "Proceso completado. Los resultados se encuentran en $BAKTA_RESULTS_DIR"