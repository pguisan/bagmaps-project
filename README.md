# bagmaps
**B**ioinformatics **A**pplied to **G**enomic **M**apping of **A**ntibiotic resistant bacterial **P**athogens, active **S**urveillance and national studies

PhD candidate: Paula Guijarro-Sánchez. Xunta de Galicia Predoctoral Student Grant – IN606A- 2021/021

## Supervisors:

- Dr. Alejandro Beceiro Casas (SERGAS)
- Dr. Carlos Fernandez-Lozano (UDC)

# 🧬 Pipeline de Análisis Genómico para Acinetobacter

Pipeline completo y semi-automático para el análisis genómico de especies de Acinetobacter, procesando lecturas cortas (Illumina) y largas (Nanopore).

## 📋 Tabla de Contenidos

- [Visión General del Pipeline](#visión-general-del-pipeline)
- [Características Principales](#características-principales)
- [Estructura del Repositorio](#estructura-del-repositorio)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Uso](#uso)
- [Descripción Detallada de los Módulos](#descripción-detallada-de-los-módulos)
- [Personalización](#personalización)
- [Contribuciones](#contribuciones)

## 🔬 Visión General del Pipeline

El pipeline se divide en cuatro etapas principales:

1. **Preprocesamiento**: Limpieza y control de calidad de las lecturas.
2. **Análisis de cobertura y calidad**: Evaluación de la calidad de secuenciación y cálculo de cobertura.
3. **Ensamblaje**: Construcción y evaluación de genomas.
4. **Análisis comparativo**: Identificación taxonómica y análisis de resistencia.

## ✨ Características Principales 

- 🧹 Preprocesamiento de lecturas (Trimmomatic, Porechop)
- 🔍 Evaluación de calidad (FastQC)
- 📊 Cálculo de cobertura genómica
- 🧩 Ensamblaje de genomas (Unicycler, Dragonflye)
- 📈 Evaluación de ensamblajes (QUAST, CheckM2)
- 🔬 Análisis de similitud genómica (FastANI)
- 🧫 Identificación taxonómica (rMLST, ANI)
- 📝 Anotación genómica (Bakta)
- 💊 Análisis de resistencia antimicrobiana (ResFinder, CARD-RGI)
- 📄 Generación de informes detallados

## 🗂 Estructura del Repositorio 
```
bagmaps/
├── scripts/
│   ├── pipeline.sh
│   ├── preprocess.sh
│   ├── quick_coverage_calculation.sh
│   ├── paired_end_report.sh
│   ├── combine_reports.sh
│   ├── recommended_assemblies.sh
│   ├── execute_assemblies.sh
│   ├── quast_evaluation.sh
│   ├── checkm2.sh
│   ├── extract_acinetobacter_references.sh
│   ├── acinetobacter_fastani_analysis.sh
│   ├── run_resistance_analysis.sh
│   └── run_bakta_annotation.sh
├── results/
└── data/
    └── input/
```

## 🛠 Requisitos
- Bash
- Mamba/Conda
- Herramientas bioinformáticas: FastQC, Trimmomatic, Porechop, Unicycler, Dragonflye, QUAST, CheckM2, FastANI, Bakta, ResFinder, CARD-RGI
- Bases de datos actualizadas para Bakta, ResFinder y CARD

## 📦 Instalación

1. Clonar el repositorio:
```bash
git clone https://github.com/MALL-Machine-Learning-in-Live-Sciences/bagmaps.git
```

2. Instalar Mamba si aún no esta instalado:
```bash
conda install mamba -n base -c conda-forge
```

3. Crear entornos e instalar herramientas:
```bash
# Entorno para control de calidad y preprocesamiento
mamba create -n qc_env -c bioconda fastqc=0.11.9 trimmomatic=0.39 porechop=0.2.4

# Entornos para ensamblaje
mamba create -n unicycler_env -c bioconda unicycler=0.4.8
mamba create -n dragonflye_env -c bioconda dragonflye=1.0.12

# Entorno para evaluación de ensamblajes
mamba create -n quast_env -c bioconda quast=5.0.2

# Entorno para análisis de identidad de nucleótidos
mamba create -n fastani_env -c bioconda fastani=1.32

# Entornos para análisis de resistencia
mamba create -n resfinder_env -c bioconda resfinder=4.1.11
mamba create -n rgi_env -c bioconda rgi=5.2.1

# Entorno para anotación genómica
mamba create -n bakta_env -c bioconda bakta=1.5.1

4. Configuración de bases de datos:
   Para ResFinder, CARD y Bakta, asegúrese de descargar y configurar las bases de datos necesarias según las instrucciones oficiales de cada herramienta.
## 🚀 Uso

1. Coloque sus datos de secuenciación en la carpeta `data/input/`

2. Ejecute el pipeline completo:
```bash
bash scripts/pipeline.sh
```

3. Para ejecutar módulos específicos:
```bash
bash scripts/preprocess.sh
bash scripts/execute_assemblies.sh
bash scripts/run_resistance_analysis.sh
```
Cada script utiliza internamente `mamba run` para ejecutar las herramientas en el entorno apropiado, por lo que no es necesario activar los entornos manualmente.

## 📘 Descripción Detallada de los Módulos

### Preprocesamiento (preprocess.sh)
- Utiliza FastQC, Trimmomatic y Porechop
- Parámetros optimizados para lecturas cortas y largas
- Genera informes de calidad antes y después del preprocesamiento

### Análisis de Cobertura y Calidad
- Calcula la cobertura genómica (quick_coverage_calculation.sh)
- Genera informes de calidad de secuenciación (paired_end_report.sh)
- Combina los informes para una visión integral (combine_reports.sh)

### Ensamblaje
- Recomienda estrategias de ensamblaje (recommended_assemblies.sh)
- Ejecuta ensamblajes con Unicycler o Dragonflye (execute_assemblies.sh)
- Evalúa la calidad de los ensamblajes con QUAST y CheckM2

### Análisis Comparativo
- Extrae referencias de Acinetobacter (extract_acinetobacter_references.sh)
- Realiza análisis de ANI con FastANI (acinetobacter_fastani_analysis.sh)
- Identifica genes de resistencia con ResFinder y CARD-RGI (run_resistance_analysis.sh)
- Anota genomas con Bakta (run_bakta_annotation.sh)

## ⚙️ Personalización
Revise los scripts individuales para ajustar parámetros específicos como tamaño del genoma, umbrales de calidad, etc.

## 👥 Contribuciones
¡Contribuciones son bienvenidas! Por favor, abra un issue para discutir cambios mayores.
