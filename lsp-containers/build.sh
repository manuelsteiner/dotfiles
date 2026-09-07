#!/usr/bin/env bash
# Build the Neovim language-server images locally as
# localhost/nvim-lsp/<dir>:local.
#
#   ./build.sh                 build every image
#   ./build.sh gopls texlab    build only the named images
#   ./build.sh --ca FILE       build with a work-only HTTPS inspection CA
#
# Versions come from versions.env; each Containerfile declares the ARGs it needs.
set -euo pipefail
cd "$(dirname "$0")"

# shellcheck disable=SC1091
set -a; . ./versions.env; set +a

ca_file=
targets=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --ca)
      [ "$#" -ge 2 ] || { echo "build.sh: --ca needs a certificate path" >&2; exit 1; }
      ca_file=$2
      shift 2
      ;;
    --ca=*)
      ca_file=${1#--ca=}
      shift
      ;;
    --)
      shift
      targets+=("$@")
      break
      ;;
    -*)
      echo "build.sh: unknown option '$1'" >&2
      exit 1
      ;;
    *)
      targets+=("$1")
      shift
      ;;
  esac
done

[ -z "$ca_file" ] || [ -f "$ca_file" ] || {
  echo "build.sh: CA certificate is not a file: $ca_file" >&2
  exit 1
}

mapfile -t all < <(for d in */; do [ -f "${d}Containerfile" ] && echo "${d%/}"; done)
[ "${#targets[@]}" -eq 0 ] && targets=("${all[@]}")

ca_args=()
[ -z "$ca_file" ] || ca_args+=(--secret "id=company_ca,src=$ca_file")

for name in "${targets[@]}"; do
  [ -f "${name}/Containerfile" ] || { echo "build.sh: no Containerfile for '${name}'" >&2; exit 1; }

  build_args=()
  while read -r arg; do
    [ -n "${!arg:-}" ] || { echo "build.sh: ${name}: versions.env has no value for ${arg}" >&2; exit 1; }
    build_args+=(--build-arg "${arg}=${!arg}")
  done < <(grep -oP '^\s*ARG\s+\K[A-Z_][A-Z0-9_]*' "${name}/Containerfile" | sort -u)

  echo ">>> localhost/nvim-lsp/${name}:local"
  podman build "${ca_args[@]}" "${build_args[@]}" -t "localhost/nvim-lsp/${name}:local" "${name}"
done
