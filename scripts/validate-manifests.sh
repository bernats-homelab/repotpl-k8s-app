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
# Kinds do CloudNativePG e do plugin Barman Cloud não estão no catálogo padrão do kubeconform;
# o CRD do cluster os valida no apply.
readonly CNPG_KINDS="Cluster,ObjectStore,ScheduledBackup"

mkdir -p "${CACHE_DIR}"

validate() { # validate <dir>
  local dir="$1" rendered
  echo "==> ${dir#"${REPO_ROOT}/"}"
  rendered="$("${REPO_ROOT}/scripts/kustomize-build.sh" "${dir}")"
  kubeconform -strict -summary -skip "${CNPG_KINDS}" \
    -kubernetes-version "${KUBERNETES_VERSION}" \
    -cache "${CACHE_DIR}" \
    -schema-location default - <<<"${rendered}"
  kube-linter lint --config "${REPO_ROOT}/.kube-linter.yaml" - <<<"${rendered}"
}

while read -r dir; do
  # Componentes (deploy/components) não se constroem sozinhos: entram pelos overlays.
  grep -q '^kind: Component' "${dir}/kustomization.yaml" && continue
  validate "${dir}"
done < <(find "${REPO_ROOT}/deploy" -name kustomization.yaml -not -path '*/.validate-*' -printf '%h\n' | sort)

# Os componentes vêm desligados no template: valida-os montados sobre a base, num overlay
# temporário, para que um erro neles apareça antes de um app ligá-los.
tmp="$(mktemp -d "${REPO_ROOT}/deploy/.validate-XXXXXX")"
trap 'rm -rf "${tmp}"' EXIT
cat >"${tmp}/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../base
components:
  - ../components/postgres-cnpg
  - ../components/postgres-backup
EOF
validate "${tmp}"
