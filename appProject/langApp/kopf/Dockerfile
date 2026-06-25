FROM python:3.11-slim

# Install just what's needed for shell access
RUN apt-get update && apt-get install -y --no-install-recommends bash curl ca-certificates \
        && KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt) \
        && curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
        && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
        && rm kubectl \
        && apt-get clean && rm -rf /var/lib/apt/lists/*

# Optional: Create log directory
RUN mkdir -p /var/log/secretreplicator

WORKDIR /app
COPY . /app

CMD ["kopf", "run", "--standalone", "--verbose", "operator.py"]


# FROM python:3.11

# WORKDIR /app
# COPY operator.py .

# RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
#     && KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt) \
#     && curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
#     && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
#     && rm kubectl \
#     && apt-get clean && rm -rf /var/lib/apt/lists/*

# RUN pip install kopf kubernetes

# CMD ["kopf", "run", "--standalone", "operator.py"]
