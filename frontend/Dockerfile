# --- stage 1 ---

FROM node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci && npm cache clean --force

COPY . .

RUN npm run build

# --- stage 2 ---

FROM node:22-alpine AS production

WORKDIR /app

COPY --from=build /app/dist .

EXPOSE 5432

CMD [ "npm", "run", "dev" ]

