# Stage 1

FROM node:22-alpine AS build

WORKDIR /app

RUN npm install -g npm@latest

COPY package*.json ./

RUN npm ci && npm cache clean --force


# stage 2

FROM node:22-alpine AS prod

WORKDIR /app

COPY --from=build /app/node_modules ./node_modules

COPY src/ ./src

COPY package*.json ./

RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

RUN chown -R appuser:appgroup /app

USER appuser   

EXPOSE "5000"

CMD [ "node", "src/index.js" ]