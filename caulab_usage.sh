#!/usr/bin/env bash
set -euo pipefail

PIPELINES="${CAULAB_PIPELINES:-$(cd "$(dirname "$0")" && pwd -P)}"

cat <<EOF
CAULab core tools
=================

Pipeline root:
  $PIPELINES

Set this once per shell session after install:
  source "$PIPELINES/caulab.env"

Edit local paths here:
  "$PIPELINES/config/lab_paths.yaml"

Commands on PATH after sourcing caulab.env:
  Go_QC.sh
  Go_KBracken.sh
  Go_Humann.sh
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
  ./install_mac.sh --build-core

Apple Silicon fallback:
  ./install_mac.sh --build-core --platform linux/amd64


1. GoQC: raw FASTQ -> QC + host-filtered FASTQ
------------------------------------------------

Go_QC.sh \\
  -i /path/to/raw_fastq \\
  -o /path/to/output/ProjectA_QC \\
  -d /path/to/host_bowtie2_index_prefix \\
  -m goqc:caulab \\
  -c 8 \\
  -j 4 \\
  -K

Main output for downstream tools:
  /path/to/output/ProjectA_QC/host_filtered_fastq


2. KBracken: FASTQ -> Kraken2/Bracken taxonomic profiles
--------------------------------------------------------

Go_KBracken.sh \\
  -i /path/to/fastq_or_host_filtered_fastq \\
  -o /path/to/output/ProjectA_kbracken \\
  -d /path/to/kraken2_db \\
  -m kbracken:caulab \\
  -c 8 \\
  -j 4 \\
  -K

Kraken2-only mode:
  Go_KBracken.sh -i IN -o OUT -d DB --kraken-only -K


3. Humann: host-filtered FASTQ -> HUMAnN3 functional profiles
-------------------------------------------------------------

Go_Humann.sh \\
  -i /path/to/ProjectA_QC/host_filtered_fastq \\
  -o /path/to/output/ProjectA_humann \\
  -n /path/to/humann/chocophlan \\
  -p /path/to/humann/uniref \\
  -b /path/to/humann/metaphlan4 \\
  -I mpa_vJan25_CHOCOPhlAnSGB_202503 \\
  -m humann:caulab \\
  -c 8 \\
  -j 4 \\
  -t 4 \\
  -K


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
  "$PIPELINES/Humann/Go_Humann.sh"
  -> "$PIPELINES/Humann/Go_Humann.smk" if present
  -> "$PIPELINES/Humann/Go_Humann_V1.smk" otherwise
EOF
