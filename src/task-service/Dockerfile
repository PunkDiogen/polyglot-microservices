FROM golang:1.26-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o task-service ./cmd

FROM alpine:latest
RUN adduser -D -s /bin/sh taskuser
WORKDIR /app
COPY --from=builder /app/task-service .
RUN chown taskuser:taskuser task-service
USER taskuser
EXPOSE 8080
ENTRYPOINT ["./task-service"]
