FROM alpine:3.15 AS build
RUN apk update
RUN apk upgrade
RUN apk add --update go gcc g++
WORKDIR /app
COPY ./src /app
RUN go install github.com/mattn/go-sqlite3
RUN CGO_ENABLED=1 GOOS=linux go build -o ./approova

FROM alpine:3.15
ENV APPROOVA_DB_PATH /content/sqlite.db
RUN apk add sqlite
RUN mkdir -p /app/
RUN mkdir -p /content/
COPY --from=build /app/approova /app/approova
RUN chmod +x /app/approova
CMD ["/app/approova"]