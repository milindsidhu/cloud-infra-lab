# Build a Multi-Platform langApp Image

Replace `<IMAGE_NAME>` with your registry/repository:tag.

## Single platform

```bash
docker buildx build --platform linux/amd64 -t <IMAGE_NAME> .
```

## Multi-platform

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t <IMAGE_NAME> . --push
```
