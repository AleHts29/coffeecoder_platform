# CoffeeCoder · imagen de producción: un binario que sirve API + PWA.
# Portable: la usa Railway hoy y cualquier host de contenedores mañana.

# --- PWA ---------------------------------------------------------------------
FROM node:24-alpine AS web
WORKDIR /src/web
COPY web/package.json web/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY web/ ./
RUN npm run build

# --- API ---------------------------------------------------------------------
FROM golang:1.25-alpine AS api
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY cmd/ cmd/
COPY internal/ internal/
COPY db/ db/
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api

# --- Runtime -----------------------------------------------------------------
# distroless/static trae certificados CA (Bunny, Mercado Pago, Resend) y
# corre como usuario sin privilegios.
FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=api /out/api /app/api
COPY --from=web /src/web/dist /app/web
ENV APP_ENV=production \
    WEB_DIST=/app/web
EXPOSE 8080
ENTRYPOINT ["/app/api"]
