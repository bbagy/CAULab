#!/usr/bin/env bash
set -euo pipefail

PIPELINES="${CAULAB_PIPELINES:-$(cd "$(dirname "$0")" && pwd -P)}"

cat <<EOF
CAULab pipeline tools
=================

Pipeline root:
  $PIPELINES

Set this once per shell session after install:
  source "$PIPELINES/caulab.env"

Edit local paths here:
  "$PIPELINES/config/lab_paths.sh"

Database variables loaded from lab_paths.sh:
  CAULAB_HOST_BT2_PREFIX
  CAULAB_KRAKEN2_DB
  CAULAB_HUMANN_CHOCOPHLAN
  CAULAB_HUMANN_UNIREF
  CAULAB_HUMANN_METAPHLAN
  CAULAB_METAPHLAN_INDEX

Commands on PATH after sourcing caulab.env:
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
  caulab_usage.sh

Docker images:
  goqc:caulab
  kbracken:caulab
  humann:caulab

Check whether images exist locally:
  docker image inspect goqc:caulab kbracken:caulab humann:caulab >/dev/null

List CAULab images:
  docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^(goqc|kbracken|humann):caulab$'

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
  download_databases.sh --db-root $HOME/caulab-db --tools host --threads 8
  download_databases.sh --db-root $HOME/caulab-db --tools kraken2 --threads 8
  download_databases.sh --db-root $HOME/caulab-db --tools humann --threads 8

Defaults:
  host    = CHM13/T2T Bowtie2 index
  kraken2 = latest k2_pluspfp_16gb_YYYYMMDD prebuilt DB
  humann  = ChocoPhlAn full + UniRef90 Diamond + MetaPhlAn DB

Download all reference databases:
  download_databases.sh --db-root $HOME/caulab-db --tools all --threads 8

After download, reload paths:
  source "$PIPELINES/caulab.env"


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


3. Humann: host-filtered FASTQ -> HUMAnN3 functional profiles
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
2) Humann on GoQC host_filtered_fastq.
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

Humann:
  "$PIPELINES/Humann/Go_Humannake.sh"
  -> "$PIPELINES/Humann/Go_Humann.smk" if present
  -> "$PIPELINES/Humann/Go_Humann_V1.smk" otherwise
EOF
