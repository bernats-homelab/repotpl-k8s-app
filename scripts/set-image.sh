#!/usr/bin/env bash
# Grava a imagem da app no bloco `images:` de deploy/base/kustomization.yaml, que precisa
# ser o último do arquivo. Diferente de `kustomize edit set image`, preserva comentários e
# formatação (yamllint). Usado pelo release.yaml, pelo init.sh e pelo e2e do CI.
#   set-image.sh <imagem>@sha256:<digest> [kustomization.yaml]
#   set-image.sh <imagem>:<tag>           [kustomization.yaml]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly ENTRY='  - name: app-image'

ref="${1:-}"
file="${2:-${REPO_ROOT}/deploy/base/kustomization.yaml}"

if [[ "${ref}" =~ ^([^@]+)@(sha256:[0-9a-f]{64})$ ]]; then
  image="${BASH_REMATCH[1]}"
  field="digest: ${BASH_REMATCH[2]}"
elif [[ "${ref}" =~ ^([^@]+):([A-Za-z0-9_][A-Za-z0-9_.-]{0,127})$ ]]; then
  image="${BASH_REMATCH[1]}"
  field="newTag: ${BASH_REMATCH[2]}"
else
  echo "uso: $0 <imagem>@sha256:<digest> | <imagem>:<tag> [kustomization.yaml]" >&2
  exit 2
fi

if ! grep -qxF "${ENTRY}" "${file}"; then
  echo "ERRO: '${ENTRY}' não encontrado em ${file}" >&2
  exit 1
fi

updated="$(sed "/^${ENTRY}\$/,\$d" "${file}")"
printf '%s\n%s\n    newName: %s\n    %s\n' "${updated}" "${ENTRY}" "${image}" "${field}" >"${file}"
