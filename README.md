![polyglot microservices](/assets/polygot-microservices.png)

# Polyglot Microservices Platform

**Kubernetes-адаптация** микросервисного проекта. Изначально проект разрабатывался для локального запуска через Docker Compose. Я полностью переработал его для продакшен-развёртывания в Kubernetes с упором на безопасность и отказоустойчивость.

> **Оригинальный проект:** [polyglot-microservices](https://github.com/TopSwagCode/polyglot-microservices) от [TopSwagCode](https://github.com/TopSwagCode)  
> **Моя адаптация:** миграция на Kubernetes, интеграция HashiCorp Vault, переработка Docker-образов, Helm-чарт.

---

## 📋 Требования к стенду

### Hardware (минимальные)
- **RAM:** 8 GB
- **CPU:** 4 cores
- **Disk:** 50 GB (для образов и PVC)

### Software
- **OS:** Ubuntu 22.04+ (или любой Linux с поддержкой Kubernetes)
- **Kubernetes:** 1.36+
- **Helm:** 3+
- **Vault CLI** (для запуска vault-init.sh)
- **Доменное имя** с настроенным A-запросом

### Установленные в кластере компоненты
Перед развёртыванием платформы убедитесь, что в кластере установлены:

| Компонент | Назначение |
|-----------|------------|
| **HashiCorp Vault** | Хранилище секретов |
| **Vault Agent Injector** | Автоматическая доставка секретов в поды |
| **Longhorn** | Распределённое блочное хранилище (должен быть default StorageClass) |
| **Contour** | Ingress-контроллер |
| **cert-manager** или **certbot** | TLS-сертификаты |

### Проверка готовности

```bash
# Проверьте StorageClass
kubectl get storageclass
# Должен быть longhorn (или другой) с пометкой (default)

# Проверьте Ingress Controller
kubectl get pods -n projectcontour
# Должны быть contour и envoy в статусе Running

# Проверьте Vault
kubectl get pods -n vault
# Должны быть vault-0 и vault-agent-injector-* в статусе Running
```

---

## Быстрый старт

```bash
# 1. Клонируйте репозиторий
git clone https://github.com/PunkDiogen/polyglot-microservices.git
cd polyglot-microservices

# 2. Подготовьте секреты
cp helm/polyglot-microservices/values.local.example.yaml helm/polyglot-microservices/values.local.yaml
# Отредактируйте values.local.yaml: замените REPLACE_ME на реальные пароли

# 3. Установите Vault (если ещё не установлен)
# Инструкция: https://developer.hashicorp.com/vault/docs/platform/k8s/helm

# 4. Настройте Vault
export VAULT_TOKEN="ваш_root_token"
export CONNECTION_STRING_AUTH="Host=postgres-auth-svc;Database=authdb;Username=...;Password=..."
export DB_DSN="host=postgres-task-svc user=... password=... dbname=... port=5432 sslmode=disable"
export MONGODB_URL="mongodb://root:...@mongo-svc:27017"

kubectl port-forward -n vault vault-0 8200:8200 &
export VAULT_ADDR="http://127.0.0.1:8200"
sh helm/polyglot-microservices/scripts/vault-init.sh

# 5. Разверните платформу
helm install polyglot ./helm/polyglot-microservices -n default -f helm/polyglot-microservices/values.local.yaml

# 6. Проверьте
kubectl get pods -n default
```

---

## Архитектура

```
                          ┌──────────┐
                          │ Frontend │
                          │  React   │
                          │  :3000   │
                          └────┬─────┘
                               │
                          ┌────▼─────┐
                          │   API    │
                          │ Gateway  │
                          │ C# .NET  │
                          │  :5000   │
                          └────┬─────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
     ┌────▼─────┐         ┌────▼─────┐        ┌─────▼─────┐
     │   Auth   │         │   Task   │        │ Analytics │
     │ C# .NET  │         │    Go    │        │  Python   │
     │  :5000   │         │  :8080   │        │   :8000   │
     └────┬─────┘         └────┬─────┘        └─────┬─────┘
          │                    │                    │
     ┌────▼─────┐         ┌────▼─────┐        ┌─────▼─────┐
     │ Postgres │         │ Postgres │        │   Mongo   │
     │  (Auth)  │         │  (Task)  │        │  :27017   │
     └──────────┘         └────┬─────┘        └───────────┘
                               │
                          ┌────▼─────┐
                          │  Workers │
                          │  Python  │
                          └────┬─────┘
                               │
                          ┌────▼─────┐
                          │   Kafka  │
                          │ Redpanda │
                          │  :9092   │
                          └────┬─────┘
                               │
                       ┌───────▼─────────┐
                       │  HashiCorp      │
                       │  Vault          │
                       │  (секреты)      │
                       └─────────────────┘
```

### Поток данных

1. **Frontend** (React) отправляет запросы в **API Gateway** (C#).
2. **API Gateway** проксирует запросы к нужному сервису и проверяет JWT-токены.
3. **Auth Service** (C#) регистрирует пользователей, выдаёт JWT, хранит данные в своём PostgreSQL.
4. **Task Service** (Go) управляет задачами и проектами, публикует события (`task.created`, `task.updated`) в **Kafka (Redpanda)**.
5. **Analytics Worker** (Python) потребляет события из Kafka и обновляет метрики в **MongoDB**.
6. **Analytics Service** (Python) отдаёт агрегированную статистику через REST API.
7. **Все секреты приложений** (строки подключения к БД) хранятся в **HashiCorp Vault** и доставляются в поды через **Vault Agent Injector**. JWT-ключи и пароли БД хранятся в `values.local.yaml` и передаются через Kubernetes Secrets.

---

## Что я изменил относительно оригинала

### Безопасность
1. **Dockerfile'ы**: приложения запускаются от непривилегированного пользователя (в оригинале — от root).
2. **Vault**: все секреты вынесены из `.env`-файлов в HashiCorp Vault.
3. **Vault Agent Injector**: sidecar-контейнер автоматически получает секреты и кладёт их в общий том пода.
4. **RBAC**: для каждого сервиса создан отдельный ServiceAccount, настроены роли и политики в Vault.

### Отказоустойчивость
5. **Longhorn**: распределённое блочное хранилище для PostgreSQL, MongoDB и самого Vault.
6. **StatefulSet**: базы данных развёрнуты как StatefulSet с PersistentVolume.
7. **Vault в production-режиме**: после перезагрузки данные не теряются.

### Инфраструктура
8. **Helm-чарт**: все манифесты параметризованы, установка одной командой.
9. **Contour + certbot**: ingress-контроллер и TLS-сертификаты.
10. **Redpanda**: Kafka-совместимый брокер, замена стандартному Kafka.
11. **Скрипт vault-init.sh**: автоматическая настройка Vault после перезагрузки (политики, роли, секреты).

---

## Технологический стек

| Категория | Технология |
|-----------|------------|
| **Языки** | C# (.NET 9), Go 1.22+, Python 3.11+ |
| **Фронтенд** | React (TypeScript) |
| **Базы данных** | PostgreSQL 15, MongoDB 4.4 |
| **Брокер сообщений** | Redpanda (Kafka-совместимый) |
| **Оркестрация** | Kubernetes 1.36 |
| **Пакетный менеджер** | Helm 3 |
| **Ingress** | Contour + Envoy |
| **Хранилище** | Longhorn |
| **Секреты** | HashiCorp Vault |
| **TLS** | Let's Encrypt (certbot) |

---

## Как работает Vault

### Аутентификация
Каждый под имеет свой **ServiceAccount**. При запуске init-контейнер (`vault-agent-init`) использует JWT-токен этого ServiceAccount для входа в Vault.

### Авторизация
В Vault настроены **роли**, которые привязаны к ServiceAccount'ам:
- `auth-service` → роль `auth-service` → доступ к `CONNECTION_STRING_AUTH`
- `task-service` → роль `task-service` → доступ к `DB_DSN`
- `analytics-service` → роль `analytics` → доступ к `MONGODB_URL`
- `analytics-worker` → роль `analytics` → доступ к `MONGODB_URL`

### Доставка секретов
Vault Agent Injector добавляет в под:
1. **init-контейнер** — получает секреты и записывает в файл `/vault/secrets/*`
2. **sidecar-контейнер** — обновляет секреты, если они изменились
3. Основной контейнер читает секреты из файла при старте

---

## 🔹 GitOps с ArgoCD

Для непрерывного деплоя используется ArgoCD. Все изменения в инфраструктуре и сервисах отслеживаются из Git-репозитория.
### Установка ArgoCD:
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.0/manifests/install.yaml
```
### Application манифест для ArgoCD:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: polyglot-services
  namespace: argocd
spec:
  destination:
    namespace: default
    server: https://kubernetes.default.svc
  source:
    path: helm/polyglot-microservices
    repoURL: https://github.com/PunkDiogen/polyglot-microservices
    targetRevision: main
    helm:
      values: |-
        domain: your-domain.com        # ← замените на свой домен
        tlsSecret: your-tls-secret     # ← замените на свой секрет с TLS-сертификатом
        # ... остальные значения в values.local.yaml
  project: default
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
  ```    
---

## 🔹 Мониторинг

Развернут стек **kube-prometheus-stack** (Prometheus + Grafana + Alertmanager) для сбора метрик со всех сервисов и инфраструктуры.

### Компоненты:
- **kube-prometheus-stack** — установлен через Helm из OCI-репозитория `ghcr.io/prometheus-community/charts/kube-prometheus-stack`
- **Prometheus** — сбор метрик
- **Grafana** — дашборды и визуализация
- **ServiceMonitor'ы** — автоматический сбор метрик с auth, task, analytics, api-gateway

### Дашборды:
![Grafana Dashboard](/assets/grafana.png)

---
## Структура репозитория

```
polyglot-microservices/
├── helm/
│   └── polyglot-microservices/    # Helm-чарт
│       ├── Chart.yaml
│       ├── values.yaml            # Значения по умолчанию (с REPLACE_ME)
│       ├── values.local.example.yaml  # Пример для локальной настройки
│       ├── templates/             # Шаблоны манифестов
│       │   ├── secret.yaml
│       │   ├── serviceaccounts.yaml
│       │   ├── kafka.yaml
│       │   ├── mongo.yaml
│       │   ├── postgres-auth.yaml
│       │   ├── postgres-task.yaml
│       │   ├── authService.yaml
│       │   ├── taskService.yaml
│       │   ├── analyticsService.yaml
│       │   ├── analyticsWorkerTask.yaml
│       │   ├── analyticsWorkerProject.yaml
│       │   ├── apiGateway.yaml
│       │   ├── frontend.yaml
│       │   └── httpproxy.yaml
│       └── scripts/
│           └── vault-init.sh      # Автонастройка Vault
├── src/                           # Исходный код сервисов
├── assets/                        # Изображения, gif-анимации
└── README.md
```

---

## Лицензия

Проект основан на [polyglot-microservices](https://github.com/TopSwagCode/polyglot-microservices) от [TopSwagCode](https://github.com/TopSwagCode). Лицензия оригинального проекта не указана.

Kubernetes-адаптация, интеграция с Vault и Helm-чарт — [Mikhail (PunkDiogen)](https://github.com/PunkDiogen), 2026.
