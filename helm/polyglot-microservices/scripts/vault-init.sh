#!/bin/bash
# Скрипт настройки Vault для Polyglot Microservices
# Замените REPLACE_ME на реальные значения перед запуском

VAULT_ADDR="http://127.0.0.1:8200"
VAULT_TOKEN="${VAULT_TOKEN:-REPLACE_ME}"

# Секреты — замените на свои
CONNECTION_STRING_AUTH="${CONNECTION_STRING_AUTH:-REPLACE_ME}"
DB_DSN="${DB_DSN:-REPLACE_ME}"
MONGODB_URL="${MONGODB_URL:-REPLACE_ME}"

echo "=== Enabling Kubernetes auth ==="
vault auth enable kubernetes

echo "=== Configuring Kubernetes auth ==="
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc.cluster.local:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  disable_local_ca_jwt="false"

echo "=== Creating policies ==="
vault policy write auth-service-policy - <<EOF
path "auth/kubernetes/login" { capabilities = ["create", "read"] }
path "polyglot-platform/data/app-secrets" { capabilities = ["read"] }
EOF

vault policy write task-service-policy - <<EOF
path "auth/kubernetes/login" { capabilities = ["create", "read"] }
path "polyglot-platform/data/app-secrets" { capabilities = ["read"] }
EOF

vault policy write analytics-policy - <<EOF
path "auth/kubernetes/login" { capabilities = ["create", "read"] }
path "polyglot-platform/data/app-secrets" { capabilities = ["read"] }
EOF

echo "=== Creating roles ==="
vault write auth/kubernetes/role/auth-service \
  bound_service_account_names=auth-service \
  bound_service_account_namespaces=default \
  policies=auth-service-policy \
  ttl=1h

vault write auth/kubernetes/role/task-service \
  bound_service_account_names=task-service \
  bound_service_account_namespaces=default \
  policies=task-service-policy \
  ttl=1h

vault write auth/kubernetes/role/analytics \
  bound_service_account_names=analytics-worker,analytics-service \
  bound_service_account_namespaces=default \
  policies=analytics-policy \
  ttl=1h

echo "=== Enabling KV ==="
vault secrets enable -path=polyglot-platform kv-v2

echo "=== Creating secrets ==="
vault write polyglot-platform/data/app-secrets \
  CONNECTION_STRING_AUTH="$CONNECTION_STRING_AUTH" \
  DB_DSN="$DB_DSN" \
  MONGODB_URL="$MONGODB_URL"

echo "=== DONE ==="
