FROM python:3.13-slim

WORKDIR /code
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

CMD ["sh", "-c", "alembic upgrade head && python -m app.scripts.seed && uvicorn main:app --host 0.0.0.0 --port 8000"]
