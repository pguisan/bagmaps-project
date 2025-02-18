#!/bin/bash

# Paso 1: Preprocesamiento de lecturas
echo "Paso 1: Preprocesamiento de lecturas"
./preprocess.sh

# Paso 2: Alineamiento de lecturas al genoma de referencia
echo "Paso 2: Alineamiento de lecturas"
./align.sh

# Paso 3: Generación de reportes de calidad y cobertura
echo "Paso 3: Generación de reportes"
./quick_coverage_calculation.sh
./paired_end_report.sh

# Paso 4: Combinación de reportes y recomendación de ensamblajes
echo "Paso 4: Combinación de reportes y recomendación de ensamblajes"
./combine_reports.sh
./recommended_assemblies.sh

# Paso 5: Ejecución de ensamblajes
echo "Paso 5: Ejecución de ensamblajes"
./execute_assemblies.sh

# Paso 6: Identificación especies
echo "Paso 6: Identificación especies"
./extract_species_info.sh
./acinetobacter_analysis_representative.sh

# Paso 7: Limpieza extendida de archivos intermedios
echo "Paso 7: Limpieza extendida de archivos intermedios"
echo "Limpiando archivos intermedios..."

# Eliminar archivos BAM y BAI
find ../data/aligned/ -type f \( -name "*.bam" -o -name "*.bai" \) -delete

# Eliminar archivos de cobertura
find ../data/aligned/ -type f -name "*.coverage" -delete

# Eliminar archivos de lecturas no pareadas generados por Trimmomatic
find ../data/trimmed/ -type f -name "*unpaired*.fastq.gz" -delete

# Eliminar archivos temporales de ensamblaje (si los hay)
find ../results/assembly_* -type f \( -name "*.log" -o -name "*.gfa" -o -name "temp_*" \) -delete

# Eliminar directorios vacíos
find ../data ../results -type d -empty -delete

echo "Limpieza extendida completada."

echo "Pipeline completado."