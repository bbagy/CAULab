# K-park Lab Installation Notes

The K-park Lab copy is intended to be path-neutral. Do not hard-code workstation paths inside Snakefiles. Keep lab-specific DB paths in `config/lab_paths.sh`; wrapper scripts use those values by default and still allow command-line overrides.

## Ubuntu Server Install

Install Git and Docker Engine before running the installer. Confirm that `docker info` works as your current user.

Install into the current user's home directory:

```bash
cd /path/to/KParkLab
./install_docker_env.sh --build-core
source "$HOME/kpark-pipelines/kpark.env"
open "$HOME/kpark-pipelines/config/lab_paths.sh"
```

If the install directory already exists, use it:

```bash
source "$HOME/kpark-pipelines/kpark.env"
kpark_usage.sh
```

Update an existing install from a refreshed clone:

```bash
cd /path/to/KParkLab
git pull
./install_docker_env.sh --update --build-core
source "$HOME/kpark-pipelines/kpark.env"
```

`--update` refreshes installed wrapper scripts (`Go_QC.sh`, `Go_KBracken.sh`, `Go_Humannake.sh`), Snakefiles, Dockerfiles, helper scripts, and `bin/` links while preserving `config/lab_paths.sh` and `config/lab_paths.yaml`.

If Docker images are missing, first start the Docker service, then rerun:

```bash
./install_docker_env.sh --update --build-core
docker image inspect goqc:kpark kbracken:kpark humann:kpark >/dev/null
```

If a container fails with `failed to launch x86-64-v3 version`, rebuild after updating K-park Lab:

```bash
git pull
./install_docker_env.sh --update --build-goqc --no-cache
```

GoQC no longer uses conda/micromamba, which avoids conda-forge CPU variant launch errors on older Intel Macs and amd64 emulation.

If GoQC build stops at `apt-get update`, first check Docker network access:

```bash
docker pull python:3.11-slim-bookworm
docker run --rm python:3.11-slim-bookworm bash -lc "apt-get update"
```

If those commands fail too, the problem is Docker network/DNS/proxy access rather than K-park Lab code.

For Apple Silicon Mac, if the normal Docker build fails while solving Bioconda packages:

```bash
cd /path/to/KParkLab
./install_docker_env.sh --build-core --platform linux/amd64
source "$HOME/kpark-pipelines/kpark.env"
```

## Install on another disk

Replace `/data` with a mounted directory writable by your user. Source code, installed pipelines, DBs, and analysis outputs can live on the same disk or separate disks.

```bash
git clone https://github.com/bbagy/KParkLab.git /data/KParkLab
cd /data/KParkLab
bash install_docker_env.sh --prefix /data/kpark-pipelines --build-all
source /data/kpark-pipelines/kpark.env
download_databases.sh --prefix /data/kpark-pipelines --db-root /data/kpark-db --tools all --threads 8
source /data/kpark-pipelines/kpark.env
```

New terminals: `source /data/kpark-pipelines/kpark.env`. Analysis output locations are selected with each pipeline's output option.

Update this installation using the same prefix:

```bash
cd /data/KParkLab
git pull --ff-only
bash install_docker_env.sh --prefix /data/kpark-pipelines --update --build-all
source /data/kpark-pipelines/kpark.env
```

### Docker image storage

`--prefix` does not relocate Docker images, containers, or volumes. Before building images, configure Docker storage on the data disk using the [Docker daemon storage guide](https://docs.docker.com/engine/daemon/#daemon-data-directory). With the containerd image store, its data directory must also be configured separately; Docker's `data-root` alone does not move it. Docker Desktop users should configure the disk image location in Docker Desktop settings.

### daDake2 host environments

Install Miniforge on the data disk by using `/data/miniforge3` for the installer's `-p` option, then source `/data/miniforge3/etc/profile.d/conda.sh`. To keep named environments and package caches on that disk, set these before creating the daDake2, QIIME 2, or FIGARO environments:

```bash
export CONDA_ENVS_PATH=/data/conda/envs
export CONDA_PKGS_DIRS=/data/conda/pkgs
```

Keep these exports in your shell startup configuration for subsequent terminals. Preserve the environment names used by the pipelines (`kpark-dadake2`, `qiime2`, `figaro_env`). FIGARO source code is stored next to the installed daDake2 Snakefile.

After install, edit:

```bash
$KPARK_PIPELINES/config/lab_paths.sh
```

Print command examples:

```bash
kpark_usage.sh
```

## Recommended Layout

```text
$HOME/kpark-pipelines/
  bin/
    Go_QC.sh
    Go_KBracken.sh
    Go_Humannake.sh
    kpark_usage.sh
  GoQC/
  KBracken/
  Humannake/
  config/lab_paths.yaml
  kpark_usage.sh
```

Any install root is valid. The important rule is that data and database paths are provided at run time.
Database paths can be provided once through `config/lab_paths.sh`.

## Docker Image Builds

If not using `install_docker_env.sh --build-core`, build the core images manually:

```bash
cd "$KPARK_PIPELINES/GoQC"
docker build -t goqc:kpark .
cd "$KPARK_PIPELINES/KBracken"
docker build -t kbracken:kpark .
cd "$KPARK_PIPELINES/Humannake"
docker build -t humann:kpark .
```

On Apple Silicon Mac, if Bioconda cannot solve packages for `linux/arm64`, use amd64 emulation:

```bash
cd "$KPARK_PIPELINES/GoQC"
docker build --platform linux/amd64 -t goqc:kpark .
cd "$KPARK_PIPELINES/KBracken"
docker build --platform linux/amd64 -t kbracken:kpark .
cd "$KPARK_PIPELINES/Humannake"
docker build --platform linux/amd64 -t humann:kpark .
export DOCKER_PLATFORM=linux/amd64
```

## Examples

First edit DB paths once on each workstation:

```bash
open "$KPARK_PIPELINES/config/lab_paths.sh"
source "$KPARK_PIPELINES/kpark.env"
```

Then normal commands can be short:

```bash
Go_QC.sh \
  -i /data/projects/ProjectA/fastq \
  -o ProjectA_QC \
  -K

Go_Humannake.sh \
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
Go_Humannake.sh -i IN -o OUT -n /path/to/chocophlan -p /path/to/uniref -b /path/to/metaphlan4 -I mpa_index -K
```

GoQC host DB policy:

```bash
download_databases.sh --db-root $HOME/kpark-db --tools host
```

The default host Bowtie2 index is CHM13/T2T (`chm13v2.0`). To override it for one workstation:

```bash
download_databases.sh \
  --db-root $HOME/kpark-db \
  --tools host \
  --host-index-name GRCh38_noalt_as \
  --host-index-url https://genome-idx.s3.amazonaws.com/bt/GRCh38_noalt_as.zip
```

Kraken2 DB policy:

```bash
download_databases.sh --db-root $HOME/kpark-db --tools kraken2 --threads 8
```

This downloads the latest available prebuilt `k2_pluspfp_16gb_YYYYMMDD` database from the Kraken2 AWS index and builds the Bracken kmer file locally. To choose a different 16GB family:

```bash
download_databases.sh --db-root $HOME/kpark-db --tools kraken2 --kraken2-16gb k2_standard_16gb --threads 8
```

`source "$KPARK_PIPELINES/kpark.env"` adds `$KPARK_PIPELINES/bin` to `PATH`, so the three wrappers can be run from any working directory.

`GoQC/Go_QC.sh` follows the same structure as `KBracken/Go_KBracken.sh`: the wrapper lives next to its Dockerfile and versioned Snakefile, and it resolves `Go_QC.smk` first, then `Go_QC_V1.smk`.

`Humannake/Go_Humannake.sh` follows the same structure: the wrapper lives next to `Dockerfile` and `Go_Humann_V1.smk`, and it resolves `Go_Humann.smk` first, then `Go_Humann_V1.smk`.

## Path Rules

- Use absolute host paths for FASTQ and DB inputs.
- Wrapper scripts mount host paths into containers as stable internal paths such as `/fastq`, `/db`, `/pipeline`, and `/report_assets`.
- Reference databases are not versioned in this repository.
- Local DB paths are loaded from `config/lab_paths.sh` after `source "$KPARK_PIPELINES/kpark.env"`.
- Keep generated outputs outside the pipeline install root.
- Avoid workstation names, user home directories, and lab names inside Snakefiles.

## Extended Pipeline Family

All installations now include longWGS, shortWGS, RNake, daDake2, MAGs, shared Docker/Apptainer helpers, and the documentation portal.
Existing GoQC, database download commands, and local DB settings are retained.

```bash
./install_docker_env.sh --update --build-all
source "$HOME/kpark-pipelines/kpark.env"
```

`--build-core` still builds only GoQC, KBracken, and Humannake. `--build-all` additionally builds longWGS, shortWGS, RNake, and all three MAGs stages.
For selective builds, use the Dockerfile and image name in each pipeline README.
daDake2 requires a host Snakemake/R/DADA2/FIGARO environment; it has no Docker build.
New pipelines take explicit reference/database flags. The downloader continues to cover only host filtering, Kraken2/Bracken, and HUMAnN/MetaPhlAn databases.
See `docs/index.html` and the individual pipeline READMEs for usage.
