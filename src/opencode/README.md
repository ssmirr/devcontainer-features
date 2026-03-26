
# OpenCode (opencode)

Installs OpenCode - the open source coding agent. Mounts your host config (plugins, themes, API keys) into the container. Run 'opencode-web' to start the web UI, 'opencode-stop' to stop it.

## Example Usage

```json
"features": {
    "ghcr.io/ssmirr/devcontainer-features/opencode:2": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | OpenCode version to install (e.g. '1.2.27' or 'latest') | string | latest |
| permission | Default permission level for all actions | string | allow |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/ssmirr/devcontainer-features/blob/main/src/opencode/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
