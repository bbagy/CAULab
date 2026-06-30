#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./install_mac.sh [--prefix INSTALL_DIR] [--build-core] [--platform linux/amd64]

Defaults:
  INSTALL_DIR = $HOME/caulab-pipelines

Examples:
  ./install_mac.sh
  ./install_mac.sh --build-core
  ./install_mac.sh --build-core --platform linux/amd64
  ./install_mac.sh --prefix /Volumes/Analysis/caulab-pipelines --build-core

Notes:
  - Docker Desktop must already be installed and running if a build option is used.
  - Use --platform linux/amd64 on Apple Silicon if Bioconda cannot solve linux/arm64 packages.
  - --build-core builds GoQC, KBracken, and Humann images.
EOF
  exit "${1:-1}"
}

PREFIX="$HOME/caulab-pipelines"
BUILD_GOQC=0
BUILD_KBRACKEN=0
BUILD_HUMANN=0
PLATFORM=""

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
    --build-core|--build-all)
      BUILD_GOQC=1
      BUILD_KBRACKEN=1
      BUILD_HUMANN=1
      shift
      ;;
    --platform)
      PLATFORM="${2:-}"
      [ -n "$PLATFORM" ] || usage
      shift 2
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

mkdir -p "$PREFIX_PARENT"

if [ -e "$PREFIX" ]; then
  echo "[CAULab install][FATAL] install dir already exists: $PREFIX"
  echo "[CAULab install] Choose a new --prefix or move the existing directory first."
  exit 1
fi

mkdir -p "$PREFIX"
cp -R "$SCRIPT_DIR"/. "$PREFIX"/

if [ ! -f "$PREFIX/config/lab_paths.yaml" ]; then
  cp "$PREFIX/config/lab_paths.example.yaml" "$PREFIX/config/lab_paths.yaml"
fi

mkdir -p "$PREFIX/bin"
ln -sf "../GoQC/Go_QC.sh" "$PREFIX/bin/Go_QC.sh"
ln -sf "../KBracken/Go_KBracken.sh" "$PREFIX/bin/Go_KBracken.sh"
ln -sf "../Humann/Go_Humann.sh" "$PREFIX/bin/Go_Humann.sh"
ln -sf "../caulab_usage.sh" "$PREFIX/bin/caulab_usage.sh"

cat > "$PREFIX/caulab.env" <<EOF
export CAULAB_PIPELINES="$PREFIX"
export PATH="$PREFIX/bin:\$PATH"
EOF
if [ -n "$PLATFORM" ]; then
  cat >> "$PREFIX/caulab.env" <<EOF
export DOCKER_PLATFORM="$PLATFORM"
EOF
fi

build_image() {
  local image="$1"
  local context="$2"
  local -a build_args=()
  if [ -n "$PLATFORM" ]; then
    build_args=(--platform "$PLATFORM")
  fi
  echo "[CAULab install] Building $image from $context"
  docker build "${build_args[@]}" -t "$image" "$context"
}

if [ "$BUILD_GOQC" -eq 1 ] || [ "$BUILD_KBRACKEN" -eq 1 ] || [ "$BUILD_HUMANN" -eq 1 ]; then
  if ! docker info >/dev/null 2>&1; then
    echo "[CAULab install][FATAL] Docker is not available. Start Docker Desktop and rerun."
    exit 1
  fi
fi
if [ "$BUILD_GOQC" -eq 1 ]; then
  build_image "goqc:caulab" "$PREFIX/GoQC"
fi
if [ "$BUILD_KBRACKEN" -eq 1 ]; then
  build_image "kbracken:caulab" "$PREFIX/KBracken"
fi
if [ "$BUILD_HUMANN" -eq 1 ]; then
  build_image "humann:caulab" "$PREFIX/Humann"
fi

cat <<EOF
[CAULab install] Installed to:
  $PREFIX

[CAULab install] Next:
  source "$PREFIX/caulab.env"
  edit "$PREFIX/config/lab_paths.yaml"
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
  Go_Humann.sh
  caulab_usage.sh
EOF
