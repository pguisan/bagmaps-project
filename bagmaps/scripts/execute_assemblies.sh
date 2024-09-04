#!/bin/bash

set -e
set -x  # Muestra cada comando ejecutado

# Directorio base del proyecto
PROJECT_DIR="/mnt/d/PC/Descargas/Pipeline_acinetobacter"
echo "Directorio del proyecto: $PROJECT_DIR"

# Directorio base donde se encuentran las carpetas de los aislados
BASE_DIR="${PROJECT_DIR}/data/trimmed"
echo "Directorio base de datos: $BASE_DIR"

# Archivo con las recomendaciones
RECOMMENDATIONS_FILE="${PROJECT_DIR}/reports/combined_report_with_recommendations.txt"
echo "Archivo de recomendaciones: $RECOMMENDATIONS_FILE"

# Directorio de resultados
RESULTS_DIR="${PROJECT_DIR}/results"
echo "Directorio de resultados: $RESULTS_DIR"

# Ruta completa a mamba
MAMBA_PATH="/home/paula/conda/bin/mamba"
echo "Ruta de mamba: $MAMBA_PATH"

# Configuración de paralelización
TOTAL_CORES=16
CORES_TO_USE=12
PARALLEL_JOBS=2
CPUS_PER_JOB=$((CORES_TO_USE / PARALLEL_JOBS))

echo "Núcleos totales: $TOTAL_CORES"
echo "Núcleos utilizados: $CORES_TO_USE"
echo "Trabajos paralelos: $PARALLEL_JOBS"
echo "CPUs por trabajo: $CPUS_PER_JOB"

# Definición de funciones
generate_dragonflye_command() {
    local recommendation=$1
    local reads_file=$2
    local output_dir=$3

    case $recommendation in
        "dragonflye_long_only_high_cov"|"dragonflye_polish_high_cov")
            echo "$MAMBA_PATH run -n dragonflye_env dragonflye --reads $reads_file --outdir $output_dir --gsize 4m --depth 100 --minreadlen 3000 --cpus $CPUS_PER_JOB --namefmt 'contig%03d' --opts '--iterations 3' --force"
            ;;
        "dragonflye_long_only_normal"|"dragonflye_polish")
            echo "$MAMBA_PATH run -n dragonflye_env dragonflye --reads $reads_file --outdir $output_dir --gsize 4m --depth 50 --minreadlen 2000 --cpus $CPUS_PER_JOB --namefmt 'contig%03d' --force"
            ;;
        "dragonflye_long_only_conservative")
            echo "$MAMBA_PATH run -n dragonflye_env dragonflye --reads $reads_file --outdir $output_dir --gsize 4m --depth 30 --minreadlen 1000 --cpus $CPUS_PER_JOB --namefmt 'contig%03d' --force"
            ;;
        *)
            echo "Error: Recomendación de Dragonflye no reconocida: $recommendation" >&2
            return 1
            ;;
    esac
}

generate_unicycler_command() {
    local recommendation=$1
    local short_reads_1=$2
    local short_reads_2=$3
    local long_reads=$4
    local output_dir=$5

    case $recommendation in
        "unicycler_short_bold_cov"|"unicycler_short_normal"|"unicycler_short_conservative")
            echo "$MAMBA_PATH run -n unicycler_env unicycler -1 $short_reads_1 -2 $short_reads_2 -o $output_dir --mode $(echo $recommendation | cut -d'_' -f3) -t $CPUS_PER_JOB"
            ;;
        "unicycler_hybrid_bold_cov"|"unicycler_hybrid_normal"|"unicycler_hybrid_normal_short_biased"|"unicycler_hybrid_normal_long_biased"|"unicycler_hybrid_conservative")
            echo "$MAMBA_PATH run -n unicycler_env unicycler -1 $short_reads_1 -2 $short_reads_2 -l $long_reads -o $output_dir --mode $(echo $recommendation | cut -d'_' -f3) -t $CPUS_PER_JOB"
            ;;
        *)
            echo "Error: Recomendación de Unicycler no reconocida: $recommendation" >&2
            return 1
            ;;
    esac
}

modify_fasta_headers() {
    local input_file=$1
    local sample_name=$2
    local output_file=$3

    awk -v sample="$sample_name" '/^>/ {$0 = ">"sample"_"++i} {print}' "$input_file" > "$output_file"
}

process_sample() {
    local line=$1
    local sample=$(echo "$line" | awk '{print $1}')
    local recommendation=$(echo "$line" | awk '{print $NF}')

    echo "Procesando muestra: $sample"
    echo "Recomendación: $recommendation"

    # Verificar si el ensamblaje ya existe
    local final_assembly="$ASSEMBLY_DIR/$sample/${sample}_assembly.fasta"
    if [ -f "$final_assembly" ]; then
        echo "El ensamblaje para $sample ya existe. Omitiendo."
        return 0
    fi

    # Crear un archivo de registro para esta muestra
    local log_file="$ASSEMBLY_DIR/${sample}_assembly.log"

    {
        # Determinar el nombre de la carpeta de la muestra
        local sample_folder
        if [[ "$sample" == "89" ]]; then
            sample_folder="89_cont_trimmed"
        else
            sample_folder="${sample}_trimmed"
        fi

        # Buscar los archivos de entrada
        local short_reads_1=$(ls ${BASE_DIR}/${sample_folder}/*R1*paired_trimmed.fastq.gz 2>/dev/null || echo "")
        local short_reads_2=$(ls ${BASE_DIR}/${sample_folder}/*R2*paired_trimmed.fastq.gz 2>/dev/null || echo "")
        local long_reads=$(ls ${BASE_DIR}/${sample_folder}/*long_trimmed.fastq.gz 2>/dev/null || echo "")

        echo "Verificando archivos de entrada:"
        echo "  Short reads 1: $short_reads_1"
        echo "  Short reads 2: $short_reads_2"
        echo "  Long reads: $long_reads"

        # Verificar la existencia de los archivos
        if [[ -z "$short_reads_1" || -z "$short_reads_2" ]]; then
            echo "Error: No se encuentran los archivos de short reads para $sample"
            return 1
        fi

        local temp_output_dir="$ASSEMBLY_DIR/$sample/temp"
        local final_output_dir="$ASSEMBLY_DIR/$sample"

        # Limpiar el directorio de salida temporal si existe
        if [ -d "$temp_output_dir" ]; then
            rm -rf "$temp_output_dir"
        fi

        # Crear el directorio de salida temporal
        mkdir -p "$temp_output_dir"

        # Generar el comando apropiado
        if [[ $recommendation == dragonflye* ]]; then
            if [ -z "$long_reads" ]; then
                echo "Error: No se encuentra el archivo de long reads para $sample"
                return 1
            fi
            cmd=$(generate_dragonflye_command "$recommendation" "$long_reads" "$temp_output_dir")
        elif [[ $recommendation == unicycler* ]]; then
            if [[ $recommendation == unicycler_hybrid* ]]; then
                if [ -z "$long_reads" ]; then
                    echo "Error: No se encuentra el archivo de long reads para $sample"
                    return 1
                fi
                cmd=$(generate_unicycler_command "$recommendation" "$short_reads_1" "$short_reads_2" "$long_reads" "$temp_output_dir")
            else
                cmd=$(generate_unicycler_command "$recommendation" "$short_reads_1" "$short_reads_2" "" "$temp_output_dir")
            fi
        else
            echo "Recomendación no reconocida para $sample: $recommendation"
            return 1
        fi

        if [ $? -ne 0 ]; then
            echo "Error al generar el comando para $sample. Saltando esta muestra."
            return 1
        fi

        echo "Ejecutando: $cmd"
        if ! eval "$cmd"; then
            echo "Error en la ejecución del ensamblaje para $sample"
            return 1
        fi

        echo "Ensamblaje completado con éxito para $sample"
        
        # Crear el directorio final de salida
        mkdir -p "$final_output_dir"
        
        # Modificar los headers del archivo fasta y mover al directorio final
        if [[ $recommendation == dragonflye* ]]; then
            input_fasta="$temp_output_dir/contigs.fa"
        else
            input_fasta="$temp_output_dir/assembly.fasta"
        fi
        
        if [ -f "$input_fasta" ]; then
            output_fasta="$final_output_dir/${sample}_assembly.fasta"
            modify_fasta_headers "$input_fasta" "$sample" "$output_fasta"
            
            # Copiar otros archivos relevantes al directorio final
            cp "$temp_output_dir"/*.{log,txt,gfa} "$final_output_dir" 2>/dev/null
            
            echo "Resultados movidos a $final_output_dir"

            # Eliminar el directorio temporal
            rm -rf "$temp_output_dir"
            echo "Directorio temporal eliminado: $temp_output_dir"
        else
            echo "Error: No se encontró el archivo de ensamblaje para $sample"
            return 1
        fi
    } > "$log_file" 2>&1

    echo "Procesamiento de $sample completado. Log: $log_file"
}

# Verificar la existencia de directorios y archivos críticos
for dir in "$PROJECT_DIR" "$BASE_DIR" "$RESULTS_DIR"; do
    if [ ! -d "$dir" ]; then
        echo "Error: El directorio $dir no existe."
        exit 1
    fi
done

if [ ! -f "$RECOMMENDATIONS_FILE" ]; then
    echo "Error: El archivo de recomendaciones $RECOMMENDATIONS_FILE no existe."
    exit 1
fi

if [ ! -f "$MAMBA_PATH" ]; then
    echo "Error: mamba no encontrado en $MAMBA_PATH"
    exit 1
fi

# Obtener la fecha actual en formato DD_MM_YY
CURRENT_DATE=$(date +"%d_%m_%y")
echo "Fecha actual: $CURRENT_DATE"

# Crear el directorio de resultados con la fecha
ASSEMBLY_DIR="${RESULTS_DIR}/assembly_${CURRENT_DATE}"
echo "Intentando crear directorio: $ASSEMBLY_DIR"
mkdir -p "$ASSEMBLY_DIR"

# Verificar si se pudo crear el directorio
if [ ! -d "$ASSEMBLY_DIR" ]; then
    echo "Error: No se pudo crear el directorio $ASSEMBLY_DIR"
    echo "Por favor, verifica los permisos y la ruta."
    exit 1
fi

echo "Directorio de ensamblaje creado exitosamente: $ASSEMBLY_DIR"

# Verificar si las funciones se han definido correctamente
type process_sample >/dev/null 2>&1 || { echo "Error: La función process_sample no está definida."; exit 1; }
type generate_dragonflye_command >/dev/null 2>&1 || { echo "Error: La función generate_dragonflye_command no está definida."; exit 1; }
type generate_unicycler_command >/dev/null 2>&1 || { echo "Error: La función generate_unicycler_command no está definida."; exit 1; }
type modify_fasta_headers >/dev/null 2>&1 || { echo "Error: La función modify_fasta_headers no está definida."; exit 1; }

export -f process_sample
export -f generate_dragonflye_command
export -f generate_unicycler_command
export -f modify_fasta_headers
export BASE_DIR ASSEMBLY_DIR MAMBA_PATH CPUS_PER_JOB

echo "Iniciando ensamblajes en paralelo..."

# Leer las recomendaciones y ejecutar los comandos en paralelo
echo "Leyendo recomendaciones de: $RECOMMENDATIONS_FILE"
if [ ! -s "$RECOMMENDATIONS_FILE" ]; then
    echo "Error: El archivo de recomendaciones está vacío o no existe."
    exit 1
fi

# Mostrar las primeras líneas del archivo de recomendaciones
echo "Primeras líneas del archivo de recomendaciones:"
head -n 5 "$RECOMMENDATIONS_FILE"

# Contar el número de muestras a procesar
num_samples=$(tail -n +2 "$RECOMMENDATIONS_FILE" | wc -l)
echo "Número de muestras a procesar: $num_samples"

# Ejecutar el procesamiento en paralelo
tail -n +2 "$RECOMMENDATIONS_FILE" | parallel --bar -j $PARALLEL_JOBS process_sample

# Verificar si se han creado los directorios de salida
echo "Verificando directorios de salida creados:"
ls -l "$ASSEMBLY_DIR"

echo "Todos los ensamblajes han sido procesados y organizados en $ASSEMBLY_DIR"
echo "Revise los archivos de registro individuales en $ASSEMBLY_DIR para ver los detalles de cada ensamblaje"

# Mostrar un resumen de los archivos de registro
echo "Resumen de los archivos de registro:"
grep -H "Procesamiento de" "$ASSEMBLY_DIR"/*_assembly.log