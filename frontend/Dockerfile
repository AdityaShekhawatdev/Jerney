# --- stage 1 ---

FROM node:22-alpine AS build

WORKDIR /app

COPY package*json ./

RUN npm ci && npm cache clean --force

COPY . .

RUN npm run build

# --- stage 2 ---

FROM nginx:alpine AS production

RUN apk update && apk upgrade

COPY nginx.conf /etc/nginx/conf.d/default.conf 

COPY --from=build /app/dist /usr/share/nginx/html

RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

USER nginx

EXPOSE 8080

CMD [ "nginx", "-g", "daemon off;" ]

