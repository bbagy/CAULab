# Humannake

![HUMAnN3](https://img.shields.io/badge/Profiler-HUMAnN3-e67e22)
![Workflow](https://img.shields.io/badge/Workflow-Snakemake-039be5)
![Container](https://img.shields.io/badge/Runtime-Docker-0db7ed)
![Status](https://img.shields.io/badge/Status-Available-2e7d32)

Shotgun metagenome functional profiling workflow using HUMAnN3 + MetaPhlAn4 with optional MUSiCC correction, gene-family normalization, and KEGG orthology regrouping.

## Current Entrypoints

- Wrapper: `Go_Humannake.sh`
- Snakefile (current): `Go_Humann_V1.smk`
- Auxiliary scripts:
  - `scripts/humann_masterlog.py`: merges per-sample HUMAnN logs into `humann3_log.txt`
- Helper examples:
  - `check_humann_logs_example.sh`
  - `run_humann_retry_example.sh`

## Pipeline

```mermaid
flowchart LR
  A[host-filtered FASTQ] --> B[Prefilter + R1/R2 merge]
  B --> C[HUMAnN3 per-sample run]
  C --> D[MetaPhlAn4 bug list extraction]
  C --> E[merge_genefamilies / pathabundance / pathcoverage]
  E --> F[Gene-family normalization CPM]
  F --> G[Regroup to KO]
  G --> H[Optional MUSiCC correction]
  H --> I[Rename to KEGG orthology]
  I --> J[Stratified / unstratified split]
```

## Requirements

- Docker
- Linux shell
- Host-filtered FASTQ files (single-end, paired-end, or `_nohuman` outputs from KneadData / host removal)
- HUMAnN3 reference DBs:
  - `chocophlan/` nucleotide DB
  - `uniref/` protein DB
- MetaPhlAn4 DB directory + index basename (e.g. `mpa_vJun23_CHOCOPhlAnSGB_202307`)

## Build

```bash
cd Humann
docker build --network=host -t humann:kpark .
```

The wrapper defaults to image `humann:kpark`; override with `-m <tag>` if needed.

## Docker Tool Inventory

Representative tools in the image:

- `snakemake`
- `humann` (HUMAnN3 toolchain: `humann`, `humann_renorm_table`, `humann_regroup_table`, `humann_rename_table`, `humann_join_tables`, `humann_split_stratified_table`)
- `metaphlan` (MetaPhlAn4)
- `musicc` (optional correction)
- supporting Python utilities for log merging

## Run A Single Tool From The Image

```bash
docker run --rm humann:kpark snakemake --version
docker run --rm humann:kpark humann --version
docker run --rm humann:kpark metaphlan --version
```

## Quick Start

```bash
./Humann/Go_Humannake.sh \
  -i /path/to/host_filtered_fastq \
  -o humann_run \
  -n "$HOME/kpark-db/humann/chocophlan" \
  -p "$HOME/kpark-db/humann/uniref90_diamond" \
  -u "$HOME/kpark-db/humann/utility_mapping" \
  -b "$HOME/kpark-db/humann/metaphlan4" \
  -I mpa_vJun23_CHOCOPhlAnSGB_202307 \
  -c 8 -j 4 -t 4 \
  -K
```

Real example:

```bash
Go_Humannake.sh \
  -i 1_host_filtered \
  -o 2_humann_out \
  -n "$HOME/kpark-db/humann/chocophlan" \
  -p "$HOME/kpark-db/humann/uniref90_diamond" \
  -u "$HOME/kpark-db/humann/utility_mapping" \
  -b "$HOME/kpark-db/humann/metaphlan4" \
  -I mpa_vJun23_CHOCOPhlAnSGB_202307 \
  -s "$HOME/kpark-pipelines/Humann" \
  -c 8 -j 4 -t 4 \
  -K
```

## Options (`Go_Humannake.sh`)

| Flag | Default | Description |
|---|---:|---|
| `-i` | - | Input FASTQ directory (host-filtered reads) |
| `-o` | - | Output directory |
| `-n` | - | HUMAnN3 nucleotide DB (`chocophlan`) |
| `-p` | - | HUMAnN3 protein DB (`uniref`) |
| `-b` | - | MetaPhlAn4 DB directory (or `.pkl` for legacy shortcut) |
| `-I` / `--metaphlan-index` | - | MetaPhlAn4 index basename (without `.pkl`) |
| `-u` | `KPARK_HUMANN_UTILITY` | Utility mapping DB directory for UniRef90/50 → KO |
| `-s` | script directory | Optional Snakefile directory override |
| `-c` | `8` | Snakemake cores |
| `-j` | `4` | Snakemake jobs |
| `-t` | `4` | HUMAnN threads per sample |
| `-m` | `humann:kpark` | Docker image tag |
| `-x` | off | Dry-run (`--dry-run`) |
| `-K` | off | Keep going (`--keep-going`) |
| `--run-musicc` | off | Enable MUSiCC correction on regrouped KO table |
| `--skip-gene-norm` | off | Skip gene-family normalization step |
| `--skip-path-split` | off | Skip pathway split (stratified/unstratified) |
| `--skip-pathcoverage` | off | Skip pathcoverage merge |

## Workstation Layout

After `Go_toWorkstation.sh Humann`, files are placed as:

```text
/home/uhlemann*/heekuk_path/
  Go_Humannake.sh
  Go_Humann.smk
  scripts/
    humann_masterlog.py
  docker/Humann/
    Dockerfile
```

## Input Layout

Supported FASTQ naming:

- Single-end / pre-merged: `<sample>.fastq.gz`, `<sample>.fq.gz`, `<sample>.fastq`, `<sample>.fq`
- Paired: `<sample>_R1.fastq.gz` / `<sample>_R2.fastq.gz` (auto-merged into `7_intermediate/<sample>.merged.fastq.gz`)
- Host-filtered paired: `<sample>_R1_nohuman.fastq.gz` / `<sample>_R2_nohuman.fastq.gz`

Each detected FASTQ unit is processed as one HUMAnN job.

## Output Layout

```text
OUT/
  1_humann3_out/
    <sample>_genefamilies.tsv
    <sample>_pathabundance.tsv
    <sample>_pathcoverage.tsv
    <sample>.humann.done
  2_humann3_final_out/
    merged_genefamilies.txt
    merged_pathabundance.txt
    merged_pathcoverage.txt
  3_MetaPhlAn_bug_list/
    <sample>_metaphlan_bugs_list.tsv
  4_kegg-orthology/
    merged_genefamilies_cpm.txt
    merged_genefamilies_uniref90_ko_cpm.txt
    merged_genefamilies_uniref90_ko_musicc.txt
    merged_genefamilies_uniref90_ko_kegg-orthology_cpm.txt
    stratified_out/
      merged_genefamilies_uniref90_ko_kegg-orthology_cpm_unstratified.txt
      merged_genefamilies_uniref90_ko_kegg-orthology_cpm_unstratified_filtered.txt
  5_pathabundance_stratified_out/
    merged_pathabundance_unstratified.txt
  6_logs/
    *.log
  7_intermediate/
    <sample>.merged.fastq.gz
    <sample>.input.done
  humann3_log.txt
```

Key files:

- `2_humann3_final_out/merged_genefamilies.txt`
- `2_humann3_final_out/merged_pathabundance.txt`
- `3_MetaPhlAn_bug_list/<sample>_metaphlan_bugs_list.tsv`
- `4_kegg-orthology/merged_genefamilies_uniref90_ko_kegg-orthology_cpm.txt`
- `humann3_log.txt`

## Direct Snakemake Run (no wrapper)

```bash
fastq_dir="host_filtered_fastq"
output_dir="humann_run"
chocophlan=""$HOME/kpark-db/humann/chocophlan""
uniref=""$HOME/kpark-db/humann/uniref90_diamond""
metaphlan_db=""$HOME/kpark-db/humann/metaphlan4""
metaphlan_index="mpa_vJun23_CHOCOPhlAnSGB_202307"

snakemake --snakefile "$HOME/kpark-pipelines/Humann"/Go_Humann.smk \
  --config \
  fastq_dir="$fastq_dir" \
  output_dir="$output_dir" \
  nucleotide_db="$chocophlan" \
  protein_db="$uniref" \
  metaphlan_db="$metaphlan_db" \
  metaphlan_index="$metaphlan_index" \
  run_musicc=true \
  humann_threads=4 \
  --cores 8 --jobs 4 \
  --latency-wait 60 --rerun-incomplete
```

## Useful Configs

```bash
--config \
  fastq_dir=host_filtered_fastq \
  output_dir=humann_run \
  nucleotide_db=/path/to/chocophlan \
  protein_db=/path/to/uniref \
  metaphlan_db=/path/to/metaphlan_db \
  metaphlan_index=mpa_vJun23_CHOCOPhlAnSGB_202307 \
  run_musicc=false \
  humann_threads=4 \
  run_gene_norm=true \
  run_path_split=true \
  run_pathcoverage_merge=true
```

## Operational Notes

- Recommended MetaPhlAn input is `-b <metaphlan_db_dir>` plus `-I <index_basename>`.
- `Go_Humannake.sh` also accepts a `.pkl` path via `-b` and auto-converts it to directory + index for backward compatibility.
- Input discovery is intentionally simple: every `*.fastq`, `*.fq`, `*.fastq.gz`, `*.fq.gz` is treated as one HUMAnN input unit.
- Paired inputs (`_R1` / `_R2` or `_R1_nohuman` / `_R2_nohuman`) are merged per sample into `7_intermediate/<sample>.merged.fastq.gz` before HUMAnN.
- Per-sample `.humann.done` markers let interrupted runs resume cleanly.
- `MetaPhlAn_bug_list` files are extracted from `{sample}_humann_temp/` before that temp directory is removed.
- Output directories are numbered in run order (`1_` through `7_`).
- `--run-musicc` enables MUSiCC correction on the regrouped KO table before `humann_rename_table`.
- `--skip-gene-norm` is useful if only raw HUMAnN tables are needed.
- `--skip-path-split` is useful when stratified split is not needed for the current project.
- Lock errors are auto-handled by the wrapper (`--unlock` then retry).

## Common Runs

Dry-run:

```bash
./Humann/Go_Humannake.sh -i IN -o OUT -n CHOCO -p UNIREF -b MPA -I mpa_index -x
```

Production run with MUSiCC:

```bash
./Humann/Go_Humannake.sh -i IN -o OUT -n CHOCO -p UNIREF -b MPA -I mpa_index --run-musicc -K
```

Skip normalization (raw HUMAnN tables only):

```bash
./Humann/Go_Humannake.sh -i IN -o OUT -n CHOCO -p UNIREF -b MPA -I mpa_index --skip-gene-norm -K
```

## Troubleshooting

- `Docker image not found locally: humann:kpark`
  - build with `docker build -t humann:kpark Humann`
- MetaPhlAn DB errors mentioning `mpa_*.pkl` not found
  - pass `-b <dir>` and `-I <index_basename>`, not the `.pkl` itself (or use the legacy `.pkl` shortcut)
- Lock-related failure in `humann.log`
  - wrapper retries with `--unlock` automatically; if it persists, remove `.snakemake/locks/` manually
- HUMAnN exits with `chocophlan / uniref not found`
  - confirm the DBs exist under the directories passed to `-n` and `-p`
- Want only Kraken/Bracken profiling instead
  - use `KBracken` pipeline (separate)

## Maintainer

Heekuk Park

## Container runtime

Shell launchers accept `--container docker|apptainer` (default: `docker`).
For HPC use `--container apptainer --container-image /path/to/pipeline.sif`
with the existing analysis options. See [shared runtime instructions](../README.md#docker--apptainer-selection)
for SIF preparation and deployment of `common/container.sh`.

## Database compatibility

HUMAnN 3.9 / MetaPhlAn 4.1.0: `mpa_vJun23_CHOCOPhlAnSGB_202307`.
The downloader pins this index. Existing installations retain local settings; rerun the downloader or update the index explicitly.
Reference: [HUMAnN 3.9 release](https://forum.biobakery.org/t/announcing-humann-3-9/6674).

KO tables require `utility_mapping/full`. Existing installs can download only this DB with `download_databases.sh --db-root "$HOME/kpark-db" --tools humann-utility`. Source `config/lab_paths.sh` again. UniRef50 uses `uniref50_ko` output names. With `--run-musicc`, only community-level KO rows are corrected, and renamed output filenames use `musicc` instead of `cpm`.
