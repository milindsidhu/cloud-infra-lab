# Useful Snippets

## Temporarily swap git identity

Save the current identity, set a temporary one, restore later:

```bash
# Save current
OLD_NAME=$(git config --global user.name)
OLD_EMAIL=$(git config --global user.email)

# Set temporary
git config --global user.name "New Name"
git config --global user.email "new.email@example.com"

# Restore
git config --global user.name "$OLD_NAME"
git config --global user.email "$OLD_EMAIL"
```

## Create SSH key using git user email

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
  ssh-keygen -t ed25519 -C "$(git config --global user.email)" \
    -f ~/.ssh/id_ed25519 -N ""
```
