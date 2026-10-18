FROM python:3.12-slim

# Set environment variable to add ~/.local/bin to PATH
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app

COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Install kubectl matching the container architecture
RUN apt-get update && apt-get install -y --no-install-recommends bash curl ca-certificates \
        && KUBECTL_VERSION=$(curl -Lsk https://dl.k8s.io/release/stable.txt) \
        && ARCH=$(uname -m) \
        && case "$ARCH" in \
             x86_64) KUBE_ARCH=amd64 ;; \
             aarch64) KUBE_ARCH=arm64 ;; \
             arm64) KUBE_ARCH=arm64 ;; \
             *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; \
           esac \
        && curl -kLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBE_ARCH}/kubectl" \
        && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
        && rm kubectl \
        && apt-get clean && rm -rf /var/lib/apt/lists/*

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
