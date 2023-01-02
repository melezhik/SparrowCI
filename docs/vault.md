# Vault

Hashicorp Vault integration

# Install vault

Follow vault docs - https://developer.hashicorp.com/vault/docs/install

# Enable KV secrets engine with a root path

The root path should be named `kv`

```bash
vault secrets enable -path=kv kv
```

# Configure SparrowCI services

Adjust SparrowCI ui configuration file:

`~/sparkyci.yaml`

```yaml
use_secrets: true
```

instruct services with vault configuration data - vault http address
and vault API token:

```bash
sparman.raku worker stop
sparman.raku ui stop

sparman.raku --env VAULT_TOKEN=$TOKEN --env VAULT_ADDR='http://127.0.0.1:8200' worker start
sparman.raku --env VAULT_TOKEN=$TOKEN --env VAULT_ADDR='http://127.0.0.1:8200' ui start
```

That is it. SparrowCI is now integrated with vault.

# See also

[secrets management](docs/dsl.md#secrets-management)
