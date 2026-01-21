# Конфигурация CodeLab Helm Chart

Этот документ содержит подробное описание всех параметров конфигурации Helm chart.

## Содержание

- [Общие параметры](#общие-параметры)
- [Образы](#образы)
- [Ingress](#ingress)
- [Сервисы](#сервисы)
- [Ресурсы](#ресурсы)
- [Безопасность](#безопасность)
- [Примеры конфигураций](#примеры-конфигураций)

## Общие параметры

### environment

**Тип**: `string`  
**По умолчанию**: `development`  
**Описание**: Окружение развертывания. Влияет на логирование и другие настройки.

**Допустимые значения**:
- `development` - для разработки
- `staging` - для тестирования
- `production` - для продакшена

**Пример**:
```yaml
environment: production
```

### replicaCount

**Тип**: `integer`  
**По умолчанию**: `1`  
**Описание**: Количество реплик для каждого сервиса по умолчанию.

**Рекомендации**:
- Development: `1`
- Staging: `2`
- Production: `3+`

**Пример**:
```yaml
replicaCount: 3
```

### imagePullSecrets

**Тип**: `array`  
**По умолчанию**: `[]`  
**Описание**: Секреты для доступа к приватным Docker registry.

**Пример**:
```yaml
imagePullSecrets:
  - name: harbor-registry
  - name: dockerhub-secret
```

**Создание секрета**:
```bash
kubectl create secret docker-registry harbor-registry \
  --docker-server=harbor.openidealab.com \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  -n codelab
```

## Образы

Все образы настраиваются в секции `images`.

### Общая структура

```yaml
images:
  <service>:
    repository: <registry>/<project>/<image>
    tag: <version>
    pullPolicy: <policy>
```

### Параметры образа

#### repository

**Тип**: `string`  
**Описание**: Полный путь к образу в registry.

**Пример**:
```yaml
repository: harbor.openidealab.com/codelab/gateway
```

#### tag

**Тип**: `string`  
**По умолчанию**: `latest`  
**Описание**: Тег образа.

**Рекомендации**:
- Development: `latest` или `dev`
- Staging: `staging` или конкретная версия
- Production: конкретная версия (например, `v1.2.3`)

**Пример**:
```yaml
tag: v1.2.3
```

#### pullPolicy

**Тип**: `string`  
**По умолчанию**: `IfNotPresent`  
**Описание**: Политика загрузки образа.

**Допустимые значения**:
- `Always` - всегда загружать
- `IfNotPresent` - загружать если отсутствует
- `Never` - никогда не загружать

**Пример**:
```yaml
pullPolicy: Always
```

### Доступные сервисы

- `authService` - Auth Service
- `gateway` - Gateway
- `agentRuntime` - Agent Runtime
- `llmProxy` - LLM Proxy
- `website` - Website
- `redis` - Redis
- `postgres` - PostgreSQL

## Ingress

Настройки внешнего доступа к приложению.

### ingress.enabled

**Тип**: `boolean`  
**По умолчанию**: `true`  
**Описание**: Включить или отключить Ingress.

**Пример**:
```yaml
ingress:
  enabled: true
```

### ingress.className

**Тип**: `string`  
**По умолчанию**: `nginx`  
**Описание**: Класс Ingress контроллера.

**Пример**:
```yaml
ingress:
  className: nginx
```

### ingress.host

**Тип**: `string`  
**По умолчанию**: `codelab.example.com`  
**Описание**: Доменное имя для доступа к приложению.

**Пример**:
```yaml
ingress:
  host: codelab.mycompany.com
```

### ingress.tls

**Тип**: `boolean`  
**По умолчанию**: `false`  
**Описание**: Включить TLS/SSL.

**Пример**:
```yaml
ingress:
  tls: true
  tlsSecretName: codelab-tls
```

### ingress.tlsSecretName

**Тип**: `string`  
**По умолчанию**: `codelab-tls`  
**Описание**: Имя Secret с TLS сертификатом.

### ingress.annotations

**Тип**: `object`  
**Описание**: Аннотации для Ingress.

**Стандартные аннотации**:
```yaml
ingress:
  annotations:
    kubernetes.io/ingress.class: "nginx"
    # Автоматический SSL через cert-manager
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    # Размер тела запроса
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    # Таймауты
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    # Rate limiting
    nginx.ingress.kubernetes.io/rate-limit: "100"
    # WebSocket поддержка
    nginx.ingress.kubernetes.io/websocket-services: "gateway"
```

### ingress.paths

**Тип**: `object`  
**Описание**: Настройка маршрутизации путей.

**Структура**:
```yaml
ingress:
  paths:
    <name>:
      path: <url-path>
      pathType: <type>
      service: <service-name>
      port: <port-number>
```

**По умолчанию**:
```yaml
ingress:
  paths:
    oauth:
      path: /oauth
      pathType: Prefix
      service: auth-service
      port: 8003
    wellknown:
      path: /.well-known
      pathType: Prefix
      service: auth-service
      port: 8003
    api:
      path: /api/v1
      pathType: Prefix
      service: gateway
      port: 8000
    website:
      path: /
      pathType: Prefix
      service: website
      port: 80
```

## Сервисы

Каждый сервис настраивается в секции `services.<serviceName>`.

### Общие параметры сервиса

#### enabled

**Тип**: `boolean`  
**По умолчанию**: `true`  
**Описание**: Включить или отключить сервис.

**Пример**:
```yaml
services:
  postgres:
    enabled: false  # Использовать внешнюю БД
```

#### port

**Тип**: `integer`  
**Описание**: Порт сервиса.

#### type

**Тип**: `string`  
**По умолчанию**: `ClusterIP`  
**Описание**: Тип Kubernetes Service.

**Допустимые значения**:
- `ClusterIP` - внутренний доступ
- `NodePort` - доступ через порт ноды
- `LoadBalancer` - внешний балансировщик

#### env

**Тип**: `object`  
**Описание**: Переменные окружения (несекретные).

**Пример**:
```yaml
services:
  gateway:
    env:
      GATEWAY__LOG_LEVEL: "INFO"
      GATEWAY__WS_HEARTBEAT_INTERVAL: "30"
```

#### secrets

**Тип**: `object`  
**Описание**: Секретные переменные окружения.

**Пример**:
```yaml
services:
  gateway:
    secrets:
      GATEWAY__INTERNAL_API_KEY: "your-secure-api-key"
```

⚠️ **Важно**: Всегда изменяйте секреты перед развертыванием в production!

### Auth Service

#### services.authService.database

**Описание**: Настройки базы данных для Auth Service.

**Параметры**:

##### type

**Тип**: `string`  
**По умолчанию**: `sqlite`  
**Допустимые значения**: `sqlite`, `postgres`

##### sqliteUrl

**Тип**: `string`  
**По умолчанию**: `sqlite:///data/auth.db`  
**Описание**: URL для SQLite базы данных.

##### useInternal

**Тип**: `boolean`  
**По умолчанию**: `true`  
**Описание**: Использовать внутренний PostgreSQL из этого chart.

##### host, port, name, user, password

**Описание**: Параметры подключения к PostgreSQL.

**Пример (SQLite)**:
```yaml
services:
  authService:
    database:
      type: sqlite
      sqliteUrl: "sqlite:///data/auth.db"
```

**Пример (внутренний PostgreSQL)**:
```yaml
services:
  authService:
    database:
      type: postgres
      useInternal: true
      host: postgres
      port: 5432
      name: auth_db
      user: codelab
      password: "secure-password"
```

**Пример (внешний PostgreSQL)**:
```yaml
services:
  authService:
    database:
      type: postgres
      useInternal: false
      host: postgres.example.com
      port: 5432
      name: auth_db
      user: codelab_user
      password: "secure-password"
  
  postgres:
    enabled: false  # Отключить внутренний PostgreSQL
```

**Пример (полный URL)**:
```yaml
services:
  authService:
    database:
      type: postgres
      url: "postgresql+asyncpg://user:pass@host:5432/auth_db"
```

#### services.authService.persistence

**Описание**: Настройки Persistent Volumes.

**Структура**:
```yaml
services:
  authService:
    persistence:
      data:
        enabled: true
        size: 1Gi
        storageClass: ""
      keys:
        enabled: true
        size: 100Mi
        storageClass: ""
```

**Параметры**:
- `enabled` - включить PVC
- `size` - размер volume
- `storageClass` - класс хранилища (пустая строка = default)

#### services.authService.healthcheck

**Описание**: Настройки health check.

**Параметры**:
```yaml
services:
  authService:
    healthcheck:
      enabled: true
      path: /health
      initialDelaySeconds: 5
      periodSeconds: 30
      timeoutSeconds: 10
      failureThreshold: 3
```

### Gateway

**Основные переменные окружения**:

```yaml
services:
  gateway:
    env:
      GATEWAY__LOG_LEVEL: "DEBUG"  # DEBUG, INFO, WARNING, ERROR
      GATEWAY__WS_HEARTBEAT_INTERVAL: "30"  # секунды
      GATEWAY__WS_CLOSE_TIMEOUT: "10"  # секунды
      GATEWAY__MAX_CONCURRENT_REQUESTS: "100"
      GATEWAY__REQUEST_TIMEOUT: "30"  # секунды
      GATEWAY__USE_JWT_AUTH: "true"  # true или false
    secrets:
      GATEWAY__INTERNAL_API_KEY: "change-me-in-production"
```

### Agent Runtime

**Основные переменные окружения**:

```yaml
services:
  agentRuntime:
    env:
      AGENT_RUNTIME__LOG_LEVEL: "DEBUG"
      AGENT_RUNTIME__MAX_CONCURRENT_REQUESTS: "100"
      AGENT_RUNTIME__REQUEST_TIMEOUT: "30"
      AGENT_RUNTIME__LLM_MODEL: "Qwen/Qwen3-0.6B"
    secrets:
      AGENT_RUNTIME__INTERNAL_API_KEY: "change-me-in-production"
    database:
      type: postgres
      # ... параметры БД
    persistence:
      data:
        enabled: true
        size: 5Gi
```

### LLM Proxy

**Основные переменные окружения**:

```yaml
services:
  llmProxy:
    env:
      LLM_PROXY__DEFAULT_MODEL: "gpt-3.5-turbo"
      LLM_PROXY__LLM_MODE: "litellm"  # litellm или ollama
      LLM_PROXY__LOG_LEVEL: "DEBUG"
      LLM_PROXY__MAX_CONCURRENT_REQUESTS: "100"
      LLM_PROXY__REQUEST_TIMEOUT: "30"
    secrets:
      LLM_PROXY__INTERNAL_API_KEY: "change-me-in-production"
      LLM_PROXY__LITELLM_PROXY_URL: "http://litellm-proxy-external:4000"
      LLM_PROXY__LITELLM_API_KEY: "sk-1234"
```

**Для Ollama**:
```yaml
services:
  llmProxy:
    env:
      LLM_PROXY__LLM_MODE: "ollama"
    secrets:
      LLM_PROXY__OLLAMA_BASE_URL: "http://ollama:11434"
```

### PostgreSQL

**Настройки**:

```yaml
services:
  postgres:
    enabled: true
    port: 5432
    env:
      POSTGRES_USER: "codelab"
      POSTGRES_DB: "codelab"
      POSTGRES_MULTIPLE_DATABASES: "agent_runtime,auth_db"
    secrets:
      POSTGRES_PASSWORD: "codelab_password"
    persistence:
      enabled: true
      size: 10Gi
      storageClass: ""
    initScripts:
      enabled: true
```

**Множественные базы данных**:

Параметр `POSTGRES_MULTIPLE_DATABASES` автоматически создает указанные базы данных при инициализации.

### Redis

**Настройки**:

```yaml
services:
  redis:
    enabled: true
    port: 6379
    healthcheck:
      enabled: true
      command: ["redis-cli", "ping"]
      initialDelaySeconds: 10
      periodSeconds: 10
```

## Ресурсы

Настройка CPU и Memory для каждого сервиса.

### Структура

```yaml
resources:
  <serviceName>:
    requests:
      cpu: <value>
      memory: <value>
    limits:
      cpu: <value>
      memory: <value>
```

### Форматы значений

**CPU**:
- `100m` = 0.1 CPU
- `1000m` = 1 CPU
- `2` = 2 CPU

**Memory**:
- `128Mi` = 128 мебибайт
- `1Gi` = 1 гибибайт

### Рекомендации по окружениям

#### Development

```yaml
resources:
  gateway:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi
  
  agentRuntime:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 512Mi
```

#### Staging

```yaml
resources:
  gateway:
    requests:
      cpu: 300m
      memory: 384Mi
    limits:
      cpu: 1500m
      memory: 768Mi
  
  agentRuntime:
    requests:
      cpu: 750m
      memory: 768Mi
    limits:
      cpu: 3000m
      memory: 2Gi
```

#### Production

```yaml
resources:
  gateway:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 2000m
      memory: 1Gi
  
  agentRuntime:
    requests:
      cpu: 1000m
      memory: 1Gi
    limits:
      cpu: 4000m
      memory: 4Gi
```

## Безопасность

### securityContext

**Описание**: Контекст безопасности для всех подов.

**Параметры**:

```yaml
securityContext:
  enabled: true
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
```

**Описание параметров**:
- `enabled` - включить security context
- `runAsNonRoot` - запрещает запуск от root
- `runAsUser` - UID пользователя
- `runAsGroup` - GID группы
- `fsGroup` - GID для файловой системы

## Примеры конфигураций

### Минимальная конфигурация (Development)

```yaml
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
  gateway:
    env:
      GATEWAY__USE_JWT_AUTH: "false"
```

### Staging с внутренним PostgreSQL

```yaml
environment: staging
replicaCount: 2

ingress:
  enabled: true
  host: codelab-stage.example.com
  tls: true
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-staging"

services:
  authService:
    database:
      type: postgres
      useInternal: true
    secrets:
      AUTH_SERVICE__MASTER_KEY: "staging-key"
  
  agentRuntime:
    database:
      type: postgres
      useInternal: true
  
  postgres:
    enabled: true
    persistence:
      size: 20Gi
```

### Production с внешней БД

```yaml
environment: production
replicaCount: 3

imagePullSecrets:
  - name: harbor-registry

ingress:
  enabled: true
  host: codelab.example.com
  tls: true
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"

services:
  authService:
    database:
      type: postgres
      host: postgres.example.com
      port: 5432
      name: auth_db
      user: codelab_user
      password: "CHANGE-ME"
    secrets:
      AUTH_SERVICE__MASTER_KEY: "CHANGE-ME"
    persistence:
      data:
        size: 5Gi
        storageClass: "fast-ssd"
  
  agentRuntime:
    database:
      type: postgres
      host: postgres.example.com
      port: 5432
      name: agent_runtime
      user: codelab_user
      password: "CHANGE-ME"
    persistence:
      data:
        size: 20Gi
        storageClass: "fast-ssd"
  
  postgres:
    enabled: false

resources:
  gateway:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 2000m
      memory: 1Gi
  
  agentRuntime:
    requests:
      cpu: 1000m
      memory: 1Gi
    limits:
      cpu: 4000m
      memory: 4Gi
```

## Переопределение параметров

### Через командную строку

```bash
helm install codelab ./codelab-chart \
  --set environment=production \
  --set replicaCount=3 \
  --set ingress.host=codelab.example.com \
  --set services.postgres.enabled=false
```

### Через values файл

```bash
helm install codelab ./codelab-chart \
  -f values-prod.yaml \
  -f custom-values.yaml
```

### Приоритет значений

1. Значения из `--set`
2. Значения из последнего `-f` файла
3. Значения из предыдущих `-f` файлов
4. Значения из `values.yaml`

## Валидация конфигурации

### Dry-run

```bash
helm install codelab ./codelab-chart \
  -f values-prod.yaml \
  --dry-run --debug
```

### Lint

```bash
helm lint ./codelab-chart -f values-prod.yaml
```

### Template

```bash
helm template codelab ./codelab-chart \
  -f values-prod.yaml > rendered.yaml
```

## Заключение

Для получения дополнительной информации см.:
- [Архитектура](ARCHITECTURE.md)
- [Руководство по развертыванию](DEPLOYMENT.md)
- [Быстрый старт](../QUICKSTART.md)
