# CAULab Installation Notes

The CAULab copy is intended to be path-neutral. Do not hard-code workstation paths inside Snakefiles. Keep lab-specific DB paths in `config/lab_paths.sh`; wrapper scripts use those values by default and still allow command-line overrides.

## General Mac Install

Install into the current user's home directory:

```bash
cd /path/to/CAULab
./install_mac.sh --build-core
source "$HOME/caulab-pipelines/caulab.env"
open "$HOME/caulab-pipelines/config/lab_paths.sh"
```

If the install directory already exists, use it:

```bash
source "$HOME/caulab-pipelines/caulab.env"
caulab_usage.sh
```

Update an existing install from a refreshed clone:

```bash
cd /path/to/CAULab
git pull
./install_mac.sh --update --build-core
source "$HOME/caulab-pipelines/caulab.env"
```

`--update` refreshes installed wrapper scripts (`Go_QC.sh`, `Go_KBracken.sh`, `Go_Humann.sh`), Snakefiles, Dockerfiles, helper scripts, and `bin/` links while preserving `config/lab_paths.sh` and `config/lab_paths.yaml`.

If Docker images are missing, first start Docker Desktop, then rerun:

```bash
./install_mac.sh --update --build-core
docker image inspect goqc:caulab kbracken:caulab humann:caulab >/dev/null
```

If a container fails with `failed to launch x86-64-v3 version`, rebuild after updating CAULab:

```bash
git pull
./install_mac.sh --update --build-goqc --no-cache
```

GoQC no longer uses conda/micromamba, which avoids conda-forge CPU variant launch errors on older Intel Macs and amd64 emulation.

If GoQC build stops at `apt-get update`, first check Docker network access:

```bash
docker pull python:3.11-slim-bookworm
docker run --rm python:3.11-slim-bookworm bash -lc "apt-get update"
```

If those commands fail too, the problem is Docker Desktop network/DNS/proxy access rather than CAULab code.

For Apple Silicon Mac, if the normal Docker build fails while solving Bioconda packages:

```bash
cd /path/to/CAULab
./install_mac.sh --build-core --platform linux/amd64
source "$HOME/caulab-pipelines/caulab.env"
```

Install somewhere else:

```bash
./install_mac.sh --prefix /Volumes/Analysis/caulab-pipelines --build-core
source /Volumes/Analysis/caulab-pipelines/caulab.env
```

After install, edit:

```bash
$CAULAB_PIPELINES/config/lab_paths.sh
```

Print command examples:

```bash
caulab_usage.sh
```

## Recommended Layout

```text
$HOME/caulab-pipelines/
  bin/
    Go_QC.sh
    Go_KBracken.sh
    Go_Humann.sh
    caulab_usage.sh
  GoQC/
  KBracken/
  Humann/
  config/lab_paths.yaml
  caulab_usage.sh
```

Any install root is valid. The important rule is that data and database paths are provided at run time.
Database paths can be provided once through `config/lab_paths.sh`.

## Docker Build on Mac

If not using `install_mac.sh --build-core`, build the core images manually:

```bash
cd "$CAULAB_PIPELINES/GoQC"
docker build -t goqc:caulab .
cd "$CAULAB_PIPELINES/KBracken"
docker build -t kbracken:caulab .
cd "$CAULAB_PIPELINES/Humann"
docker build -t humann:caulab .
```

On Apple Silicon Mac, if Bioconda cannot solve packages for `linux/arm64`, use amd64 emulation:

```bash
cd "$CAULAB_PIPELINES/GoQC"
docker build --platform linux/amd64 -t goqc:caulab .
cd "$CAULAB_PIPELINES/KBracken"
docker build --platform linux/amd64 -t kbracken:caulab .
cd "$CAULAB_PIPELINES/Humann"
docker build --platform linux/amd64 -t humann:caulab .
export DOCKER_PLATFORM=linux/amd64
```

## Examples

First edit DB paths once on each workstation:

```bash
open "$CAULAB_PIPELINES/config/lab_paths.sh"
source "$CAULAB_PIPELINES/caulab.env"
```

Then normal commands can be short:

```bash
Go_QC.sh \
  -i /data/projects/ProjectA/fastq \
  -o ProjectA_QC \
  -K

Go_Humann.sh \
  -i ProjectA_QC/host_filtered_fastq \
  -o ProjectA_humann \
  -K

Go_KBracken.sh \
  -i ProjectA_QC/host_filtered_fastq \
  -o ProjectA_kbracken \
  -K
```

To override the configured DB paths for one run:

```bash
Go_QC.sh -i IN -o OUT -d /path/to/host_bowtie2_index_prefix -K
Go_KBracken.sh -i IN -o OUT -d /path/to/kraken2_db -K
Go_Humann.sh -i IN -o OUT -n /path/to/chocophlan -p /path/to/uniref -b /path/to/metaphlan4 -I mpa_index -K
```

GoQC host DB policy:

```bash
download_databases.sh --db-root /Volumes/CAULabDB --tools host
```

The default host Bowtie2 index is CHM13/T2T (`chm13v2.0`). To override it for one workstation:

```bash
download_databases.sh \
  --db-root /Volumes/CAULabDB \
  --tools host \
  --host-index-name GRCh38_noalt_as \
  --host-index-url https://genome-idx.s3.amazonaws.com/bt/GRCh38_noalt_as.zip
```

Kraken2 DB policy:

```bash
download_databases.sh --db-root /Volumes/CAULabDB --tools kraken2 --threads 8
```

This downloads the latest available prebuilt `k2_pluspfp_16gb_YYYYMMDD` database from the Kraken2 AWS index and builds the Bracken kmer file locally. To choose a different 16GB family:

```bash
download_databases.sh --db-root /Volumes/CAULabDB --tools kraken2 --kraken2-16gb k2_standard_16gb --threads 8
```

`source "$CAULAB_PIPELINES/caulab.env"` adds `$CAULAB_PIPELINES/bin` to `PATH`, so the three wrappers can be run from any working directory.

`GoQC/Go_QC.sh` follows the same structure as `KBracken/Go_KBracken.sh`: the wrapper lives next to its Dockerfile and versioned Snakefile, and it resolves `Go_QC.smk` first, then `Go_QC_V1.smk`.

`Humann/Go_Humann.sh` follows the same structure: the wrapper lives next to `Dockerfile` and `Go_Humann_V1.smk`, and it resolves `Go_Humann.smk` first, then `Go_Humann_V1.smk`.

## Path Rules

- Use absolute host paths for FASTQ and DB inputs.
- Wrapper scripts mount host paths into containers as stable internal paths such as `/fastq`, `/db`, `/pipeline`, and `/report_assets`.
- Reference databases are not versioned in this repository.
- Local DB paths are loaded from `config/lab_paths.sh` after `source "$CAULAB_PIPELINES/caulab.env"`.
- Keep generated outputs outside the pipeline install root.
- Avoid workstation names, user home directories, and lab names inside Snakefiles.
