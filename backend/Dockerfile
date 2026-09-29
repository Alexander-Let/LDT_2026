# syntax=docker/dockerfile:1

FROM golang:1.27-alpine AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/server ./cmd/server \
    && CGO_ENABLED=0 go build -trimpath -o /out/migrate ./cmd/migrate \
    && CGO_ENABLED=0 go build -trimpath -o /out/profiles ./cmd/profiles \
    && CGO_ENABLED=0 go build -trimpath -o /out/content ./cmd/content \
    && CGO_ENABLED=0 go build -trimpath -o /out/parents ./cmd/parents \
    && CGO_ENABLED=0 go build -trimpath -o /out/gateway ./cmd/gateway

FROM alpine:3.21
RUN adduser -D -u 10001 finni
COPY --from=build /out/server /app/server
COPY --from=build /out/migrate /app/migrate
COPY --from=build /out/profiles /app/profiles
COPY --from=build /out/content /app/content
COPY --from=build /out/parents /app/parents
COPY --from=build /out/gateway /app/gateway
USER finni
EXPOSE 8080
CMD ["/app/gateway"]
