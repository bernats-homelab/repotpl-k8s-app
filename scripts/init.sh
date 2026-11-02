#!/usr/bin/env bash
# Prepara um repo gerado a partir do template: troca o placeholder `app-template`
# pelo nome da app em deploy/ e app/ e aponta a imagem para o GHCR deste repo.
#   scripts/init.sh <nome>
# O nome (DNS-1123) vira Deployment/Service, label e host na tailnet
# (https://<nome>.<sua-tailnet>). Use o mesmo nome como chave em `apps:` no repo central.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly PLACEHOLDER="app-template"

name="${1:-}"
if ! [[ "${name}" =~ ^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$ ]]; then
  echo "uso: $0 <nome>   (minúsculas, números e '-', até 63 caracteres)" >&2
  exit 2
fi

cd "${REPO_ROOT}"
repo="$(git remote get-url origin | sed -E 's#^.*github\.com[:/]##; s#\.git$##' | tr '[:upper:]' '[:lower:]')"
if [[ "${repo}" == "bernats-homelab/repotpl-k8s-app" ]]; then
  echo "Rode no repo gerado a partir do template, não no próprio template." >&2
  exit 1
fi

mapfile -t files < <(git grep -l "${PLACEHOLDER}" -- deploy app || true)
if [[ ${#files[@]} -gt 0 ]]; then
  sed -i "s/${PLACEHOLDER}/${name}/g" "${files[@]}"
fi

# Imagem deste repo; o digest real entra no primeiro release (workflow release.yaml).
scripts/set-image.sh "ghcr.io/${repo}:unreleased"

echo "OK: app '${name}' (imagem ghcr.io/${repo})."
echo "Próximos passos: commit + push, depois Actions → release → version v0.1.0."
