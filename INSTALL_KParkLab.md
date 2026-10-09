# K-park Lab Installation Notes

The K-park Lab copy is intended to be path-neutral. Do not hard-code workstation paths inside Snakefiles. Keep lab-specific DB paths in `config/lab_paths.sh`; wrapper scripts use those values by default and still allow command-line overrides.

## Data disk setup

The recommended Ubuntu server layout keeps large files on `/data`. The OS and service configuration stay on `/`. Replace `/data` throughout the examples with your actual mounted data disk. Installer defaults remain unchanged, so always pass `--prefix /data/kpark-pipelines`.

| Files | Location |
|---|---|
| Source code | `/data/KParkLab` |
| Installed pipelines | `/data/kpark-pipelines` |
| Reference DBs | `/data/kpark-db` |
| Miniforge | `/data/miniforge3` |
| Conda environments / package cache | `/data/conda/envs`, `/data/conda/pkgs` |
| Docker / containerd | `/data/docker`, `/data/containerd` |
| Analysis inputs and outputs | `/data/projects` |
| Downloads / logs / container archives | `/data/downloads`, `/data/logs`, `/data/containers` |

### Prepare the mounted disk

Check that `/data` is a mounted data filesystem before creating directories. On a shared server, the administrator should grant access to these directories to the intended users.

```bash
findmnt --mountpoint /data
df -h / /data
sudo mkdir -p /data/kpark-db /data/conda /data/projects /data/downloads /data/logs /data/containers
sudo chown "$USER:$(id -gn)" /data/kpark-db /data/conda /data/projects /data/downloads /data/logs /data/containers
test -w /data/kpark-db
```

For cloning, installation, and Miniforge, have the administrator grant the user permission to create `/data/KParkLab`, `/data/kpark-pipelines`, and `/data/miniforge3`. Keep these targets absent for a first installation; installers create them.

### Docker storage: configure before building

For Ubuntu Docker Engine, merge `"data-root": "/data/docker"` into `/etc/docker/daemon.json`, preserving any existing settings. With the containerd image store, also set the top-level `root = "/data/containerd"` in `/etc/containerd/config.toml`, preserving its existing version and plugin settings. Docker's `data-root` does not move containerd image data. See the [Docker storage guide](https://docs.docker.com/engine/daemon/#daemon-data-directory).

Create the service directories with root ownership. During a maintenance window, stop Docker and its socket; stop containerd too if changing its storage. For existing installations, copy the actual old service data directories to the new destinations with `sudo rsync -aHAX --numeric-ids OLD/ NEW/` while the services are stopped. Keep the old copies until the restart and an existing-image/container check pass. Coordinate the containerd change if other services use it.

```bash
sudo mkdir -p /data/docker /data/containerd
sudo systemctl stop docker.service docker.socket
# Only when changing containerd storage:
sudo systemctl stop containerd.service
# Copy existing data and edit service storage settings before continuing.
sudo systemctl edit docker
```

Add the following override so Docker waits for the data disk at boot:

```ini
[Unit]
RequiresMountsFor=/data/docker /data/containerd
```

If using the separate containerd service on `/data`, add `RequiresMountsFor=/data/containerd` under `[Unit]` with `sudo systemctl edit containerd` as well. Reload service configuration, start containerd then Docker, and verify:

```bash
sudo systemctl daemon-reload
sudo systemctl start containerd docker
docker info --format '{{.DockerRootDir}}'
docker info -f '{{ .DriverStatus }}'
docker image ls
docker system df
```

Expected Docker root: `/data/docker`. For containerd, inspect the effective service configuration and confirm its `root` before image builds. Docker Desktop users should set the disk image location in Docker Desktop settings instead of using these Linux service commands.

### Conda storage: configure before creating environments

Install Miniforge with `-p /data/miniforge3`. Put the following in `~/.bashrc` once (replace any older Conda initialization that points to the old installation):

```bash
export CONDA_ENVS_PATH=/data/conda/envs
export CONDA_PKGS_DIRS=/data/conda/pkgs
source /data/miniforge3/etc/profile.d/conda.sh
source /data/kpark-pipelines/kpark.env
```

Apply the same exports in the current terminal before creating named environments. Keep the pipeline's environment names (`kpark-dadake2`, `qiime2`, `figaro_env`). Check storage with `conda info` and `conda env list`. FIGARO source is installed next to the daDake2 Snakefile. See [Conda environment and cache settings](https://docs.conda.io/projects/conda/en/latest/user-guide/configuration/settings.html).

### Move an existing root-disk installation

1. Inspect old DB paths in the existing `config/lab_paths.sh` and `config/lab_paths.yaml`; record `conda env list`, Docker's root, and containerd's root.
2. Copy DBs to `/data/kpark-db` with `rsync -aH --info=progress2 OLD_DB/ /data/kpark-db/`. Verify contents with `rsync -aHnc --itemize-changes OLD_DB/ /data/kpark-db/`; resolve any reported file differences.
3. Install pipeline files into `/data/kpark-pipelines` with an explicit prefix. Update both local configuration files to the copied DB paths, retaining DB filenames and index prefixes. Copying the old settings without changing paths still uses root-disk DBs.
4. Export existing Conda environments, install Miniforge on `/data`, and recreate the required named environments there. Do not move existing Conda folders directly: installed packages can contain absolute paths. Verify daDake2/R and QIIME 2 commands in the recreated environments.
5. Move Docker/containerd storage using the stopped-service procedure above. Run a pipeline dry-run and a small real analysis using the `/data` DBs.
6. After verification, delete only the confirmed old DB, Conda, pipeline, and service-data directories. Check that no active settings or running jobs reference them first. A new installation does not remove old files or reclaim root space automatically. Recheck `df -h / /data`.

## Ubuntu Server Install

Install Git and Docker Engine before running the installer. Confirm that `docker info` works as your current user.

Install onto the mounted data disk after configuring Docker storage above:

```bash
cd /data/KParkLab
./install_docker_env.sh --prefix /data/kpark-pipelines --build-core
source "/data/kpark-pipelines/kpark.env"
nano "/data/kpark-pipelines/config/lab_paths.sh"
```

If the install directory already exists, use it:

```bash
source "/data/kpark-pipelines/kpark.env"
kpark_usage.sh
```

Update an existing install from a refreshed clone:

```bash
cd /data/KParkLab
git pull
./install_docker_env.sh --prefix /data/kpark-pipelines --update --build-core
source "/data/kpark-pipelines/kpark.env"
```

`--update` refreshes installed wrapper scripts (`Go_QC.sh`, `Go_KBracken.sh`, `Go_Humannake.sh`), Snakefiles, Dockerfiles, helper scripts, and `bin/` links while preserving `config/lab_paths.sh` and `config/lab_paths.yaml`.

If Docker images are missing, first start the Docker service, then rerun:

```bash
./install_docker_env.sh --prefix /data/kpark-pipelines --update --build-core
docker image inspect goqc:kpark kbracken:kpark humann:kpark >/dev/null
```

If a container fails with `failed to launch x86-64-v3 version`, rebuild after updating K-park Lab:

```bash
git pull
./install_docker_env.sh --prefix /data/kpark-pipelines --update --build-goqc --no-cache
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
cd /data/KParkLab
./install_docker_env.sh --prefix /data/kpark-pipelines --build-core --platform linux/amd64
source "/data/kpark-pipelines/kpark.env"
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
/data/kpark-pipelines/
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

If not using `install_docker_env.sh --prefix /data/kpark-pipelines --build-core`, build the core images manually:

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
nano "$KPARK_PIPELINES/config/lab_paths.sh"
source "$KPARK_PIPELINES/kpark.env"
```

Then normal commands can be short:

```bash
mkdir -p /data/projects/ProjectA
cd /data/projects/ProjectA
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
Go_KBracken.sh -i IN -o OUT -d /data/kpark-db/kraken2/k2_pluspfp_16gb_latest -K
Go_Humannake.sh -i IN -o OUT -n /data/kpark-db/humann/chocophlan -p /data/kpark-db/humann/uniref90_diamond -b /path/to/metaphlan4 -I mpa_index -K
```

GoQC host DB policy:

```bash
download_databases.sh --db-root /data/kpark-db --tools host
```

The default host Bowtie2 index is CHM13/T2T (`chm13v2.0`). To override it for one workstation:

```bash
download_databases.sh \
  --db-root /data/kpark-db \
  --tools host \
  --host-index-name GRCh38_noalt_as \
  --host-index-url https://genome-idx.s3.amazonaws.com/bt/GRCh38_noalt_as.zip
```

Kraken2 DB policy:

```bash
download_databases.sh --db-root /data/kpark-db --tools kraken2 --threads 8
```

This downloads the latest available prebuilt `k2_pluspfp_16gb_YYYYMMDD` database from the Kraken2 AWS index and builds the Bracken kmer file locally. To choose a different 16GB family:

```bash
download_databases.sh --db-root /data/kpark-db --tools kraken2 --kraken2-16gb k2_standard_16gb --threads 8
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
./install_docker_env.sh --prefix /data/kpark-pipelines --update --build-all
source "/data/kpark-pipelines/kpark.env"
```

`--build-core` still builds only GoQC, KBracken, and Humannake. `--build-all` additionally builds longWGS, shortWGS, RNake, and all three MAGs stages.
For selective builds, use the Dockerfile and image name in each pipeline README.
daDake2 requires a host Snakemake/R/DADA2/FIGARO environment; it has no Docker build.
New pipelines take explicit reference/database flags. The downloader continues to cover only host filtering, Kraken2/Bracken, and HUMAnN/MetaPhlAn databases.
See `docs/index.html` and the individual pipeline READMEs for usage.
