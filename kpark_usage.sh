#!/usr/bin/env bash
set -euo pipefail

PIPELINES="${KPARK_PIPELINES:-$(cd "$(dirname "$0")" && pwd -P)}"

cat <<EOF
K-park Lab pipeline tools
=================

Pipeline root:
  $PIPELINES

Set this once per shell session after install:
  source "$PIPELINES/kpark.env"

Edit local paths here:
  "$PIPELINES/config/lab_paths.sh"

Database variables loaded from lab_paths.sh:
  KPARK_HOST_BT2_PREFIX
  KPARK_KRAKEN2_DB
  KPARK_HUMANN_CHOCOPHLAN
  KPARK_HUMANN_UNIREF
  KPARK_HUMANN_METAPHLAN
  KPARK_HUMANN_UTILITY
  KPARK_METAPHLAN_INDEX

Commands on PATH after sourcing kpark.env:
  Go_QC.sh
  Go_KBracken.sh
  Go_Humannake.sh
  Go_longWGS.sh
  Go_shortWGS.sh
  Go_Rnake.sh
  Go_daDake2.sh
  Go_MAGs_QC.sh
  Go_MAGs_Assembly.sh
  Go_MAGs_Annotation.sh
  Go_container_image.sh
  download_databases.sh
  kpark_usage.sh

Docker images:
  goqc:kpark
  kbracken:kpark
  humann:kpark

Check whether images exist locally:
  docker image inspect goqc:kpark kbracken:kpark humann:kpark >/dev/null

List K-park Lab images:
  docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^(goqc|kbracken|humann):kpark$'

Build all three images during install:
  ./install_docker_env.sh --build-core

Build the complete container family:
  ./install_docker_env.sh --build-all

Extended pipeline usage:
  See "$PIPELINES/docs/index.html" and each pipeline README.
  Container launchers accept --container docker|apptainer and --container-image IMAGE_OR_SIF.
  GoQC is Docker-only; daDake2 requires the host Snakemake/R/DADA2/FIGARO environment.
  New pipelines require explicit database/reference flags.

Apple Silicon fallback:
  ./install_docker_env.sh --build-core --platform linux/amd64

Download reference databases:
  download_databases.sh --db-root $HOME/kpark-db --tools host --threads 8
  download_databases.sh --db-root $HOME/kpark-db --tools kraken2 --threads 8
  download_databases.sh --db-root $HOME/kpark-db --tools humann --threads 8

Defaults:
  host    = CHM13/T2T Bowtie2 index
  kraken2 = latest k2_pluspfp_16gb_YYYYMMDD prebuilt DB
  humann  = ChocoPhlAn full + UniRef90 Diamond + MetaPhlAn DB

Download all reference databases:
  download_databases.sh --db-root $HOME/kpark-db --tools all --threads 8

After download, reload paths:
  source "$PIPELINES/kpark.env"


1. GoQC: raw FASTQ -> QC + host-filtered FASTQ
------------------------------------------------

Go_QC.sh \\
  -i /path/to/raw_fastq \\
  -o /path/to/output/ProjectA_QC \\
  -c 8 \\
  -j 4 \\
  -K

Explicit DB override:
  Go_QC.sh -i IN -o OUT -d /path/to/host_bowtie2_index_prefix -K

Main output for downstream tools:
  /path/to/output/ProjectA_QC/host_filtered_fastq


2. KBracken: FASTQ -> Kraken2/Bracken taxonomic profiles
--------------------------------------------------------

Go_KBracken.sh \\
  -i /path/to/fastq_or_host_filtered_fastq \\
  -o /path/to/output/ProjectA_kbracken \\
  -c 8 \\
  -j 4 \\
  -K

Explicit DB override:
  Go_KBracken.sh -i IN -o OUT -d /path/to/kraken2_db -K

Kraken2-only mode:
  Go_KBracken.sh -i IN -o OUT --kraken-only -K


3. Humannake: host-filtered FASTQ -> HUMAnN3 functional profiles
-------------------------------------------------------------

Go_Humannake.sh \\
  -i /path/to/ProjectA_QC/host_filtered_fastq \\
  -o /path/to/output/ProjectA_humann \\
  -c 8 \\
  -j 4 \\
  -t 4 \\
  -K

Explicit DB override:
  Go_Humannake.sh -i IN -o OUT -n /path/to/chocophlan -p /path/to/uniref -b /path/to/metaphlan4 -I mpa_index -K


Typical order
-------------

1) GoQC on raw paired FASTQs.
2) Humannake on GoQC host_filtered_fastq.
3) KBracken on raw FASTQ or host_filtered_fastq, depending on the analysis policy.


Wrapper-to-Snakefile mapping
----------------------------

GoQC:
  "$PIPELINES/GoQC/Go_QC.sh"
  -> "$PIPELINES/GoQC/Go_QC.smk" if present
  -> "$PIPELINES/GoQC/Go_QC_V1.smk" otherwise

KBracken:
  "$PIPELINES/KBracken/Go_KBracken.sh"
  -> "$PIPELINES/KBracken/Go_KBracken.smk" if present
  -> "$PIPELINES/KBracken/Go_KBracken_V1.smk" otherwise

Humannake:
  "$PIPELINES/Humannake/Go_Humannake.sh"
  -> "$PIPELINES/Humannake/Go_Humann.smk" if present
  -> "$PIPELINES/Humannake/Go_Humann_V1.smk" otherwise
EOF
