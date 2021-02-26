FROM python:3.8
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
WORKDIR /app
COPY requirements.txt /app/
RUN mkdir /app/content
COPY src/bot.py /app/bot.py
COPY src/.env /app/.env
ENTRYPOINT ["/docker-entrypoint.sh"]
