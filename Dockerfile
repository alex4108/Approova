FROM python:3.7
RUN mkdir /app
COPY src/bot.py /app/bot.py
COPY src/.env /app/.env
COPY requirements.txt /app/
WORKDIR /app
RUN pip install -r requirements.txt
CMD ["python", "bot.py"]