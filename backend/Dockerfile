# Stage 1

FROM node:22-alpine AS build

WORKDIR /app

COPY package*.json ./

RUN npm ci --only=production && npm cache clean --force


# stage 2

FROM node:22-alpine AS prod

WORKDIR /app

COPY --from=build /app/node_modules ./node_modules

COPY src/ ./src

COPY package*.json ./

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

RUN chown -R appuser:appgroup /app

USER appuser   

EXPOSE "5000"

CMD [ "node", "src/index.js" ]