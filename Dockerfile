FROM golang:alpine AS builder
WORKDIR /app
COPY . .
RUN go mod tidy && go mod download &&  go build -o main .

FROM alpine:latest  
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 80
CMD ["./main"]
