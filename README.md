# CodeLab Helm Chart

Helm chart для развертывания микросервисной платформы CodeLab в Kubernetes.

## Описание

Этот Helm chart развертывает следующие компоненты:

- **Gateway** - API Gateway для маршрутизации запросов
- **Auth Service** - Сервис аутентификации и авторизации
- **Agent Runtime** - Среда выполнения агентов
- **LLM Proxy** - Прокси для работы с LLM моделями
- **Redis** - Кэш и хранилище сессий
- **PostgreSQL** - Реляционная база данных

## Предварительные требования

- Kubernetes 1.19+
- Helm 3.0+
- Nginx Ingress Controller (если используется Ingress)
- Persistent Volume provisioner (для хранения данных)

## Установка

### Базовая установка

```bash
helm install codelab ./codelab
```

### Установка с кастомными значениями

```bash
helm install codelab ./codelab -f custom-values.yaml
```

### Установка в определенный namespace

```bash
kubectl create namespace codelab
helm install codelab ./codelab -n codelab
```

## Конфигурация

### Основные параметры

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `environment` | Окружение развертывания | `development` |
| `replicaCount` | Количество реплик | `1` |

### Ingress

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `ingress.enabled` | Включить Ingress | `true` |
| `ingress.className` | Класс Ingress контроллера | `nginx` |
| `ingress.host` | Хост для доступа | `codelab.example.com` |
| `ingress.tls` | Включить TLS | `false` |

### Образы

Для каждого сервиса можно настроить образ:

```yaml
images:
  authService:
    repository: your-registry/auth-service
    tag: latest
    pullPolicy: IfNotPresent
```

### Базы данных

#### Auth Service

```yaml
services:
  authService:
    database:
      type: "sqlite"  # или "postgres"
      sqliteUrl: "sqlite:///data/auth.db"
      # Для PostgreSQL:
      # type: "postgres"
      # host: "postgres"
      # port: 5432
      # name: "auth_db"
      # user: "codelab"
      # password: "codelab_password"
```

#### Agent Runtime

```yaml
services:
  agentRuntime:
    database:
      type: "sqlite"  # или "postgres"
      sqliteUrl: "sqlite:///data/agent_runtime.db"
```

### Persistent Storage

Для каждого сервиса можно настроить хранилище:

```yaml
services:
  authService:
    persistence:
      data:
        enabled: true
        size: 1Gi
        storageClass: ""  # Использовать default StorageClass
```

### Ресурсы

Настройка ресурсов для каждого сервиса:

```yaml
resources:
  gateway:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 512Mi
```

## Примеры использования

### Пример 1: Минимальная конфигурация для разработки

```yaml
# dev-values.yaml
environment: development
replicaCount: 1

ingress:
  enabled: true
  host: codelab.local
  tls: false

services:
  authService:
    database:
      type: sqlite
  agentRuntime:
    database:
      type: sqlite
```

```bash
helm install codelab ./codelab -f dev-values.yaml
```

### Пример 2: Production конфигурация с внешней БД

```yaml
# prod-values.yaml
environment: production
replicaCount: 3

ingress:
  enabled: true
  host: codelab.example.com
  tls: true
  tlsSecretName: codelab-tls

services:
  authService:
    database:
      type: postgres
      host: external-postgres.example.com
      port: 5432
      name: auth_db
      user: codelab_user
      password: "secure-password"
    secrets:
      AUTH_SERVICE__MASTER_KEY: "production-master-key"
  
  agentRuntime:
    database:
      type: postgres
      host: external-postgres.example.com
      port: 5432
      name: agent_runtime
      user: codelab_user
      password: "secure-password"
  
  postgres:
    enabled: false  # Используем внешнюю БД

resources:
  gateway:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 2000m
      memory: 1Gi
```

```bash
helm install codelab ./codelab -f prod-values.yaml -n production
```

### Пример 3: Отключение внутреннего PostgreSQL

```yaml
services:
  postgres:
    enabled: false
  
  authService:
    database:
      type: postgres
      url: "postgresql+asyncpg://user:pass@external-host:5432/auth_db"
  
  agentRuntime:
    database:
      type: postgres
      url: "postgresql+asyncpg://user:pass@external-host:5432/agent_runtime"
```

## Обновление

```bash
helm upgrade codelab ./codelab -f values.yaml
```

## Удаление

```bash
helm uninstall codelab
```

**Внимание:** PersistentVolumeClaims не удаляются автоматически. Для их удаления:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=codelab
```

## Проверка статуса

```bash
# Статус релиза
helm status codelab

# Статус подов
kubectl get pods -l app.kubernetes.io/instance=codelab

# Логи
kubectl logs -l app.kubernetes.io/instance=codelab -f

# Проверка Ingress
kubectl get ingress
```

## Troubleshooting

### Проблемы с подключением к БД

Проверьте логи сервиса:
```bash
kubectl logs -l app.kubernetes.io/component=auth-service
```

Проверьте секреты:
```bash
kubectl get secret codelab-auth-service-secret -o yaml
```

### Проблемы с Persistent Volumes

Проверьте PVC:
```bash
kubectl get pvc
kubectl describe pvc codelab-auth-service-data
```

### Проблемы с Ingress

Проверьте Ingress:
```bash
kubectl describe ingress codelab
```

Проверьте логи Ingress контроллера:
```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

## Безопасность

⚠️ **ВАЖНО:** Перед развертыванием в production:

1. Измените все секретные значения в `values.yaml`
2. Используйте Kubernetes Secrets или внешние системы управления секретами (Vault, Sealed Secrets)
3. Включите TLS для Ingress
4. Настройте Network Policies
5. Используйте внешнюю PostgreSQL БД с резервным копированием

## Лицензия

[Укажите лицензию]
