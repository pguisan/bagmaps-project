#!/bin/bash

# pipeline.sh
# Propósito: Ejecutar el pipeline completo de análisis genómico para Acinetobacter
# Uso: ./pipeline.sh [opciones]

# Activar el modo de salida inmediata en caso de error
set -e

# Directorio base del proyecto
BASE_DIR="/mnt/d/PC/Descargas/Pipeline_acinetobacter"

# Directorio de scripts
SCRIPTS_DIR="${BASE_DIR}/scripts"

# Configurar logging
LOG_DIR="${BASE_DIR}/logs"
LOG_FILE="${LOG_DIR}/pipeline_$(date +'%Y%m%d_%H%M%S').log"
mkdir -p "$LOG_DIR"

# Función para logging
log() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Función para ejecutar un script
run_script() {
    local script=$1
    log "Iniciando: $script"
    if [ -f "${SCRIPTS_DIR}/$script" ]; then
        bash "${SCRIPTS_DIR}/$script"
        if [ $? -eq 0 ]; then
            log "Completado con éxito: $script"
        else
            log "Error al ejecutar: $script"
            exit 1
        fi
    else
        log "Advertencia: El script $script no existe en ${SCRIPTS_DIR}"
        return 1
    fi
}

# Verificar prerrequisitos
check_prerequisites() {
    log "Verificando prerrequisitos..."
    command -v mamba >/dev/null 2>&1 || { log "Error: mamba no está instalado."; exit 1; }
    # Agregar más verificaciones según sea necesario
}

# Función principal
main() {
    log "Iniciando pipeline de análisis genómico para Acinetobacter"
    
    check_prerequisites

    # Array de scripts a ejecutar
    scripts=(
        "preprocess.sh"
        "quick_coverage_calculation.sh"
        "paired_end_report.sh"
        "combine_reports.sh"
        "recommended_assemblies.sh"
        "execute_assemblies.sh"
        "quast_evaluation.sh"
        "checkm2.sh"
        "extract_acinetobacter_references.sh"
        "acinetobacter_fastani_analysis.sh"
        "run_resistance_analysis.sh"
        "run_bakta_annotation.sh"
    )

    # Ejecutar scripts
    for script in "${scripts[@]}"; do
        if ! run_script "$script"; then
            log "Error: Fallo en $script. Abortando pipeline."
            exit 1
        fi
    end

    # Limpieza final
    log "Realizando limpieza final..."
    find "${BASE_DIR}/data/trimmed/" -type f -name "*unpaired*.fastq.gz" -delete
    find "${BASE_DIR}/results/assembly_"* -type f \( -name "*.log" -o -name "*.gfa" -o -name "temp_*" \) -delete
    find "${BASE_DIR}/data" "${BASE_DIR}/results" -type d -empty -delete

    log "Pipeline completado con éxito."
}

# Ejecutar la función principal
main "$@"