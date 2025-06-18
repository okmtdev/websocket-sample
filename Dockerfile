# index.htmlを配信するだけの超簡易Webサーバー
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
