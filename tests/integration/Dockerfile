FROM python:3.12-slim

WORKDIR /workspace
COPY requirements-dev.txt .
RUN python -m pip install --no-cache-dir --requirement requirements-dev.txt
COPY . .
RUN chmod +x tests/docker-compose-test.sh tests/mock-bin/pct tests/integration/run.sh

CMD ["./tests/integration/run.sh"]
