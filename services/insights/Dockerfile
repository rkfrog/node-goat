ARG REGISTRY_URL DOCKER_REPO_NAME

FROM ${REGISTRY_URL}/${DOCKER_REPO_NAME}/python:3.10-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "-m", "insights.app"]
