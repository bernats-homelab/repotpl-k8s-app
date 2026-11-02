# App de exemplo: página estática servida pelo nginx sem root na porta 8080.
# Troque pelo build da sua aplicação; mantenha usuário não-root, porta 8080 e /healthz
# (ou ajuste deploy/base/deployment.yaml). Imagem base sempre por digest.
FROM nginxinc/nginx-unprivileged:1.31.7-alpine@sha256:b5047b9b76845eac124358373c6852377c52e4b05834a47647e955dd91cb8f1e

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY app/ /usr/share/nginx/html/

EXPOSE 8080
