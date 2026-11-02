# repotpl-k8s-app

Template de repositório para apps que rodam no cluster k3s do notebook, gerenciado pelo repo central [bernats-homelab/2026-kubernetes](https://github.com/bernats-homelab/2026-kubernetes).

O repo da app tem o código, o `Dockerfile` e os manifests kustomize em `deploy/`. O repo central só declara uma Application do ArgoCD que aponta para uma **tag** deste repo, do mesmo jeito que ele fixa a versão dos charts de terceiros.

```
este repo                                      repo central (2026-kubernetes)
  Dockerfile, app/                               kubernetes/apps/values.yaml
  deploy/base           ◀── CI (sem tailnet)        apps:
  deploy/overlays/tailscale ◀── notebook              <nome>:
  release.yaml ──▶ ghcr.io/<repo>@sha256 ──▶ tag vX.Y.Z ◀── targetRevision: vX.Y.Z
                                                 ArgoCD (AppProject homelab-apps) sincroniza
```

## Criar uma app a partir do template

1. **Novo repo:** em *Use this template* → *Create a new repository* na org `bernats-homelab`. Pode ser privado.
2. **Inicializar** (no WSL, com `make deps` já rodado):
   ```bash
   scripts/init.sh <nome>     # nome DNS-1123: vira Deployment/Service e https://<nome>.<sua-tailnet>
   pre-commit install
   make test
   ```
   O CI falha enquanto o placeholder `app-template` existir em `deploy/` ou `app/`.
3. **Código:** troque `app/`, `nginx.conf` e o `Dockerfile` pela sua aplicação. Mantenha:
   - usuário não-root, com o `runAsUser` correspondente em `deploy/base/deployment.yaml`;
   - porta `8080` e um endpoint `/healthz` (ou ajuste as probes e o teste do CI);
   - imagem base por digest.
4. **Primeiro release:** *Actions → release → Run workflow* na `main` com `v0.1.0`. O workflow publica `ghcr.io/<repo>:v0.1.0`, grava o digest em `deploy/base/kustomization.yaml`, comita na `main` e cria a tag e o GitHub Release.
5. **Publicar no cluster:** PR no repo central adicionando a app em `kubernetes/apps/values.yaml`. O resumo do job de release mostra o trecho pronto:
   ```yaml
   apps:
     <nome>:
       repoURL: https://github.com/bernats-homelab/<repo>
       targetRevision: v0.1.0
   ```
   Depois do merge, o ArgoCD cria o namespace `<nome>` e sincroniza `deploy/overlays/tailscale`.

Para cada versão nova: rode o release com `vX.Y.Z` e abra o PR no central trocando o `targetRevision`.

## O que o cluster espera deste repo

| Caminho | Uso |
|---|---|
| `deploy/base` | Sincronizado no CI do central (sem Tailscale). Sem `namespace:`: ele vem da Application. Sem Ingress. |
| `deploy/overlays/tailscale` | Sincronizado no notebook: `base` + Ingress `ingressClassName: tailscale`. |
| `images: app-image` em `deploy/base/kustomization.yaml` | Sempre por digest, gravado pelo `release.yaml`. Não edite à mão. |
| tags `vX.Y.Z` | O central só aceita tags semver (o `values.schema.json` dele valida). |

As Applications de apps externas rodam no AppProject `homelab-apps`. Ele só aceita repos `bernats-homelab/*`, não permite recursos cluster-scoped (fora `Namespace`) e bloqueia os namespaces do sistema e da plataforma (`argocd`, `kube-system`, `tailscale`, `cnpg-system`, `immich`…). Um `ClusterRole`, CRD ou webhook neste repo falha no sync.

Os manifests precisam passar no `kube-linter` (`.kube-linter.yaml`): probes, requests de CPU/memória, `runAsNonRoot`, `readOnlyRootFilesystem`, capabilities removidas. Precisa escrever em disco? Monte um `emptyDir`, como o `/tmp` do exemplo.

## Segredos

Os segredos são commitados criptografados (SOPS + age), e o ArgoCD os descriptografa com KSOPS usando a chave do cluster. O `.sops.yaml` já tem as chaves públicas do WSL (para editar) e do cluster (para sincronizar).

1. Crie o Secret em texto claro, por exemplo `deploy/base/app-secret.sops.yaml` (`kind: Secret`, `stringData`), e criptografe **no lugar**:
   ```bash
   sops encrypt --in-place deploy/base/app-secret.sops.yaml
   ```
2. Liste o arquivo em `files:` de [deploy/base/secret-generator.yaml](deploy/base/secret-generator.yaml) e descomente `generators:` na kustomization.
3. Para editar depois: `sops deploy/base/app-secret.sops.yaml`.

O hook `sops-encrypted` barra arquivos descriptografados. No pre-commit e no CI, sem chave, o `scripts/ksops-stub.py` gera o Secret com valores placeholder só para validar a estrutura.

## Repos privados

- **Git:** o ArgoCD lê os repos da org com uma GitHub App, configurada no repo central. Confira se a App está instalada no repo novo (ou em *All repositories*).
- **Imagens:** os pacotes GHCR de repos privados são privados. O k3s autentica no `ghcr.io` (`registries.yaml`, configurado pelo central), então não é preciso `imagePullSecret`.

## Desenvolvimento

| Comando | O que faz |
|---|---|
| `make deps` | Ferramentas com versão e sha256 fixados em `~/.local/bin` (as mesmas do central) |
| `make test` | pre-commit: higiene, gitleaks, yamllint, shellcheck/shfmt, actionlint, sops, kubeconform + kube-linter |
| `make build` | `docker build` local |

O CI ([ci.yaml](.github/workflows/ci.yaml)) roda o mesmo pre-commit. Depois sobe um k3s no runner (mesma versão do notebook) com a imagem construída no job e confere que `deploy/base` fica Available e responde `/healthz`.

O próprio template é o *smoke app* do e2e do repo central: o central sincroniza uma tag deste repo para provar o caminho repo externo → AppProject → Application.
