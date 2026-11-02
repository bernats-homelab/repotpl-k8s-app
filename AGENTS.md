# Contexto

App publicada no cluster k3s do notebook pelo repo central `bernats-homelab/2026-kubernetes` (ArgoCD app-of-apps). Este repo tem código, `Dockerfile` e kustomize em `deploy/`. O central só declara a Application (`apps.<nome>` em `kubernetes/apps/values.yaml`), fixada numa tag `vX.Y.Z` deste repo.

# Estrutura

- `deploy/base`: Deployment + Service, sem `namespace:` e sem Ingress (é o que o CI do central sincroniza)
- `deploy/overlays/tailscale`: base + Ingress `ingressClassName: tailscale` (notebook)
- `.github/workflows/release.yaml`: único jeito de gerar versão (imagem → digest na kustomization → tag)
- `scripts/`: cópias dos scripts de validação do central (`kustomize-build.sh`, `ksops-stub.py`, `check-sops-encrypted.sh`)

# Restrições

- Imagens sempre por digest: a base no `Dockerfile` e a da app em `images:` (só o `release.yaml` altera)
- Ferramentas com versão + sha256 em `scripts/setup-tools.sh` (mesmas versões do central)
- Nunca versionar o nome da tailnet (`*.ts.net`), hostname, usuário ou kubeconfig
- Segredos só em `*.sops.yaml` criptografados no caminho final (o `.sops.yaml` escolhe WSL + cluster). Nunca usar a chave de teste do CI do central
- Só recursos namespaced (AppProject `homelab-apps`): nada de ClusterRole, CRD, webhook ou namespace do sistema
- Manifests passam no `.kube-linter.yaml`: probes, requests, `runAsNonRoot`, `readOnlyRootFilesystem`, `drop: [ALL]`

# Testes

- `make test` (WSL): pre-commit completo, incluindo kubeconform + kube-linter de `deploy/`
- CI `e2e`: k3s no runner, imagem do próprio job, `deploy/base` Available + `/healthz`
