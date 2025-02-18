#!/bin/bash
set -e

# Configuración de recursos (ajustar según necesidades)
TOTAL_CORES=12     # Total de núcleos disponibles
USE_PARALLEL=0     # 0 para procesar una muestra a la vez, 1 para procesamiento paralelo
if [ "$USE_PARALLEL" -eq 1 ]; then
    PARALLEL_JOBS=8
    CPUS_PER_JOB=2
else
    PARALLEL_JOBS=1
    CPUS_PER_JOB=$TOTAL_CORES
fi

BASE_DIR="/mnt/d/PC/Descargas/Pipeline_acinetobacter/data/trimmed"
# Archivo con las recomendaciones
RECOMMENDATIONS_FILE="../reports/combined_report_with_recommendations.txt"
# Directorio de resultados
RESULTS_DIR="/mnt/d/PC/Descargas/Pipeline_acinetobacter/results"
# Ruta completa a mamba
MAMBA_PATH="/home/paula/conda/bin/mamba"

# === MENSAJES DE DEBUG ===
echo "=== Verificación de archivos y rutas ==="
echo "Verificando archivo de recomendaciones: $RECOMMENDATIONS_FILE"
if [ -f "$RECOMMENDATIONS_FILE" ]; then
    echo "✓ El archivo existe"
    echo "Contenido del directorio actual:"
    ls -l
    echo "Ruta absoluta del archivo de recomendaciones:"
    realpath "$RECOMMENDATIONS_FILE"
    echo "Número de líneas en el archivo (incluyendo header):"
    wc -l "$RECOMMENDATIONS_FILE"
    echo "Número de muestras (sin header):"
    tail -n +2 "$RECOMMENDATIONS_FILE" | wc -l
    echo "Primeras 5 líneas del archivo:"
    head -n 5 "$RECOMMENDATIONS_FILE"
else
    echo "✗ ERROR: No se encuentra el archivo de recomendaciones"
    echo "Directorio actual: $(pwd)"
    echo "Contenido del directorio:"
    ls -l
    exit 1
fi

echo "Verificando directorio de datos: $BASE_DIR"
if [ -d "$BASE_DIR" ]; then
    echo "✓ El directorio existe"
    echo "Número de carpetas de muestras:"
    ls "$BASE_DIR" | grep "_trimmed" | wc -l
else
    echo "✗ ERROR: No se encuentra el directorio de datos"
    exit 1
fi
echo "=================================="

# Crear el directorio de resultados con la fecha
ASSEMBLY_DIR="${RESULTS_DIR}/assembly_21_01_25_hybrid"
mkdir -p "$ASSEMBLY_DIR"

# Verificar si se pudo crear el directorio
if [ ! -d "$ASSEMBLY_DIR" ]; then
    echo "Error: No se pudo crear el directorio $ASSEMBLY_DIR"
    echo "Por favor, verifica los permisos y la ruta."
    exit 1
fi

# Calcular el número total de muestras correctamente
TOTAL_SAMPLES=$(tail -n +2 "$RECOMMENDATIONS_FILE" | wc -l)
CURRENT_SAMPLE=0

# Mostrar configuración
echo "=== Configuración del sistema ==="
echo "Núcleos totales disponibles: $TOTAL_CORES"
if [ "$USE_PARALLEL" -eq 1 ]; then
    echo "Modo: Paralelo"
    echo "Trabajos paralelos: $PARALLEL_JOBS"
    echo "CPUs por trabajo: $CPUS_PER_JOB"
    echo "Total CPUs utilizadas: $((PARALLEL_JOBS * CPUS_PER_JOB))"
else
    echo "Modo: Secuencial"
    echo "CPUs por trabajo: $CPUS_PER_JOB"
fi
echo "Total de muestras a procesar: $TOTAL_SAMPLES"
echo "==============================="

# Función para generar comandos de dragonflye
generate_dragonflye_command() {
    local recommendation=$1
    local reads_file=$2
    local output_dir=$3
    local short_reads_1=$4
    local short_reads_2=$5

    # Comando base de dragonflye con opciones comunes
    local cmd="$MAMBA_PATH run -n dragonflye_env dragonflye"
    cmd="$cmd --reads \"$reads_file\""
    cmd="$cmd --outdir \"$output_dir\""
    cmd="$cmd --gsize 4m"
    cmd="$cmd --cpus $TOTAL_CORES"
    cmd="$cmd --namefmt contig%03d"
    cmd="$cmd --force"
    cmd="$cmd --assembler flye"

    echo "DEBUG - Analizando recomendación: $recommendation" >&2

    # CASO 1: Ensamblaje híbrido (usa polypolish)
    if [[ $recommendation == *"--polypolish"* ]]; then
        echo "DEBUG - Detectado caso híbrido con polypolish" >&2
        
        # Extraer el número de rondas de polypolish
        local polypolish=$(echo "$recommendation" | grep -o "polypolish [0-9]" | cut -d' ' -f2)
        
        # Añadir lecturas cortas y polypolish al comando
        cmd="$cmd --R1 \"$short_reads_1\" --R2 \"$short_reads_2\" --polypolish $polypolish"
        
        echo "$cmd"
        return 0
    fi

    # CASO 2: Ensamblaje con minreadlen específico
    if [[ $recommendation == *"--min-readlen"* ]]; then
        echo "DEBUG - Detectado caso con minreadlen" >&2
        
        # Extraer el valor de min-readlen y convertirlo a minreadlen
        local minreadlen=$(echo "$recommendation" | grep -o "min-readlen [0-9]*" | cut -d' ' -f2)
        cmd="$cmd --minreadlen $minreadlen"
        
        # Verificar si también tiene iterations
        if [[ $recommendation == *"--iterations"* ]]; then
            echo "DEBUG - También tiene iterations" >&2
            local iterations=$(echo "$recommendation" | grep -o "iterations [0-9]" | cut -d' ' -f2)
            cmd="$cmd --opts '--iterations $iterations'"
        fi
        
        echo "$cmd"
        return 0
    fi

    # CASO 3: Ensamblaje que solo usa iterations
    if [[ $recommendation == *"--iterations"* ]]; then
        echo "DEBUG - Detectado caso con solo iterations" >&2
        
        # Extraer el número de iterations
        local iterations=$(echo "$recommendation" | grep -o "iterations [0-9]" | cut -d' ' -f2)
        cmd="$cmd --opts '--iterations $iterations'"
        
        echo "$cmd"
        return 0
    fi

    # Si llegamos aquí, la recomendación no coincide con ningún caso esperado
    echo "Error: Formato de recomendación de Dragonflye no reconocido: $recommendation" >&2
    return 1
}
# Función para generar comandos de unicycler
generate_unicycler_command() {
    local recommendation=$1
    local short_reads_1=$2
    local short_reads_2=$3
    local long_reads=$4
    local output_dir=$5

    # Eliminar cualquier espacio al final de la recomendación
    recommendation=$(echo "$recommendation" | tr -d '[:space:]')

    case "$recommendation" in
        "unicycler_short_normal")
            echo "$MAMBA_PATH run -n unicycler_env unicycler -1 \"$short_reads_1\" -2 \"$short_reads_2\" -o \"$output_dir\" --mode normal -t $TOTAL_CORES"
            ;;
        "unicycler_short_bold")
            echo "$MAMBA_PATH run -n unicycler_env unicycler -1 \"$short_reads_1\" -2 \"$short_reads_2\" -o \"$output_dir\" --mode bold -t $TOTAL_CORES"
            ;;
        "unicycler_hybrid_normal")
            echo "$MAMBA_PATH run -n unicycler_env unicycler -1 \"$short_reads_1\" -2 \"$short_reads_2\" -l \"$long_reads\" -o \"$output_dir\" --mode normal -t $TOTAL_CORES"
            ;;
        "unicycler_hybrid_bold")
            echo "$MAMBA_PATH run -n unicycler_env unicycler -1 \"$short_reads_1\" -2 \"$short_reads_2\" -l \"$long_reads\" -o \"$output_dir\" --mode bold -t $TOTAL_CORES"
            ;;
        *)
            echo "Error: Recomendación de Unicycler no reconocida: '$recommendation'" >&2
            return 1
            ;;
    esac
}

# Función para modificar los headers del FASTA
modify_fasta_headers() {
    local input_file=$1
    local sample_name=$2
    local output_file=$3

    awk -v sample="$sample_name" '/^>/ {$0 = ">"sample"_"++i} {print}' "$input_file" > "$output_file"
}

# Función process_sample modificada para saltar muestras ya procesadas
process_sample() {
    local line=$1
    local sample=$(echo "$line" | cut -f1)
    local recommendation=$(echo "$line" | cut -f7)
    
    echo "===== Procesando muestra $CURRENT_SAMPLE de $TOTAL_SAMPLES ====="
    echo "Muestra: $sample"
    echo "Recomendación: $recommendation"

    # Verificar si ya existe el ensamblaje (solo una vez)
    local final_assembly="$ASSEMBLY_DIR/$sample/${sample}_assembly.fasta"
    if [ -f "$final_assembly" ]; then
        echo "El ensamblaje para $sample ya existe y fue completado. Continuando con el siguiente..."
        return 0
    fi

    local log_file="$ASSEMBLY_DIR/${sample}_assembly.log"
    exec 1>"$log_file" 2>&1

    echo "Procesando muestra: $sample ($CURRENT_SAMPLE de $TOTAL_SAMPLES)"
    echo "Recomendación: $recommendation"

    local sample_dir="$BASE_DIR/${sample}_trimmed"
    
    # Búsqueda flexible de archivos usando find
    local short_reads_1=$(find "$sample_dir" -name "${sample}*R1*paired_trimmed.fastq.gz" -type f)
    local short_reads_2=$(find "$sample_dir" -name "${sample}*R2*paired_trimmed.fastq.gz" -type f)
    local long_reads=$(find "$sample_dir" -name "${sample}*long_trimmed.fastq.gz" -type f)

    # Debug para ver qué archivos encontró
    echo "DEBUG - Archivos encontrados:"
    echo "R1: $short_reads_1"
    echo "R2: $short_reads_2"
    echo "Long: $long_reads"

    local temp_output_dir="$sample_dir/assembly"
    local final_output_dir="$ASSEMBLY_DIR/$sample"

    # Verificar que se encontraron los archivos necesarios
    if [[ $recommendation == *"unicycler"* ]]; then
        if [ -z "$short_reads_1" ] || [ -z "$short_reads_2" ]; then
            echo "ERROR: No se encontraron los archivos de lecturas cortas necesarios para unicycler"
            exec 1>&- # Restaurar salida estándar
            return 1
        fi
        if [[ $recommendation == *"hybrid"* ]] && [ -z "$long_reads" ]; then
            echo "ERROR: No se encontró el archivo de lecturas largas necesario para unicycler hybrid"
            exec 1>&- # Restaurar salida estándar
            return 1
        fi
    elif [[ $recommendation == *"dragonflye"* ]]; then
        if [ -z "$long_reads" ]; then
            echo "ERROR: No se encontró el archivo de lecturas largas necesario para dragonflye"
            exec 1>&- # Restaurar salida estándar
            return 1
        fi
        if [[ $recommendation == *"--polypolish"* ]] && ([ -z "$short_reads_1" ] || [ -z "$short_reads_2" ]); then
            echo "ERROR: No se encontraron los archivos de lecturas cortas necesarios para polypolish"
            exec 1>&- # Restaurar salida estándar
            return 1
        fi
    fi

    if [ -d "$temp_output_dir" ]; then
        rm -rf "$temp_output_dir"
    fi

    mkdir -p "$temp_output_dir" || {
        echo "ERROR: No se pudo crear el directorio temporal $temp_output_dir"
        exec 1>&- # Restaurar salida estándar
        return 1
    }

    # Generar y ejecutar el comando apropiado
    if [[ $recommendation == dragonflye* ]]; then
        cmd=$(generate_dragonflye_command "$recommendation" "$long_reads" "$temp_output_dir" "$short_reads_1" "$short_reads_2") || {
            echo "ERROR: Fallo al generar el comando dragonflye"
            exec 1>&- # Restaurar salida estándar
            return 1
        }
    elif [[ $recommendation == unicycler* ]]; then
        cmd=$(generate_unicycler_command "$recommendation" "$short_reads_1" "$short_reads_2" "$long_reads" "$temp_output_dir") || {
            echo "ERROR: Fallo al generar el comando unicycler"
            exec 1>&- # Restaurar salida estándar
            return 1
        }
    else
        echo "ERROR: Recomendación no reconocida para $sample: $recommendation"
        exec 1>&- # Restaurar salida estándar
        return 1
    fi

    echo "Ejecutando: $cmd"
    eval "$cmd" || {
        echo "ERROR: Fallo en la ejecución del ensamblaje"
        exec 1>&- # Restaurar salida estándar
        return 1
    }

    echo "Ensamblaje completado con éxito para $sample"
    
    mkdir -p "$final_output_dir" || {
        echo "ERROR: No se pudo crear el directorio final $final_output_dir"
        exec 1>&- # Restaurar salida estándar
        return 1
    }
    
    # Determinar el archivo de entrada correcto
    if [[ $recommendation == dragonflye* ]]; then
        input_fasta="$temp_output_dir/contigs.fa"
    else
        input_fasta="$temp_output_dir/assembly.fasta"
    fi
    
    if [ -f "$input_fasta" ]; then
        output_fasta="$final_output_dir/${sample}_assembly.fasta"
        modify_fasta_headers "$input_fasta" "$sample" "$output_fasta" || {
            echo "ERROR: Fallo al modificar los headers del FASTA"
            exec 1>&- # Restaurar salida estándar
            return 1
        }
        cp "$temp_output_dir"/*.{log,txt,gfa} "$final_output_dir" 2>/dev/null || true
        echo "Resultados movidos a $final_output_dir"
    else
        echo "ERROR: No se encontró el archivo de ensamblaje $input_fasta"
        exec 1>&- # Restaurar salida estándar
        return 1
    fi

    echo "------------------------"
    echo "Progreso: $CURRENT_SAMPLE de $TOTAL_SAMPLES completado ($((CURRENT_SAMPLE * 100 / TOTAL_SAMPLES))%)"

    # Nueva verificación de errores más específica
    if grep -iE "^ERROR:|^ABORT:|process terminated|assembly failed|fatal error" "$log_file" > /dev/null; then
        echo "Se encontraron errores críticos en el proceso. Revisa el log: $log_file"
        grep -iE "^ERROR:|^ABORT:|process terminated|assembly failed|fatal error" "$log_file"
        exec 1>&- # Restaurar salida estándar
        return 1
    fi

    # Mostrar información de filtrado de lecturas (sin tratarlo como error)
    if grep -i "reads failed due to" "$log_file" > /dev/null; then
        echo "Información de filtrado de lecturas:"
        grep -i "reads failed due to" "$log_file"
    fi

    echo "Completado: $sample (ver detalles en $log_file)"
    exec 1>&- # Restaurar salida estándar
    return 0
}

# Exportar todo lo necesario
export -f process_sample
export -f generate_dragonflye_command
export -f generate_unicycler_command
export -f modify_fasta_headers
export BASE_DIR ASSEMBLY_DIR MAMBA_PATH CPUS_PER_JOB TOTAL_SAMPLES CURRENT_SAMPLE

echo "Iniciando ensamblajes..."

# Procesar las muestras una por una, continuar incluso si hay errores
tail -n +2 "$RECOMMENDATIONS_FILE" | while read -r line; do
    if ! process_sample "$line"; then
        echo "AVISO: Hubo un problema con la muestra. Continuando con la siguiente..."
    fi
done

echo "Todos los ensamblajes han sido procesados y organizados en $ASSEMBLY_DIR"
echo "Revise los archivos de registro individuales en $ASSEMBLY_DIR para ver los detalles de cada ensamblaje"