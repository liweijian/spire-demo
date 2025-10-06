FROM golang:1.24-alpine AS builder
ENV GOPROXY=https://goproxy.cn,direct
WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY proto/ ./proto/
COPY client/ ./client/

WORKDIR /build/client
RUN CGO_ENABLED=0 GOOS=linux go build -o /client .

FROM alpine:latest
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
    && apk --no-cache add ca-certificates
COPY --from=builder /client /client

ENV SPIFFE_ENDPOINT_SOCKET=unix:///spire-agent-socket/agent.sock

ENTRYPOINT ["/client"]
