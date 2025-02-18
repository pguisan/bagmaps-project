#!/bin/bash

set -e

# Configuración base
RESULTS_DIR="/mnt/d/PC/Descargas/Pipeline_acinetobacter/results"
THREADS=8
MAMBA_PATH="/home/paula/conda/bin/mamba"

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

# Crear directorio para resultados de QUAST
QUAST_DIR="${ASSEMBLY_DIR}/quast_results_$(date +%d_%m_%Y)_with_genes"
mkdir -p "$QUAST_DIR"

# Función para verificar el contenido del archivo
check_file_content() {
    local file=$1
    if [ ! -s "$file" ]; then
        echo "Advertencia: El archivo $file está vacío."
        return 1
    fi
    if ! grep -q ">" "$file"; then
        echo "Advertencia: El archivo $file no parece contener secuencias FASTA válidas."
        return 1
    fi
    return 0
}

# Arrays para almacenar archivos válidos y etiquetas
valid_files=()
labels=()

echo "Verificando archivos de ensamblaje..."
while IFS= read -r -d '' file; do
    if check_file_content "$file"; then
        valid_files+=("$file")
        # Extraer el nombre de la muestra del path del archivo
        sample=$(basename "$(dirname "$file")")
        labels+=("$sample")
        echo "Archivo válido: $file"
    else
        echo "Archivo problemático: $file"
    fi
done < <(find "$ASSEMBLY_DIR" -type f -name "*_assembly.fasta" -print0)

# Contar archivos válidos
echo "Número total de ensamblajes válidos encontrados: ${#valid_files[@]}"

# Preparar la cadena de etiquetas
labels_string=$(IFS=,; echo "${labels[*]}")

# Ejecutar QUAST con Glimmer para predicción de genes
echo "Ejecutando QUAST con predicción de genes usando Glimmer..."
if ! $MAMBA_PATH run -n quast_env quast.py \
    "${valid_files[@]}" \
    -o "$QUAST_DIR" \
    -t "$THREADS" \
    --labels "$labels_string" \
    -m 500 \
    --glimmer; then
    echo "Error al ejecutar QUAST. Consulte los logs para más detalles."
else
    echo "QUAST completado con éxito. Resultados en: $QUAST_DIR"
fi

echo "Proceso de evaluación con QUAST y predicción de genes completado."