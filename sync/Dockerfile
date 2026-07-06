FROM python:3.12-alpine

WORKDIR /app
COPY sync.py .

USER nobody
CMD ["python", "-u", "sync.py"]
