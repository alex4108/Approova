FROM qmcgaw/godevcontainer
RUN apk add make --update gcc musl-dev sqlite
RUN go install github.com/go-delve/delve/cmd/dlv@latest
RUN go install github.com/mattn/go-sqlite3