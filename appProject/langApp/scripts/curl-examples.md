# langApp /run Endpoint Examples

Replace `<HOST>` with your ingress hostname (e.g. `runner-api.example.com`).

## Python example (multi-file)

```bash
curl -X POST https://<HOST>/run \
  -F "language=python" \
  -F "files=@tests/python/main.py" \
  -F "files=@tests/python/helper.py"
```

## Go single-file example

```bash
curl -X POST https://<HOST>/run \
  -F "language=go" \
  -F "files=@tests/go/single/main.go"
```

## Go multi-file example

```bash
curl -X POST https://<HOST>/run \
  -F "language=go" \
  -F "files=@tests/go/multi/main.go" \
  -F "files=@tests/go/multi/helper.go" \
  -F "files=@tests/go/multi/math.go"
```
