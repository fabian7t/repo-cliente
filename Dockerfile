FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
COPY health /usr/share/nginx/html/