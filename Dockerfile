FROM alpine:3.15
ENV APPROOVA_DB_PATH /content/sqlite.db

RUN mkdir -p /app/
RUN mkdir -p /content/
COPY ./bin/approova /app/approova
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/app/approova"]