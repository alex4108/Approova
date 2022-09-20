FROM alpine:3.15
ENV APPROOVA_DB_PATH /content/sqlite.db

RUN apk add sqlite
RUN mkdir -p /app/
RUN mkdir -p /content/
COPY ./bin/approova /app/approova
RUN chmod +x /app/approova

ENTRYPOINT ["/bin/sh"]