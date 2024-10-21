# bagmaps
**B**ioinformatics **A**pplied to **G**enomic **M**apping of **A**ntibiotic resistant bacterial **P**athogens, active **S**urveillance and national studies

## 🎓 Doctoral Thesis Project

This project is part of a doctoral thesis in bioinformatics focused on the analysis of antibiotic resistance in pathogenic bacteria.

👩‍🔬 **PhD candidate**: Paula Guijarro-Sánchez
🏆 Xunta de Galicia Predoctoral Student Grant – IN606A- 2021/021

### 👥 Supervisors:

- 🩺 Dr. Alejandro Beceiro Casas (SERGAS)
- 💻 Dr. Carlos Fernandez-Lozano (UDC)

## 🏆 Featured Publication

The results obtained with this pipeline have been published in a prestigious scientific journal:

📚 **Journal**: Eurosurveillance (D1 in Epidemiology)
🔗 **DOI**: 10.2807/1560-7917.ES.2024.29.15.2300352
👩‍🔬 **Co-first author**: Paula Guijarro-Sánchez

This publication highlights the importance and impact of the work carried out, validating the effectiveness of the pipeline developed for the analysis of antibiotic resistance in Acinetobacter species.

## 🎯 Purpose of the Analysis

Complete and semi-automatic pipeline for genomic analysis of Acinetobacter species, processing short (Illumina) and long (Nanopore) reads. The pipeline evaluates depth, coverage, and quality to automatically select the best assembly method among various options from both Unicycler and Dragonflye. This selection is optimized based on the input data type:

-Short reads only (Illumina)
-Long reads only (Nanopore)
-Hybrid approach (both Illumina and Nanopore)

This adaptive approach ensures the most appropriate assembly strategy is employed for each dataset, optimizing the quality and completeness of the resulting genomic assemblies.

## 📋 Table of Contents

Pipeline Overview
Main Features
Repository Structure
Requirements
Installation
Usage
Detailed Module Description
Customization
Contributions

## 🔬 Pipeline Overview

The pipeline is divided into four main stages:

1. **Preprocessing**: Cleaning and quality control of reads.
2. **Coverage and quality analysis**: Evaluation of sequencing quality and coverage calculation.
3. **Assembly**: Genome construction and evaluation.
4. **Comparative analysis**: Taxonomic identification and resistance analysis.

## ✨ Main Features

🧹 Read preprocessing (Trimmomatic, Porechop)
🔍 Quality assessment (FastQC)
📊 Genomic coverage calculation
🧩 Genome assembly (Unicycler, Dragonflye)
📈 Assembly evaluation (QUAST, CheckM2)
🔬 Genomic similarity analysis (FastANI)
🧫 Taxonomic identification (rMLST, ANI)
📝 Genomic annotation (Bakta)
💊 Antimicrobial resistance analysis (ResFinder, CARD-RGI)
📄 Generation of detailed reports

## 🗂 Repository Structure
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

## 🛠 Requirements
-Bash
-Mamba/Conda
-Bioinformatics tools: FastQC, Trimmomatic, Porechop, Unicycler, Dragonflye, QUAST, CheckM2, FastANI, Bakta, ResFinder, CARD-RGI
-Updated databases for Bakta, ResFinder, and CARD

## 📦 Installation

1. Clone the repository:
```bash
git clone https://github.com/MALL-Machine-Learning-in-Live-Sciences/bagmaps.git
```

2. Install Mamba if not already installed:
```bash
conda install mamba -n base -c conda-forge
```

3. Create environments and install tools:
```bash
# Environment for quality control and preprocessing
mamba create -n qc_env -c bioconda fastqc=0.11.9 trimmomatic=0.39 porechop=0.2.4

# Environments for assembly
mamba create -n unicycler_env -c bioconda unicycler=0.4.8
mamba create -n dragonflye_env -c bioconda dragonflye=1.0.12

# Environment for assembly evaluation
mamba create -n quast_env -c bioconda quast=5.0.2

# Environment for nucleotide identity analysis
mamba create -n fastani_env -c bioconda fastani=1.32

# Environments for resistance analysis
mamba create -n resfinder_env -c bioconda resfinder=4.1.11
mamba create -n rgi_env -c bioconda rgi=5.2.1

# Environment for genomic annotation
mamba create -n bakta_env -c bioconda bakta=1.5.1

4. Database configuration:
For ResFinder, CARD, and Bakta, make sure to download and configure the necessary databases according to the official instructions for each tool.

## 🚀 Usage

1. Place your sequencing data in the `data/input/` folder

2. Run the complete pipeline:
```bash
bash scripts/pipeline.sh
```

3. To run specific modules:
```bash
bash scripts/preprocess.sh
bash scripts/execute_assemblies.sh
bash scripts/run_resistance_analysis.sh
```
Each script internally uses mamba run to execute the tools in the appropriate environment, so it's not necessary to manually activate the environments.

## 📘 Detailed Module Description

### Preprocessing (preprocess.sh)
-Uses FastQC, Trimmomatic, and Porechop
-Optimized parameters for short and long reads
-Generates quality reports before and after preprocessing

### Coverage and Quality Analysis

-Calculates genomic coverage (quick_coverage_calculation.sh)
-Generates sequencing quality reports (paired_end_report.sh)
-Combines reports for a comprehensive view (combine_reports.sh)

### Assembly

-Recommends assembly strategies (recommended_assemblies.sh)
-Executes assemblies with Unicycler or Dragonflye (execute_assemblies.sh)
-Evaluates assembly quality with QUAST and CheckM2

### Comparative Analysis

-Extracts Acinetobacter references (extract_acinetobacter_references.sh)
-Performs ANI analysis with FastANI (acinetobacter_fastani_analysis.sh)
-Identifies resistance genes with ResFinder and CARD-RGI (run_resistance_analysis.sh)
-Annotates genomes with Bakta (run_bakta_annotation.sh)

## ⚙️ Customization
Review individual scripts to adjust specific parameters such as genome size, quality thresholds, etc.

## 👥 Contributions
Contributions are welcome! Please open an issue to discuss major changes.
