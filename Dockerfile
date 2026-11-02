# App de exemplo: página estática servida pelo nginx sem root na porta 8080.
# Troque pelo build da sua aplicação; mantenha usuário não-root, porta 8080 e /healthz
# (ou ajuste deploy/base/deployment.yaml). Imagem base sempre por digest.
FROM nginxinc/nginx-unprivileged:1.30.6-alpine@sha256:f5116ed4606f3eb015dd4a8e28cb9b351476dc0ad4bc6e9f93b19cec130cdf03

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY app/ /usr/share/nginx/html/

EXPOSE 8080
