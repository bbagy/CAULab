#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./install_mac.sh [--prefix INSTALL_DIR] [--update] [--build-core|--build-all] [--no-cache] [--platform linux/amd64]

Defaults:
  INSTALL_DIR = $HOME/caulab-pipelines

Examples:
  ./install_mac.sh
  ./install_mac.sh --build-core
  ./install_mac.sh --update --build-goqc --no-cache
  ./install_mac.sh --update --build-core
  ./install_mac.sh --build-core --platform linux/amd64
  ./install_mac.sh --prefix /Volumes/Analysis/caulab-pipelines --build-core

Notes:
  - Docker Desktop must already be installed and running if a build option is used.
  - Use --platform linux/amd64 on Apple Silicon if Bioconda cannot solve linux/arm64 packages.
  - Use --no-cache when replacing a broken Docker image.
  - --build-core builds GoQC, KBracken, and Humann images.
  - --build-all also builds WGS, RNake, and all three MAGs stages.
  - daDake2 runs on the host and requires Snakemake, R/DADA2, and FIGARO.
  - --update refreshes an existing install while preserving config/lab_paths.yaml.
EOF
  exit "${1:-1}"
}

PREFIX="$HOME/caulab-pipelines"
BUILD_GOQC=0
BUILD_KBRACKEN=0
BUILD_HUMANN=0
BUILD_ALL=0
UPDATE=0
PLATFORM=""
NO_CACHE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      PREFIX="${2:-}"
      [ -n "$PREFIX" ] || usage
      shift 2
      ;;
    --build-goqc)
      BUILD_GOQC=1
      shift
      ;;
    --build-kbracken)
      BUILD_KBRACKEN=1
      shift
      ;;
    --build-humann)
      BUILD_HUMANN=1
      shift
      ;;
    --build-all)
      BUILD_ALL=1
      BUILD_GOQC=1
      BUILD_KBRACKEN=1
      BUILD_HUMANN=1
      shift
      ;;
    --build-core)
      BUILD_GOQC=1
      BUILD_KBRACKEN=1
      BUILD_HUMANN=1
      shift
      ;;
    --update)
      UPDATE=1
      shift
      ;;
    --platform)
      PLATFORM="${2:-}"
      [ -n "$PLATFORM" ] || usage
      shift 2
      ;;
    --no-cache)
      NO_CACHE=1
      shift
      ;;
    -h|--help)
      usage 0
      ;;
    *)
      usage
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PREFIX_PARENT="$(dirname "$PREFIX")"

prepare_update_target() {
  if [ "$UPDATE" -ne 1 ] || [ ! -e "$PREFIX" ]; then
    return
  fi

  local keep_yaml=""
  local keep_shell=""
  if [ -f "$PREFIX/config/lab_paths.yaml" ]; then
    keep_yaml="$(mktemp "${TMPDIR:-/tmp}/caulab_lab_paths_yaml.XXXXXX")"
    cp "$PREFIX/config/lab_paths.yaml" "$keep_yaml"
  fi
  if [ -f "$PREFIX/config/lab_paths.sh" ]; then
    keep_shell="$(mktemp "${TMPDIR:-/tmp}/caulab_lab_paths_sh.XXXXXX")"
    cp "$PREFIX/config/lab_paths.sh" "$keep_shell"
  fi

  rm -rf \
    "$PREFIX/GoQC" \
    "$PREFIX/KBracken" \
    "$PREFIX/Humann" \
    "$PREFIX/longWGS" \
    "$PREFIX/shortWGS" \
    "$PREFIX/RNake" \
    "$PREFIX/daDake2" \
    "$PREFIX/MAGs" \
    "$PREFIX/PFsnake" \
    "$PREFIX/common" \
    "$PREFIX/docs" \
    "$PREFIX/bin" \
    "$PREFIX/config" \
    "$PREFIX/README.md" \
    "$PREFIX/INSTALL_CAULab.md" \
    "$PREFIX/install_mac.sh" \
    "$PREFIX/download_databases.sh" \
    "$PREFIX/caulab_usage.sh" \
    "$PREFIX/.gitignore"

  mkdir -p "$PREFIX/config"
  if [ -n "$keep_yaml" ]; then
    cp "$keep_yaml" "$PREFIX/config/lab_paths.yaml"
    rm -f "$keep_yaml"
  fi
  if [ -n "$keep_shell" ]; then
    cp "$keep_shell" "$PREFIX/config/lab_paths.sh"
    rm -f "$keep_shell"
  fi
}

copy_install_files() {
  mkdir -p "$PREFIX"
  for pipeline in GoQC KBracken Humann longWGS shortWGS RNake daDake2 MAGs common docs; do
    cp -R "$SCRIPT_DIR/$pipeline" "$PREFIX/"
  done
  cp -R "$SCRIPT_DIR/config" "$PREFIX/"
  cp "$SCRIPT_DIR/README.md" "$PREFIX/"
  cp "$SCRIPT_DIR/INSTALL_CAULab.md" "$PREFIX/"
  cp "$SCRIPT_DIR/install_mac.sh" "$PREFIX/"
  cp "$SCRIPT_DIR/download_databases.sh" "$PREFIX/"
  cp "$SCRIPT_DIR/caulab_usage.sh" "$PREFIX/"
  cp "$SCRIPT_DIR/.gitignore" "$PREFIX/"
}

mkdir -p "$PREFIX_PARENT"

if [ -e "$PREFIX" ] && [ "$UPDATE" -ne 1 ]; then
  echo "[CAULab install][FATAL] install dir already exists: $PREFIX"
  echo "[CAULab install] Existing install can be used with:"
  echo "  source \"$PREFIX/caulab.env\""
  echo "[CAULab install] No Docker images were built because install stopped before the build step."
  echo "[CAULab install] To refresh code and build images in that install, rerun:"
  echo "  ./install_mac.sh --update --build-core"
  echo "[CAULab install] Or choose a new --prefix."
  exit 1
fi

prepare_update_target
copy_install_files

if [ ! -f "$PREFIX/config/lab_paths.yaml" ]; then
  cp "$PREFIX/config/lab_paths.example.yaml" "$PREFIX/config/lab_paths.yaml"
fi
if [ ! -f "$PREFIX/config/lab_paths.sh" ]; then
  cp "$PREFIX/config/lab_paths.sh.example" "$PREFIX/config/lab_paths.sh"
fi

mkdir -p "$PREFIX/bin"
ln -sf "../GoQC/Go_QC.sh" "$PREFIX/bin/Go_QC.sh"
ln -sf "../KBracken/Go_KBracken.sh" "$PREFIX/bin/Go_KBracken.sh"
ln -sf "../Humann/Go_Humannake.sh" "$PREFIX/bin/Go_Humannake.sh"
for launcher in longWGS/Go_longWGS.sh shortWGS/Go_shortWGS.sh RNake/Go_Rnake.sh daDake2/Go_daDake2.sh MAGs/Go_MAGs_QC.sh MAGs/Go_MAGs_Assembly.sh MAGs/Go_MAGs_Annotation.sh common/Go_container_image.sh; do
  ln -sf "../$launcher" "$PREFIX/bin/$(basename "$launcher")"
done
ln -sf "../download_databases.sh" "$PREFIX/bin/download_databases.sh"
ln -sf "../caulab_usage.sh" "$PREFIX/bin/caulab_usage.sh"

cat > "$PREFIX/caulab.env" <<EOF
export CAULAB_PIPELINES="$PREFIX"
export PATH="$PREFIX/bin:\$PATH"
if [ -f "$PREFIX/config/lab_paths.sh" ]; then
  . "$PREFIX/config/lab_paths.sh"
fi
EOF
if [ -n "$PLATFORM" ]; then
  cat >> "$PREFIX/caulab.env" <<EOF
export DOCKER_PLATFORM="$PLATFORM"
EOF
fi

build_image() {
  local image="$1"
  local context="$2"
  local dockerfile="${3:-$context/Dockerfile}"
  echo "[CAULab install] Building $image from $context"
  if [ "$NO_CACHE" -eq 1 ] && [ -n "$PLATFORM" ]; then
    if ! docker build -f "$dockerfile" --progress=plain --no-cache --platform "$PLATFORM" -t "$image" "$context"; then
      report_build_failure "$image" "$context" "$dockerfile"
    fi
  elif [ "$NO_CACHE" -eq 1 ]; then
    if ! docker build -f "$dockerfile" --progress=plain --no-cache -t "$image" "$context"; then
      report_build_failure "$image" "$context" "$dockerfile"
    fi
  elif [ -n "$PLATFORM" ]; then
    if ! docker build -f "$dockerfile" --progress=plain --platform "$PLATFORM" -t "$image" "$context"; then
      report_build_failure "$image" "$context" "$dockerfile"
    fi
  else
    if ! docker build -f "$dockerfile" --progress=plain -t "$image" "$context"; then
      report_build_failure "$image" "$context" "$dockerfile"
    fi
  fi
}

report_build_failure() {
  local image="$1"
  local context="$2"
  local dockerfile="${3:-$context/Dockerfile}"
  echo "[CAULab install][FATAL] Docker build failed: $image"
  echo "[CAULab install] Re-run this command to see the full plain build log:"
  if [ -n "$PLATFORM" ]; then
    echo "  docker build -f \"$dockerfile\" --progress=plain --no-cache --platform \"$PLATFORM\" -t \"$image\" \"$context\""
  else
    echo "  docker build -f \"$dockerfile\" --progress=plain --no-cache -t \"$image\" \"$context\""
  fi
  if [ "$image" = "goqc:caulab" ]; then
    echo "[CAULab install] If the failure is at apt-get, test Docker apt directly:"
    echo "  docker run --rm python:3.11-slim-bookworm bash -lc 'apt-get update && apt-get install -y --no-install-recommends fastp bowtie2 samtools pigz'"
  fi
  exit 1
}

check_image_runtime() {
  local image="$1"
  local runtime_check='(command -v python >/dev/null 2>&1 && python --version || python3 --version) && snakemake --version >/dev/null'
  echo "[CAULab install] Runtime check: $image"
  if [ -n "$PLATFORM" ]; then
    docker run --rm --platform "$PLATFORM" "$image" bash -lc "$runtime_check"
  else
    docker run --rm "$image" bash -lc "$runtime_check"
  fi
}

report_image_status() {
  local image="$1"
  if docker image inspect "$image" >/dev/null 2>&1; then
    echo "[CAULab install] Docker image ready: $image"
  else
    echo "[CAULab install][WARN] Docker image missing: $image"
  fi
}

if [ "$BUILD_GOQC" -eq 1 ] || [ "$BUILD_KBRACKEN" -eq 1 ] || [ "$BUILD_HUMANN" -eq 1 ]; then
  if ! docker info >/dev/null 2>&1; then
    echo "[CAULab install][FATAL] Docker is not available. Start Docker Desktop and rerun."
    echo "[CAULab install] After Docker Desktop is running, use:"
    echo "  ./install_mac.sh --update --build-core"
    exit 1
  fi
fi
if [ "$BUILD_GOQC" -eq 1 ]; then
  build_image "goqc:caulab" "$PREFIX/GoQC"
  check_image_runtime "goqc:caulab"
fi
if [ "$BUILD_KBRACKEN" -eq 1 ]; then
  build_image "kbracken:caulab" "$PREFIX/KBracken"
  check_image_runtime "kbracken:caulab"
fi
if [ "$BUILD_HUMANN" -eq 1 ]; then
  build_image "humann:caulab" "$PREFIX/Humann"
  check_image_runtime "humann:caulab"
fi

if [ "$BUILD_GOQC" -eq 1 ] || [ "$BUILD_KBRACKEN" -eq 1 ] || [ "$BUILD_HUMANN" -eq 1 ]; then
  echo "[CAULab install] Docker image status:"
  report_image_status "goqc:caulab"
  report_image_status "kbracken:caulab"
  report_image_status "humann:caulab"
fi

if [ "$BUILD_ALL" -eq 1 ]; then
  build_image longwgs "$PREFIX/longWGS"
  build_image shortwgs "$PREFIX/shortWGS"
  build_image rnake:1.0 "$PREFIX/RNake"
  for stage in qc assembly annotation; do
    build_image "mags-$stage:1.0" "$PREFIX/MAGs" "$PREFIX/MAGs/docker/Dockerfile.$stage"
  done
fi

cat <<EOF
[CAULab install] Installed/updated to:
  $PREFIX

[CAULab install] Next:
  source "$PREFIX/caulab.env"
  edit "$PREFIX/config/lab_paths.sh"
  caulab_usage.sh

[CAULab install] GoQC example:
  Go_QC.sh \\
    -i /path/to/raw_fastq \\
    -o /path/to/output/ProjectA_QC \\
    -d /path/to/host_bowtie2_index_prefix \\
    -m goqc:caulab \\
    -K

[CAULab install] Core images:
  goqc:caulab
  kbracken:caulab
  humann:caulab

[CAULab install] Commands added to PATH:
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

[CAULab install] Updated wrapper scripts:
  $PREFIX/GoQC/Go_QC.sh
  $PREFIX/KBracken/Go_KBracken.sh
  $PREFIX/Humann/Go_Humannake.sh
EOF
