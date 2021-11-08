
from node:lts as builder
workdir hubs
copy . .
env BASE_ASSETS_PATH="{{rawhubs-base-assets-path}}"
run npm ci 
run npm run build
run cd admin && npm ci && npm run build && cp -R dist/* ../dist && cd ..
run mkdir -p dist/pages && mv dist/*.html dist/pages && mv dist/hub.service.js dist/pages && mv dist/schema.toml dist/pages          
#[info] rearrange files
run mkdir rawhubs && mv dist/pages rawhubs && mv dist/assets rawhubs && mv dist/react-components rawhubs/pages && mv dist/favicon.ico rawhubs/pages

from alpine/openssl as ssl
run mkdir /ssl && openssl req -x509 -newkey rsa:2048 -sha256 -days 36500 -nodes -keyout /ssl/key -out /ssl/cert -subj '/CN=hubs'

from nginx:alpine
run apk add bash
run mkdir /ssl && mkdir -p /www/hubs && mkdir -p /www/hubs/pages && mkdir -p /www/hubs/assets
copy --from=ssl /ssl /ssl
copy --from=builder /hubs/rawhubs/pages /www/hubs/pages
copy --from=builder /hubs/rawhubs/assets /www/hubs/assets
run echo "server {listen 8080 ssl;ssl_certificate /ssl/cert;ssl_certificate_key /ssl/key; location / {root /www;autoindex off;add_header 'Access-Control-Allow-Origin' '*';}}" > /etc/nginx/conf.d/default.conf
run printf 'while true; do (echo -e "HTTP/1.1 200 OK\r\n") | nc -lp 1111 > /dev/null; done' > /healthcheck.sh && chmod +x /healthcheck.sh
run printf ' \n\
find /www/hubs/ -type f -name *.html -exec sed -i "s/{{rawhubs-base-assets-path}}\//https:\/\/${SUB_DOMAIN}-assets.${DOMAIN}\/hubs\//g" {} \; \n\          
find /www/hubs/ -type f -name *.html -exec sed -i "s/{{rawhubs-base-assets-path}}/https:\/\/${SUB_DOMAIN}-assets.${DOMAIN}\/hubs\//g" {} \; \n\
find /www/hubs/ -type f -name *.css -exec sed -i "s/{{rawhubs-base-assets-path}}\//https:\/\/${SUB_DOMAIN}-assets.${DOMAIN}\/hubs\//g" {} \; \n\
find /www/hubs/ -type f -name *.css -exec sed -i "s/{{rawhubs-base-assets-path}}/https:\/\/${SUB_DOMAIN}-assets.${DOMAIN}\/hubs\//g" {} \; \n\            
anchor="<!-- DO NOT REMOVE\/EDIT THIS COMMENT - META_TAGS -->" \n\
for f in /www/hubs/pages/*.html; do \n\
    for var in $(printenv); do \n\
    var=$(echo $var | cut -d"=" -f1 ); prefix="turkeyCfg_"; \n\
    [[ $var == $prefix* ]] && sed -i "s/$anchor/ <meta name=\"env:${var#$prefix}\" content=\"${!var//\//\\\/}\"\/> $anchor/" $f; \n\
    done \n\
done \n\
/healthcheck.sh& \n\
nginx -g "daemon off;" \n\n' > /run.sh
run chmod +x /run.sh && cat /run.sh
cmd bash /run.sh