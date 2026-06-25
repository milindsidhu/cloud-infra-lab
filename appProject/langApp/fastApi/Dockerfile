FROM python:3.12-slim

# Set environment variable to add ~/.local/bin to PATH
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app

COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Install just what's needed for shell access
RUN apt-get update && apt-get install -y --no-install-recommends bash curl ca-certificates \
        && KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt) \
        && curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
        && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
        && rm kubectl \
        && apt-get clean && rm -rf /var/lib/apt/lists/*

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
