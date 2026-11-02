#!/usr/bin/env bash
# Instala as ferramentas deste repo em ~/.local/bin com versão e sha256 fixados
# (subset de scripts/setup-control-node.sh do repo central; mesmas versões).
#   setup-tools.sh               -> tudo (WSL e job lint do CI)
#   setup-tools.sh kustomize ... -> só as ferramentas pedidas (outros jobs do CI)
set -euo pipefail

readonly BIN_DIR="${HOME}/.local/bin"

# --- versões fixadas (atualize versão + sha256 juntos) -----------------------
readonly PRE_COMMIT_VERSION="4.7.0"
readonly SOPS_VERSION="v3.13.3"
readonly SOPS_SHA256="e5bec3346a873ae91d871550f3e698c1aad962aff462a080e40f25fde17fef6b"
readonly AGE_VERSION="v1.3.2"
readonly AGE_SHA256="cbe24006683f8eb669266162894b9a522a1af52f2665fbc63a4bb032ed26ac10"
readonly KUBECONFORM_VERSION="v0.8.0"
readonly KUBECONFORM_SHA256="9bc2bffbf71f261128533edaf912153948b7ff238f9a531ae6d34466ec287883"
readonly KUBE_LINTER_VERSION="v0.8.3"
readonly KUBE_LINTER_SHA256="1a6d8419b11971372971fdbc22682b684ebfb7cf1c39591662d1b6ca736c41df"
readonly KUSTOMIZE_VERSION="v5.8.3"
readonly KUSTOMIZE_SHA256="cb9e31198d3f63b44848bd0afc4c8efc56e6cfef9c93a4a39a211940e6decd61"
# -----------------------------------------------------------------------------

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# download <url> <sha256> <dest>
download() {
  local url="$1" sha="$2" dest="$3"
  curl -fsSL --retry 3 -o "${dest}" "${url}"
  echo "${sha}  ${dest}" | sha256sum --check --quiet -
}

# install_bin <name> <version> <url> <sha256> [path-inside-tar]
install_bin() {
  local name="$1" version="$2" url="$3" sha="$4" member="${5:-}"
  local stamp="${BIN_DIR}/.${name}-${version}"
  if [[ -f "${stamp}" && -x "${BIN_DIR}/${name}" ]]; then
    return 0
  fi
  log "instalando ${name} ${version}"
  local tmp
  tmp="$(mktemp -d)"
  download "${url}" "${sha}" "${tmp}/artifact"
  if [[ -n "${member}" ]]; then
    tar -xzf "${tmp}/artifact" -C "${tmp}" "${member}"
    install -m 0755 "${tmp}/${member}" "${BIN_DIR}/${name}"
  else
    install -m 0755 "${tmp}/artifact" "${BIN_DIR}/${name}"
  fi
  rm -rf "${tmp}" "${BIN_DIR}/.${name}-"*
  touch "${stamp}"
}

install_tool() {
  case "$1" in
    pre-commit)
      # pipx próprio: ignora instalações pré-existentes (ex.: /opt/pipx dos runners do GitHub)
      PIPX_HOME="${HOME}/.local/share/pipx" PIPX_BIN_DIR="${BIN_DIR}" \
        pipx install --force "pre-commit==${PRE_COMMIT_VERSION}" >/dev/null
      ;;
    sops)
      install_bin sops "${SOPS_VERSION}" \
        "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64" \
        "${SOPS_SHA256}"
      ;;
    age)
      local url="https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-linux-amd64.tar.gz"
      install_bin age "${AGE_VERSION}" "${url}" "${AGE_SHA256}" age/age
      install_bin age-keygen "${AGE_VERSION}" "${url}" "${AGE_SHA256}" age/age-keygen
      ;;
    kubeconform)
      install_bin kubeconform "${KUBECONFORM_VERSION}" \
        "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" \
        "${KUBECONFORM_SHA256}" kubeconform
      ;;
    kube-linter)
      install_bin kube-linter "${KUBE_LINTER_VERSION}" \
        "https://github.com/stackrox/kube-linter/releases/download/${KUBE_LINTER_VERSION}/kube-linter-linux.tar.gz" \
        "${KUBE_LINTER_SHA256}" kube-linter
      ;;
    kustomize)
      install_bin kustomize "${KUSTOMIZE_VERSION}" \
        "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" \
        "${KUSTOMIZE_SHA256}" kustomize
      ;;
    *)
      echo "ferramenta desconhecida: $1" >&2
      exit 2
      ;;
  esac
}

main() {
  if [[ "$(uname -s)-$(uname -m)" != "Linux-x86_64" ]]; then
    echo "Rode no WSL (Ubuntu x86_64) ou em um runner Linux." >&2
    exit 1
  fi
  mkdir -p "${BIN_DIR}"
  case ":${PATH}:" in
    *":${BIN_DIR}:"*) ;;
    *) echo "Adicione ${BIN_DIR} ao PATH (ex.: no ~/.bashrc)." >&2 ;;
  esac
  export PATH="${BIN_DIR}:${PATH}"

  local tools=("$@")
  if [[ ${#tools[@]} -eq 0 ]]; then
    tools=(pre-commit sops age kubeconform kube-linter kustomize)
    log "pacotes apt"
    sudo apt-get update -qq
    sudo apt-get install -y -qq curl git jq make pipx python3 python3-yaml >/dev/null
  fi

  local tool
  for tool in "${tools[@]}"; do
    install_tool "${tool}"
  done
  log "pronto"
}

main "$@"
