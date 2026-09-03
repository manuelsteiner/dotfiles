#!/usr/bin/env bash
# Build the Neovim language-server images locally as
# localhost/nvim-lsp/<dir>:local.
#
#   ./build.sh                 build every image
#   ./build.sh gopls texlab    build only the named images
#
# Versions come from versions.env; each Containerfile declares the ARGs it needs.
set -euo pipefail
cd "$(dirname "$0")"

# shellcheck disable=SC1091
set -a; . ./versions.env; set +a

mapfile -t all < <(for d in */; do [ -f "${d}Containerfile" ] && echo "${d%/}"; done)
targets=("$@")
[ "${#targets[@]}" -eq 0 ] && targets=("${all[@]}")

for name in "${targets[@]}"; do
  [ -f "${name}/Containerfile" ] || { echo "build.sh: no Containerfile for '${name}'" >&2; exit 1; }

  build_args=()
  while read -r arg; do
    [ -n "${!arg:-}" ] || { echo "build.sh: ${name}: versions.env has no value for ${arg}" >&2; exit 1; }
    build_args+=(--build-arg "${arg}=${!arg}")
  done < <(grep -oP '^\s*ARG\s+\K[A-Z_][A-Z0-9_]*' "${name}/Containerfile" | sort -u)

  echo ">>> localhost/nvim-lsp/${name}:local"
  podman build "${build_args[@]}" -t "localhost/nvim-lsp/${name}:local" "${name}"
done
