#!/bin/bash

set -e  # Detiene el script si hay algún error

# Definir variables
GENOMES_DIR="./results/assembly/"
RESULTS_DIR="./results/resfinder_card"
MAMBA_PATH="/home/paula/conda/bin/mamba"
CARD_DB_DIR="/mnt/d/PC/card_db"

# Imprimir variables para diagnóstico
echo "GENOMES_DIR: $GENOMES_DIR"
echo "RESULTS_DIR: $RESULTS_DIR"
echo "MAMBA_PATH: $MAMBA_PATH"
echo "CARD_DB_DIR: $CARD_DB_DIR"

# Verificar que CARD_DB_DIR no esté vacío y exista
if [ -z "$CARD_DB_DIR" ] || [ ! -d "$CARD_DB_DIR" ]; then
    echo "Error: CARD_DB_DIR no está configurado correctamente o no existe."
    exit 1
fi

# Verificar y configurar la base de datos CARD
echo "Verificando la base de datos CARD..."
"$MAMBA_PATH" run -n rgi_env rgi load --card_json "$CARD_DB_DIR/card.json" --local
"$MAMBA_PATH" run -n rgi_env rgi database --version

# Función para procesar un genoma
process_genome() {
    local GENOME_DIR="$1"
    local GENOME_NAME=$(basename "$GENOME_DIR")
    local GENOME_PREFIX=$(echo "$GENOME_NAME" | cut -d'_' -f1)
    local GENOME_PATH=$(find "$GENOME_DIR" -name "*.fasta" -o -name "*.fa" | head -n 1)
    local OUTPUT_DIR="$RESULTS_DIR/$GENOME_NAME"
    
    echo "Procesando genoma: $GENOME_NAME"
    
    # Crear directorio de salida si no existe
    mkdir -p "$OUTPUT_DIR"
    
    # Filtrar contigs menores de 200 pb
    local FILTERED_GENOME="$OUTPUT_DIR/${GENOME_PREFIX}_filtered.fasta"
    echo "Filtrando contigs menores de 200 pb..."
    awk '/^>/ {if (seqlen>=200) print seq; print; seq=""; seqlen=0; next} {seq = seq $0; seqlen += length}END{if (seqlen>=200) print seq}' "$GENOME_PATH" > "$FILTERED_GENOME"
    
    # Ejecutar ResFinder
    echo "Ejecutando ResFinder para $GENOME_NAME"
    "$MAMBA_PATH" run -n resfinder_env python -m resfinder \
        -o "$OUTPUT_DIR/${GENOME_PREFIX}_resfinder_output" \
        -s "other" \
        --acquired \
        -ifa "$FILTERED_GENOME" \
        -db_res "/mnt/d/PC/resfinder_db/resfinder_db"
    
    # Ejecutar CARD (RGI)
    echo "Ejecutando CARD (RGI) para $GENOME_NAME"
    "$MAMBA_PATH" run -n rgi_env rgi main \
        --input_sequence "$FILTERED_GENOME" \
        --output_file "$OUTPUT_DIR/${GENOME_PREFIX}_card_output" \
        --local
    
    # Combinar resultados
    local RESFINDER_FILE="$OUTPUT_DIR/${GENOME_PREFIX}_resfinder_output/ResFinder_results_tab.txt"
    local CARD_FILE="$OUTPUT_DIR/${GENOME_PREFIX}_card_output.txt"
    local COMBINED_FILE="$OUTPUT_DIR/${GENOME_PREFIX}_combined_resistance_results.txt"
    
    # Procesar ResFinder
    awk 'BEGIN {FS=OFS="\t"}
        NR==1 {next}
        {
            split($6, contig_info, " ");
            contig = contig_info[1];
            split($7, pos, "\\.\\.");
            identity = sprintf("%.2f", $2);
            coverage = sprintf("%.2f", $4);
            key = contig "," pos[1] "," pos[2];
            data[key] = contig "\t" pos[1] "\t" pos[2] "\t" $1 "\t" identity "\t" $3 "\t" coverage "\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA";
        }
        END {
            for (key in data) {
                print data[key];
            }
        }
    ' "$RESFINDER_FILE" > "$COMBINED_FILE.tmp1"
    
    # Procesar CARD
    awk 'BEGIN {FS=OFS="\t"}
        NR==1 {next}
        {
            contig = $2;
            sub(/_[0-9]+$/, "", contig);  # Eliminar el ID único de CARD
            start = $3;
            end = $4;
            gene = $9;
            identity = $10;
            cutoff = $6;
            orientation = $5;
            snps_best_hit = $13;
            other_snps = $14;
            drug_class = $15;
            resistance_mechanism = $16;
            antibiotics = $NF;
            key = contig "," start "," end;
            data[key] = contig "\t" start "\t" end "\tNA\tNA\tNA\tNA\t" gene "\t" identity "\t" cutoff "\t" orientation "\t" snps_best_hit "\t" other_snps "\t" drug_class "\t" resistance_mechanism "\t" antibiotics;
        }
        END {
            for (key in data) {
                print data[key];
            }
        }
    ' "$CARD_FILE" > "$COMBINED_FILE.tmp2"
    
    # Combinar resultados
    echo -e "Contig\tBeginning\tEnd\tResFinder_Gene_name\tResFinder_Identity\tResFinder_Alignment_Length/Gene_Length\tResFinder_Coverage\tGene_name_CARD\tIdentity_CARD\tCARD_Cutoff\tCARD_Orientation\tCARD_SNPs_in_Best_Hit_ARO\tCARD_Other_SNPs\tCARD_Drug_Class\tCARD_Resistance_Mechanism\tCARD_Antibiotics" > "$COMBINED_FILE"
    
    awk 'BEGIN {FS=OFS="\t"}
        ARGIND==1 {
            key = $1 "," $2 "," $3;
            resfinder[key] = $0;
        }
        ARGIND==2 {
            key = $1 "," $2 "," $3;
            if (key in resfinder) {
                split(resfinder[key], r, "\t");
                if (r[4] != "NA" && $8 != "NA") {
                    print r[1], r[2], r[3], r[4], r[5], r[6], r[7], $8, $9, $10, $11, $12, $13, $14, $15, $16;
                } else if (r[4] != "NA") {
                    print resfinder[key];
                } else {
                    print $0;
                }
                delete resfinder[key];
            } else {
                print $0;
            }
        }
        END {
            for (key in resfinder) {
                print resfinder[key];
            }
        }
    ' "$COMBINED_FILE.tmp1" "$COMBINED_FILE.tmp2" | sort -t $'\t' -k1,1 -k2,2n >> "$COMBINED_FILE"
    
    # Limpiar archivos temporales
    rm "$COMBINED_FILE.tmp1" "$COMBINED_FILE.tmp2"
    
    # Eliminar archivos temporales innecesarios
    echo "Limpiando archivos temporales para $GENOME_NAME..."
    find "$OUTPUT_DIR" -type f -name "*.temp*" -delete
    find "$OUTPUT_DIR" -type f -name "*.draft" -delete
    find "$OUTPUT_DIR" -type f -name "*.db.*" -delete
    find "$OUTPUT_DIR" -type f -name "*.potentialGenes" -delete
    find "$OUTPUT_DIR" -type f -name "*.predictedGenes*" -delete
    find "$OUTPUT_DIR" -type f -name "*.rna" -delete
    find "$OUTPUT_DIR" -type f -name "*.homolog" -delete
    find "$OUTPUT_DIR" -type f -name "*.overexpression" -delete
    
    # Eliminar archivos anteriores
    rm -f "$OUTPUT_DIR/card_output.txt" "$OUTPUT_DIR/combined_resistance_results.txt"
    
    echo "Procesamiento completado para $GENOME_NAME"
}

# Procesar todos los genomas
for GENOME_DIR in "$GENOMES_DIR"/*; do
    if [ -d "$GENOME_DIR" ]; then
        process_genome "$GENOME_DIR"
    fi
done

echo "Proceso completado para todos los genomas."