
# OpenCode (opencode)

Installs OpenCode - the open source coding agent. Optionally starts the web UI on container start with an auto-derived port per project.

## Example Usage

```json
"features": {
    "ghcr.io/ssmirr/devcontainer-features/opencode:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | OpenCode version to install (e.g. '1.2.27' or 'latest') | string | latest |
| permission | Default permission level for all actions | string | allow |
| web | Start the OpenCode web UI automatically on container start | boolean | true |
| port | Port for the web UI. 'auto' derives a stable port from the project name. | string | auto |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/ssmirr/devcontainer-features/blob/main/src/opencode/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
