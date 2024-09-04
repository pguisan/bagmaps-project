#!/bin/bash

set -e

# Definir los parámetros
BASE_DIR="/mnt/d/PC/Descargas/Pipeline_acinetobacter"
input_dir="${BASE_DIR}/data/input"
output_dir="${BASE_DIR}/data/trimmed"
results_dir="${BASE_DIR}/results"

# Ruta específica para el archivo de adaptadores Nextera
adapters_file="/home/paula/conda/envs/qc_env/share/trimmomatic-0.39-2/adapters/NexteraPE-PE.fa"

# Ruta completa a mamba
MAMBA_PATH="/home/paula/conda/bin/mamba"

# Número de hilos para Trimmomatic y Porechop
THREADS=12

# Configuración de memoria para Java (usado por FastQC)
export _JAVA_OPTIONS="-Xmx4g"

# Crear directorios necesarios
mkdir -p "$input_dir" "$output_dir" "$results_dir"

# Verificar si mamba está disponible
if [ ! -f "$MAMBA_PATH" ]; then
    echo "Error: mamba no se encontró en $MAMBA_PATH"
    exit 1
fi

# Verificar espacio en disco
min_space=10  # En gigabytes
available_space=$(df -BG "$BASE_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
if [ -z "$available_space" ] || [ "$available_space" -lt "$min_space" ]; then
    echo "Error: No hay suficiente espacio en disco. Se requieren al menos ${min_space}G."
    exit 1
fi

# Verificar permisos de escritura
if [ ! -w "$output_dir" ]; then
    echo "Error: No se tienen permisos de escritura en $output_dir"
    exit 1
fi

# Crear directorios para los reportes FastQC en results
fastqc_before_dir="$results_dir/fastqc_before"
fastqc_after_dir="$results_dir/fastqc_after"
mkdir -p "$fastqc_before_dir" "$fastqc_after_dir"

# Función para renombrar archivos
rename_files() {
    local dir=$1
    for subdir in "$dir"/*; do
        if [ -d "$subdir" ]; then
            local sample_name=$(basename "$subdir")
            for file in "$subdir"/*; do
                if [ -f "$file" ]; then
                    local base_name=$(basename "$file")
                    # Comprobar si el nombre del archivo ya comienza con el nombre de la muestra
                    if [[ "$base_name" != "${sample_name}_"* ]]; then
                        local new_name="${sample_name}_${base_name}"
                        mv "$file" "$subdir/$new_name"
                        echo "Renombrado: $file a $subdir/$new_name"
                    else
                        echo "El archivo $file ya tiene el formato correcto. No se renombra."
                    fi
                fi
            done
        fi
    done
}

# Renombrar archivos antes del procesamiento
echo "Renombrando archivos de entrada..."
rename_files "$input_dir"

# Función para procesar un par de archivos short reads
process_short_reads() {
    local input_forward=$1
    local input_reverse=$2
    local subdir=$(basename $(dirname "$input_forward"))
    local base_name=$(basename "$input_forward" | sed -E 's/_(R1_001|R1|1)\.fastq\.gz//')
    
    local output_subdir="$output_dir/${subdir}_trimmed"
    mkdir -p "$output_subdir"
    
    local output_forward_paired="$output_subdir/${base_name}_R1_paired_trimmed.fastq.gz"
    local output_reverse_paired="$output_subdir/${base_name}_R2_paired_trimmed.fastq.gz"
    
    # Verificar si los archivos de salida ya existen
    if [ -f "$output_forward_paired" ] && [ -f "$output_reverse_paired" ]; then
        echo "Los archivos para $base_name ya han sido procesados. Omitiendo."
        return
    fi
    
    echo "Procesando short reads: $base_name"
    
    # FastQC antes del preprocesado
    "$MAMBA_PATH" run -n qc_env fastqc -o "$fastqc_before_dir" --threads $THREADS --memory 4000 "$input_forward" "$input_reverse"
    
    # Trimmomatic
    "$MAMBA_PATH" run -n qc_env trimmomatic PE -threads $THREADS \
        "$input_forward" "$input_reverse" \
        "$output_forward_paired" "${output_forward_paired%.fastq.gz}_unpaired.fastq.gz" \
        "$output_reverse_paired" "${output_reverse_paired%.fastq.gz}_unpaired.fastq.gz" \
        ILLUMINACLIP:$adapters_file:2:30:10:2:keepBothReads \
        AVGQUAL:20 MINLEN:36
    
    # Eliminar archivos unpaired
    rm -f "${output_forward_paired%.fastq.gz}_unpaired.fastq.gz" "${output_reverse_paired%.fastq.gz}_unpaired.fastq.gz"
    
    # FastQC después del preprocesado
    "$MAMBA_PATH" run -n qc_env fastqc -o "$fastqc_after_dir" --threads $THREADS --memory 4000 "$output_forward_paired" "$output_reverse_paired"
}

# Función para procesar long reads
process_long_reads() {
    local input_file=$1
    local subdir=$(basename $(dirname "$input_file"))
    local base_name=$(basename "$input_file" | sed -E 's/\.fastq\.gz//')
    
    local output_subdir="$output_dir/${subdir}_trimmed"
    mkdir -p "$output_subdir"
    
    local output_file="$output_subdir/${base_name}_trimmed.fastq.gz"
    
    # Verificar si el archivo de salida ya existe
    if [ -f "$output_file" ]; then
        echo "El archivo $base_name ya ha sido procesado. Omitiendo."
        return
    fi
    
    echo "Procesando long reads: $base_name"
    
    # FastQC antes del preprocesado
    "$MAMBA_PATH" run -n qc_env fastqc -o "$fastqc_before_dir" --threads $THREADS --memory 4000 "$input_file"
    
    # Porechop
    "$MAMBA_PATH" run -n qc_env porechop -i "$input_file" -o "$output_file" \
        --discard_middle --require_two_barcodes --barcode_threshold 80 --threads $THREADS
    
    # FastQC después del preprocesado
    "$MAMBA_PATH" run -n qc_env fastqc -o "$fastqc_after_dir" --threads $THREADS --memory 4000 "$output_file"
}

# Buscar y procesar todos los pares de archivos short reads
echo "Buscando archivos de short reads..."
while IFS= read -r -d '' input_forward; do
    if [[ $input_forward =~ _R1_001\.fastq\.gz$ ]]; then
        input_reverse="${input_forward/_R1_001.fastq.gz/_R2_001.fastq.gz}"
    elif [[ $input_forward =~ _R1\.fastq\.gz$ ]]; then
        input_reverse="${input_forward/_R1.fastq.gz/_R2.fastq.gz}"
    elif [[ $input_forward =~ _1\.fastq\.gz$ ]]; then
        input_reverse="${input_forward/_1.fastq.gz/_2.fastq.gz}"
    else
        continue
    fi
    
    if [ -f "$input_reverse" ]; then
        process_short_reads "$input_forward" "$input_reverse"
    else
        echo "No se encontró el archivo reverse para $input_forward"
    fi
done < <(find "$input_dir" -type f \( -name "*_R1_001.fastq.gz" -o -name "*_R1.fastq.gz" -o -name "*_1.fastq.gz" \) -print0)

# Buscar y procesar todos los archivos long reads
echo "Buscando archivos de long reads..."
long_read_files=$(find "$input_dir" -type f \( -name "*_long.fastq.gz" -o -name "*long*.fastq.gz" -o -name "*nanopore*.fastq.gz" \))

if [ -z "$long_read_files" ]; then
    echo "No se encontraron archivos de long reads."
else
    echo "Se encontraron los siguientes archivos de long reads:"
    echo "$long_read_files"
    echo "Procesando long reads..."
    echo "$long_read_files" | while read -r input_file; do
        process_long_reads "$input_file"
    done
fi

echo "Procesamiento de calidad con Trimmomatic/Porechop y generación de reportes FastQC completados para short y long reads."