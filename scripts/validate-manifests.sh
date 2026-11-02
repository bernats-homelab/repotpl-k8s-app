#!/usr/bin/env bash
# Valida cada kustomization de deploy/ (base e overlays) contra os schemas do Kubernetes
# (kubeconform) e boas práticas (kube-linter), como o repo central faz com os workloads dele.
# O generator KSOPS é resolvido por scripts/ksops-stub.py (sem chave age).
# Os schemas são baixados na primeira execução e ficam em cache em .cache/kubeconform.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
# Mesma minor do k3s fixado no repo central (ansible/group_vars/all/main.yaml)
readonly KUBERNETES_VERSION="1.37.0"
readonly CACHE_DIR="${REPO_ROOT}/.cache/kubeconform"

mkdir -p "${CACHE_DIR}"

while read -r dir; do
  echo "==> ${dir#"${REPO_ROOT}/"}"
  rendered="$("${REPO_ROOT}/scripts/kustomize-build.sh" "${dir}")"
  kubeconform -strict -summary \
    -kubernetes-version "${KUBERNETES_VERSION}" \
    -cache "${CACHE_DIR}" \
    -schema-location default - <<<"${rendered}"
  kube-linter lint --config "${REPO_ROOT}/.kube-linter.yaml" - <<<"${rendered}"
done < <(find "${REPO_ROOT}/deploy" -name kustomization.yaml -printf '%h\n' | sort)
