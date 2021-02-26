FROM python:3.8
WORKDIR /app
COPY requirements.txt /app/
RUN pip install -r requirements.txt
RUN mkdir /app/content
COPY src/bot.py /app/bot.py
COPY src/.env /app/.env
CMD ["python3", "bot.py"]