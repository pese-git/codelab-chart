# Руководство по развертыванию CodeLab

Это руководство описывает процесс развертывания платформы CodeLab в различных окружениях с использованием Helm.

## Содержание

- [Предварительные требования](#предварительные-требования)
- [Development окружение](#development-окружение)
- [Staging окружение](#staging-окружение)
- [Production окружение](#production-окружение)
- [Настройка компонентов](#настройка-компонентов)
- [Обновление и откат](#обновление-и-откат)
- [Мониторинг](#мониторинг)
- [Troubleshooting](#troubleshooting)

## Предварительные требования

### Обязательные компоненты

1. **Kubernetes кластер** версии 1.19 или выше
   ```bash
   kubectl version --short
   ```

2. **Helm** версии 3.0 или выше
   ```bash
   helm version
   ```

3. **kubectl** настроен для работы с кластером
   ```bash
   kubectl cluster-info
   ```

### Рекомендуемые компоненты

1. **Nginx Ingress Controller**
   ```bash
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
   ```

2. **cert-manager** (для автоматических SSL сертификатов)
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

3. **Metrics Server** (для HPA и мониторинга)
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

### Проверка кластера

```bash
# Проверить доступные ресурсы
kubectl get nodes
kubectl top nodes

# Проверить StorageClass
kubectl get storageclass

# Проверить Ingress Controller
kubectl get pods -n ingress-nginx
```

## Development окружение

### Характеристики

- Минимальные ресурсы
- SQLite для баз данных
- Без TLS
- Локальный домен
- Отключена JWT аутентификация (опционально)

### Шаг 1: Подготовка

```bash
# Создать namespace
kubectl create namespace codelab-dev

# Добавить hosts запись (для локального доступа)
echo "127.0.0.1 codelab.local" | sudo tee -a /etc/hosts
```

### Шаг 2: Настройка values

Файл [`values-dev.yaml`](../values-dev.yaml) уже содержит оптимальные настройки для разработки.

Ключевые параметры:
```yaml
environment: development
replicaCount: 1

services:
  authService:
    database:
      type: sqlite
  agentRuntime:
    database:
      type: sqlite
  gateway:
    env:
      GATEWAY__USE_JWT_AUTH: "false"  # Упрощает разработку
```

### Шаг 3: Установка

```bash
# Установить chart
helm install codelab ./codelab-chart \
  -f ./codelab-chart/values-dev.yaml \
  -n codelab-dev

# Проверить статус
helm status codelab -n codelab-dev
kubectl get pods -n codelab-dev
```

### Шаг 4: Доступ к приложению

**Вариант A: Через Ingress**

Если используете minikube:
```bash
minikube tunnel
```

Доступ: http://codelab.local

**Вариант B: Port-forward**

```bash
# Gateway
kubectl port-forward -n codelab-dev svc/codelab-gateway 8000:8000

# Auth Service
kubectl port-forward -n codelab-dev svc/codelab-auth-service 8003:8003
```

Доступ:
- Gateway: http://localhost:8000
- Auth Service: http://localhost:8003

### Шаг 5: Проверка работоспособности

```bash
# Проверить health endpoints
curl http://codelab.local/api/v1/health
curl http://codelab.local/oauth/health

# Просмотреть логи
kubectl logs -n codelab-dev -l app.kubernetes.io/instance=codelab -f
```

## Staging окружение

### Характеристики

- Средние ресурсы
- PostgreSQL (внутренний)
- TLS с Let's Encrypt staging
- 2 реплики сервисов
- Полная аутентификация

### Шаг 1: Подготовка

```bash
# Создать namespace
kubectl create namespace codelab-stage

# Создать Secret для Harbor (если используется)
kubectl create secret docker-registry harbor-registry \
  --docker-server=harbor.openidealab.com \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  -n codelab-stage
```

### Шаг 2: Настройка DNS

Настройте A-запись для вашего домена:
```
codelab-stage.example.com → IP_ADDRESS_OF_INGRESS
```

Проверка:
```bash
nslookup codelab-stage.example.com
```

### Шаг 3: Настройка cert-manager

Создайте ClusterIssuer для Let's Encrypt staging:

```yaml
# letsencrypt-staging-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
```

```bash
kubectl apply -f letsencrypt-staging-issuer.yaml
```

### Шаг 4: Настройка values

Отредактируйте [`values-stage.yaml`](../values-stage.yaml):

```yaml
ingress:
  host: codelab-stage.example.com  # Ваш домен
  tls: true
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-staging"

services:
  authService:
    secrets:
      AUTH_SERVICE__MASTER_KEY: "your-secure-master-key"
  gateway:
    secrets:
      GATEWAY__INTERNAL_API_KEY: "your-secure-api-key"
  agentRuntime:
    secrets:
      AGENT_RUNTIME__INTERNAL_API_KEY: "your-secure-api-key"
  llmProxy:
    secrets:
      LLM_PROXY__INTERNAL_API_KEY: "your-secure-api-key"
      LLM_PROXY__LITELLM_PROXY_URL: "http://your-litellm-proxy:4000"
  postgres:
    secrets:
      POSTGRES_PASSWORD: "your-secure-db-password"
```

### Шаг 5: Установка

```bash
helm install codelab ./codelab-chart \
  -f ./codelab-chart/values-stage.yaml \
  -n codelab-stage

# Дождаться готовности всех подов
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=codelab \
  -n codelab-stage \
  --timeout=300s
```

### Шаг 6: Проверка сертификата

```bash
# Проверить Certificate
kubectl get certificate -n codelab-stage
kubectl describe certificate codelab-stage-tls -n codelab-stage

# Проверить Secret с сертификатом
kubectl get secret codelab-stage-tls -n codelab-stage
```

### Шаг 7: Тестирование

```bash
# Проверить HTTPS доступ
curl -v https://codelab-stage.example.com/api/v1/health

# Проверить WebSocket
wscat -c wss://codelab-stage.example.com/api/v1/ws
```

## Production окружение

### Характеристики

- Максимальные ресурсы
- Внешняя PostgreSQL (рекомендуется)
- TLS с Let's Encrypt production
- 3+ реплики сервисов
- Полная безопасность
- Мониторинг и алертинг

### Шаг 1: Подготовка инфраструктуры

#### Внешняя PostgreSQL

Рекомендуется использовать управляемую БД:
- AWS RDS
- Google Cloud SQL
- Azure Database for PostgreSQL
- Или собственный PostgreSQL кластер с репликацией

Создайте базы данных:
```sql
CREATE DATABASE auth_db;
CREATE DATABASE agent_runtime;
CREATE USER codelab_user WITH PASSWORD 'secure-password';
GRANT ALL PRIVILEGES ON DATABASE auth_db TO codelab_user;
GRANT ALL PRIVILEGES ON DATABASE agent_runtime TO codelab_user;
```

#### Внешний Redis (опционально)

Для production рекомендуется Redis Cluster или управляемый Redis:
- AWS ElastiCache
- Google Cloud Memorystore
- Azure Cache for Redis

### Шаг 2: Настройка DNS

```
codelab.example.com → IP_ADDRESS_OF_INGRESS
```

### Шаг 3: Настройка cert-manager

Создайте ClusterIssuer для Let's Encrypt production:

```yaml
# letsencrypt-prod-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

```bash
kubectl apply -f letsencrypt-prod-issuer.yaml
```

### Шаг 4: Подготовка секретов

**Вариант A: Kubernetes Secrets**

```bash
kubectl create namespace codelab-prod

# Auth Service secrets
kubectl create secret generic codelab-auth-secrets \
  --from-literal=AUTH_SERVICE__MASTER_KEY='your-production-master-key' \
  -n codelab-prod

# Gateway secrets
kubectl create secret generic codelab-gateway-secrets \
  --from-literal=GATEWAY__INTERNAL_API_KEY='your-production-api-key' \
  -n codelab-prod

# Database credentials
kubectl create secret generic codelab-db-secrets \
  --from-literal=DB_PASSWORD='your-production-db-password' \
  -n codelab-prod
```

**Вариант B: External Secrets Operator** (рекомендуется)

Используйте External Secrets для интеграции с Vault, AWS Secrets Manager и т.д.

### Шаг 5: Настройка values

Создайте файл `values-prod-custom.yaml`:

```yaml
environment: production
replicaCount: 3

imagePullSecrets:
  - name: harbor-registry

ingress:
  enabled: true
  host: codelab.example.com
  tls: true
  tlsSecretName: codelab-tls
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/rate-limit: "100"

services:
  authService:
    database:
      type: postgres
      host: your-postgres-host.example.com
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
      host: your-postgres-host.example.com
      port: 5432
      name: agent_runtime
      user: codelab_user
      password: "CHANGE-ME"
    secrets:
      AGENT_RUNTIME__INTERNAL_API_KEY: "CHANGE-ME"
    persistence:
      data:
        size: 20Gi
        storageClass: "fast-ssd"
  
  gateway:
    env:
      GATEWAY__LOG_LEVEL: "INFO"
    secrets:
      GATEWAY__INTERNAL_API_KEY: "CHANGE-ME"
  
  llmProxy:
    env:
      LLM_PROXY__LOG_LEVEL: "INFO"
    secrets:
      LLM_PROXY__INTERNAL_API_KEY: "CHANGE-ME"
      LLM_PROXY__LITELLM_PROXY_URL: "https://your-litellm-proxy.example.com"
      LLM_PROXY__LITELLM_API_KEY: "CHANGE-ME"
  
  # Отключаем внутренний PostgreSQL
  postgres:
    enabled: false
  
  redis:
    enabled: true
    # Или используйте внешний Redis

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

### Шаг 6: Установка

```bash
# Dry-run для проверки
helm install codelab ./codelab-chart \
  -f ./codelab-chart/values-prod.yaml \
  -f values-prod-custom.yaml \
  -n codelab-prod \
  --dry-run --debug

# Установка
helm install codelab ./codelab-chart \
  -f ./codelab-chart/values-prod.yaml \
  -f values-prod-custom.yaml \
  -n codelab-prod

# Мониторинг установки
kubectl get pods -n codelab-prod -w
```

### Шаг 7: Проверка

```bash
# Проверить все ресурсы
kubectl get all -n codelab-prod

# Проверить сертификат
kubectl get certificate -n codelab-prod

# Проверить Ingress
kubectl describe ingress codelab -n codelab-prod

# Проверить логи
kubectl logs -n codelab-prod -l app.kubernetes.io/instance=codelab --tail=100
```

### Шаг 8: Smoke тесты

```bash
# Health checks
curl https://codelab.example.com/api/v1/health
curl https://codelab.example.com/oauth/health

# WebSocket connection
wscat -c wss://codelab.example.com/api/v1/ws

# OAuth endpoints
curl https://codelab.example.com/.well-known/jwks.json
```

## Настройка компонентов

### Настройка LiteLLM Proxy

Если используете внешний LiteLLM Proxy:

```yaml
services:
  llmProxy:
    secrets:
      LLM_PROXY__LITELLM_PROXY_URL: "http://litellm-proxy:4000"
      LLM_PROXY__LITELLM_API_KEY: "your-api-key"
```

### Настройка Ollama

Для использования локальных моделей через Ollama:

```yaml
services:
  llmProxy:
    env:
      LLM_PROXY__LLM_MODE: "ollama"
    secrets:
      LLM_PROXY__OLLAMA_BASE_URL: "http://ollama:11434"
```

### Настройка мониторинга

#### Prometheus

Добавьте ServiceMonitor для Prometheus Operator:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: codelab
  namespace: codelab-prod
spec:
  selector:
    matchLabels:
      app.kubernetes.io/instance: codelab
  endpoints:
  - port: http
    path: /metrics
```

#### Grafana

Импортируйте дашборды:
- Kubernetes Cluster Monitoring
- PostgreSQL Database
- Redis Monitoring

## Обновление и откат

### Обновление релиза

```bash
# Обновить с новыми values
helm upgrade codelab ./codelab-chart \
  -f ./codelab-chart/values-prod.yaml \
  -n codelab-prod

# Обновить только образы
helm upgrade codelab ./codelab-chart \
  --set images.gateway.tag=v1.2.0 \
  --set images.agentRuntime.tag=v1.2.0 \
  -n codelab-prod

# Мониторинг обновления
kubectl rollout status deployment/codelab-gateway -n codelab-prod
```

### Откат

```bash
# Просмотреть историю
helm history codelab -n codelab-prod

# Откатить к предыдущей версии
helm rollback codelab -n codelab-prod

# Откатить к конкретной ревизии
helm rollback codelab 3 -n codelab-prod
```

### Zero-downtime обновление

Для обновления без простоя:

1. Убедитесь, что `replicaCount >= 2`
2. Настройте Pod Disruption Budget:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: codelab-gateway-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/component: gateway
```

## Мониторинг

### Health Checks

```bash
# Проверить все health endpoints
kubectl get pods -n codelab-prod -o wide | while read pod; do
  kubectl exec -n codelab-prod $pod -- curl -s localhost:8000/health
done
```

### Метрики

```bash
# CPU и Memory
kubectl top pods -n codelab-prod

# Детальная информация
kubectl describe pod <pod-name> -n codelab-prod
```

### Логи

```bash
# Все логи
kubectl logs -n codelab-prod -l app.kubernetes.io/instance=codelab --tail=100 -f

# Логи конкретного сервиса
kubectl logs -n codelab-prod -l app.kubernetes.io/component=gateway -f

# Логи с временными метками
kubectl logs -n codelab-prod <pod-name> --timestamps
```

## Troubleshooting

### Поды не запускаются

```bash
# Проверить события
kubectl get events -n codelab-prod --sort-by='.lastTimestamp'

# Описание пода
kubectl describe pod <pod-name> -n codelab-prod

# Проверить образы
kubectl get pods -n codelab-prod -o jsonpath='{.items[*].spec.containers[*].image}'
```

### Проблемы с ImagePull

См. [HARBOR-SETUP.md](../HARBOR-SETUP.md) для настройки доступа к Harbor registry.

### Проблемы с базой данных

```bash
# Проверить подключение к PostgreSQL
kubectl exec -it -n codelab-prod deployment/codelab-postgres -- \
  psql -U codelab -d codelab -c '\l'

# Проверить логи сервиса
kubectl logs -n codelab-prod -l app.kubernetes.io/component=auth-service
```

### Проблемы с Ingress

```bash
# Проверить Ingress
kubectl describe ingress codelab -n codelab-prod

# Проверить endpoints
kubectl get endpoints -n codelab-prod

# Логи Ingress контроллера
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

### Проблемы с сертификатами

```bash
# Проверить Certificate
kubectl describe certificate codelab-tls -n codelab-prod

# Проверить CertificateRequest
kubectl get certificaterequest -n codelab-prod

# Проверить Challenge
kubectl get challenge -n codelab-prod

# Логи cert-manager
kubectl logs -n cert-manager -l app=cert-manager
```

## Резервное копирование

### PostgreSQL

```bash
# Создать бэкап
kubectl exec -n codelab-prod deployment/codelab-postgres -- \
  pg_dump -U codelab auth_db > auth_db_backup.sql

# Восстановить из бэкапа
kubectl exec -i -n codelab-prod deployment/codelab-postgres -- \
  psql -U codelab auth_db < auth_db_backup.sql
```

### Persistent Volumes

```bash
# Создать snapshot (зависит от провайдера)
kubectl get pvc -n codelab-prod

# Для AWS EBS
aws ec2 create-snapshot --volume-id vol-xxxxx
```

## Удаление

```bash
# Удалить релиз
helm uninstall codelab -n codelab-prod

# Удалить PVC (опционально)
kubectl delete pvc -l app.kubernetes.io/instance=codelab -n codelab-prod

# Удалить namespace
kubectl delete namespace codelab-prod
```

## Заключение

Следуя этому руководству, вы сможете развернуть CodeLab в любом окружении. Для получения дополнительной информации см.:

- [Архитектура](ARCHITECTURE.md)
- [Конфигурация](CONFIGURATION.md)
- [Быстрый старт](../QUICKSTART.md)
