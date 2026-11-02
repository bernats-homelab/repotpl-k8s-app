#!/usr/bin/env bash
# Falha se algum *.sops.yaml não estiver criptografado pelo SOPS:
#   - precisa ter o bloco de metadados `sops:` com `mac: ENC[...]`
#   - todo valor escalar fora do bloco `sops:` precisa ser `ENC[...]`, exceto as chaves
#     de topo liberadas pelo `unencrypted_regex` do próprio arquivo (manifests do KSOPS)
#   - precisa ter pelo menos um valor `ENC[...]`
#   - nunca pode ter como destinatária a chave de teste do CI do repo central
#     (pública, bernats-homelab/2026-kubernetes tests/ci-age.key)
# Mesma lógica de scripts/check-sops-encrypted.sh do repo central.
set -euo pipefail

readonly CI_RECIPIENT='age13jefle8t0y6t6a2epfjm3tpdczy79qlljxjhme6xttwfkw9309zq5m7v6m'

status=0
for file in "$@"; do
  if ! grep -qE '^sops:' "${file}" || ! grep -qE '^[[:space:]]+mac: ENC\[' "${file}"; then
    echo "ERRO: ${file} não tem metadados SOPS (sops/mac). Rode: sops encrypt --in-place ${file}" >&2
    status=1
    continue
  fi
  if grep -qE '^[[:space:]]+encrypted_regex:' "${file}"; then
    echo "ERRO: ${file} usa encrypted_regex; use unencrypted_regex (regras em .sops.yaml)" >&2
    status=1
    continue
  fi
  if grep -qF "recipient: ${CI_RECIPIENT}" "${file}"; then
    echo "ERRO: ${file} está criptografado para a chave PÚBLICA de teste do CI do repo central." >&2
    echo "      Corrija o .sops.yaml e rode: sops updatekeys ${file}" >&2
    status=1
    continue
  fi
  unencrypted="$(sed -nE 's/^[[:space:]]+unencrypted_regex: (.*)$/\1/p' "${file}")"
  plaintext="$(awk -v unencrypted="${unencrypted}" '
    /^sops:/ { in_sops = 1; next }
    /^[^[:space:]#]/ {
      in_sops = 0
      top = $0; sub(/:.*/, "", top)
      skip = (unencrypted != "" && top ~ unencrypted)
    }
    in_sops || skip { next }
    /^[[:space:]]*(#|$)/ { next }
    /^[[:space:]]*-?[[:space:]]*[^:]+:[[:space:]]*$/ { next }
    /:[[:space:]]+ENC\[/ { encrypted++; next }
    /^[[:space:]]*-[[:space:]]+ENC\[/ { encrypted++; next }
    { print FILENAME ":" NR }
    END { if (!encrypted) print FILENAME ":sem-valores-criptografados" }
  ' "${file}")"
  if [[ -n "${plaintext}" ]]; then
    echo "ERRO: valores em texto claro em ${file} (linhas: ${plaintext//$'\n'/, })" >&2
    status=1
  fi
done
exit "${status}"
