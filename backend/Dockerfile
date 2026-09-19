# syntax=docker/dockerfile:1

FROM golang:1.27-alpine AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/server ./cmd/server \
    && CGO_ENABLED=0 go build -trimpath -o /out/migrate ./cmd/migrate

FROM alpine:3.21
RUN adduser -D -u 10001 finni
COPY --from=build /out/server /app/server
COPY --from=build /out/migrate /app/migrate
USER finni
EXPOSE 8080
CMD ["/app/server"]
