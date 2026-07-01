#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./install_mac.sh [--prefix INSTALL_DIR] [--update] [--build-core] [--platform linux/amd64]

Defaults:
  INSTALL_DIR = $HOME/caulab-pipelines

Examples:
  ./install_mac.sh
  ./install_mac.sh --build-core
  ./install_mac.sh --update --build-core
  ./install_mac.sh --build-core --platform linux/amd64
  ./install_mac.sh --prefix /Volumes/Analysis/caulab-pipelines --build-core

Notes:
  - Docker Desktop must already be installed and running if a build option is used.
  - Use --platform linux/amd64 on Apple Silicon if Bioconda cannot solve linux/arm64 packages.
  - --build-core builds GoQC, KBracken, and Humann images.
  - --update refreshes an existing install while preserving config/lab_paths.yaml.
EOF
  exit "${1:-1}"
}

PREFIX="$HOME/caulab-pipelines"
BUILD_GOQC=0
BUILD_KBRACKEN=0
BUILD_HUMANN=0
UPDATE=0
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
    --update)
      UPDATE=1
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

copy_install_files() {
  mkdir -p "$PREFIX"
  cp -R "$SCRIPT_DIR/GoQC" "$PREFIX/"
  cp -R "$SCRIPT_DIR/KBracken" "$PREFIX/"
  cp -R "$SCRIPT_DIR/Humann" "$PREFIX/"
  cp -R "$SCRIPT_DIR/config" "$PREFIX/"
  cp "$SCRIPT_DIR/README.md" "$PREFIX/"
  cp "$SCRIPT_DIR/INSTALL_CAULab.md" "$PREFIX/"
  cp "$SCRIPT_DIR/install_mac.sh" "$PREFIX/"
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

copy_install_files

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
fi
if [ "$BUILD_KBRACKEN" -eq 1 ]; then
  build_image "kbracken:caulab" "$PREFIX/KBracken"
fi
if [ "$BUILD_HUMANN" -eq 1 ]; then
  build_image "humann:caulab" "$PREFIX/Humann"
fi

if [ "$BUILD_GOQC" -eq 1 ] || [ "$BUILD_KBRACKEN" -eq 1 ] || [ "$BUILD_HUMANN" -eq 1 ]; then
  echo "[CAULab install] Docker image status:"
  report_image_status "goqc:caulab"
  report_image_status "kbracken:caulab"
  report_image_status "humann:caulab"
fi

cat <<EOF
[CAULab install] Installed/updated to:
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
