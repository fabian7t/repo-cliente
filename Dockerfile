@"
FROM nginx:alpine
ARG VERSION=blue
COPY index.html /usr/share/nginx/html/index.html
COPY health /usr/share/nginx/html/health
"@ | Set-Content Dockerfile