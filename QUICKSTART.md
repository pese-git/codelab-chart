# CodeLab Helm Chart - Быстрый старт

## Предварительные требования

1. Kubernetes кластер (minikube, kind, или облачный провайдер)
2. Helm 3.x установлен
3. kubectl настроен для работы с кластером

## Быстрая установка для разработки

### Шаг 1: Клонирование репозитория

```bash
cd /path/to/helm-charts
```

### Шаг 2: Установка с настройками для разработки

```bash
# Создать namespace
kubectl create namespace codelab-dev

# Установить chart
helm install codelab ./codelab \
  -f ./codelab/values-dev.yaml \
  -n codelab-dev
```

### Шаг 3: Проверка статуса

```bash
# Проверить статус релиза
helm status codelab -n codelab-dev

# Проверить поды
kubectl get pods -n codelab-dev

# Дождаться готовности всех подов
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=codelab -n codelab-dev --timeout=300s
```

### Шаг 4: Настройка доступа

#### Вариант A: Использование Ingress (рекомендуется)

Добавьте в `/etc/hosts`:
```
127.0.0.1 codelab.local
```

Если используете minikube:
```bash
minikube tunnel
```

Доступ к приложению:
- Gateway: http://codelab.local/
- Auth Service: http://codelab.local/auth/

#### Вариант B: Port-forward

```bash
# Gateway
kubectl port-forward -n codelab-dev svc/codelab-gateway 8000:8000

# Auth Service
kubectl port-forward -n codelab-dev svc/codelab-auth-service 8003:8003
```

Доступ к приложению:
- Gateway: http://localhost:8000/
- Auth Service: http://localhost:8003/

## Установка для production

### Шаг 1: Подготовка values файла

Скопируйте и отредактируйте `values-prod.yaml`:

```bash
cp codelab/values-prod.yaml my-prod-values.yaml
```

Измените следующие значения:
- `ingress.host` - ваш домен
- Все секреты (пароли, API ключи)
- Настройки внешней БД
- Размеры PVC

### Шаг 2: Создание TLS сертификата

Если используете cert-manager:
```bash
# cert-manager автоматически создаст сертификат
# Убедитесь, что аннотация cert-manager.io/cluster-issuer настроена
```

Или создайте Secret вручную:
```bash
kubectl create secret tls codelab-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n production
```

### Шаг 3: Установка

```bash
# Создать namespace
kubectl create namespace production

# Установить chart
helm install codelab ./codelab \
  -f my-prod-values.yaml \
  -n production
```

## Обновление

```bash
# Обновить с новыми значениями
helm upgrade codelab ./codelab \
  -f ./codelab/values-dev.yaml \
  -n codelab-dev

# Откатить к предыдущей версии
helm rollback codelab -n codelab-dev
```

## Просмотр логов

```bash
# Все логи
kubectl logs -n codelab-dev -l app.kubernetes.io/instance=codelab --tail=100 -f

# Логи конкретного сервиса
kubectl logs -n codelab-dev -l app.kubernetes.io/component=gateway -f
kubectl logs -n codelab-dev -l app.kubernetes.io/component=auth-service -f
kubectl logs -n codelab-dev -l app.kubernetes.io/component=agent-runtime -f
```

## Отладка

### Проверка конфигурации

```bash
# Показать все значения
helm get values codelab -n codelab-dev

# Показать сгенерированные манифесты
helm get manifest codelab -n codelab-dev

# Проверить шаблоны перед установкой
helm template codelab ./codelab -f ./codelab/values-dev.yaml
```

### Проверка подключения к БД

```bash
# Подключиться к поду auth-service
kubectl exec -it -n codelab-dev deployment/codelab-auth-service -- /bin/sh

# Проверить переменные окружения
kubectl exec -n codelab-dev deployment/codelab-auth-service -- env | grep DB_URL
```

### Проверка Ingress

```bash
# Описание Ingress
kubectl describe ingress codelab -n codelab-dev

# Проверка endpoints
kubectl get endpoints -n codelab-dev
```

## Удаление

```bash
# Удалить релиз
helm uninstall codelab -n codelab-dev

# Удалить PVC (опционально)
kubectl delete pvc -l app.kubernetes.io/instance=codelab -n codelab-dev

# Удалить namespace
kubectl delete namespace codelab-dev
```

## Настройка внешних сервисов

### LiteLLM Proxy

Убедитесь, что внешний LiteLLM Proxy доступен:

```bash
# Проверить доступность
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://litellm-proxy-external:4000/health
```

Обновите URL в values:
```yaml
services:
  llmProxy:
    secrets:
      LLM_PROXY__LITELLM_PROXY_URL: "http://your-litellm-proxy:4000"
```

### Внешняя PostgreSQL

Для использования внешней БД:

```yaml
services:
  postgres:
    enabled: false
  
  authService:
    database:
      type: postgres
      host: external-postgres.example.com
      port: 5432
      name: auth_db
      user: codelab_user
      password: "secure-password"
  
  agentRuntime:
    database:
      type: postgres
      host: external-postgres.example.com
      port: 5432
      name: agent_runtime
      user: codelab_user
      password: "secure-password"
```

## Мониторинг

### Prometheus метрики

Если у вас установлен Prometheus Operator, добавьте ServiceMonitor:

```yaml
# Добавьте в values.yaml
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
```

### Grafana дашборды

Импортируйте дашборды для мониторинга:
- Kubernetes Cluster Monitoring
- PostgreSQL Database
- Redis

## Полезные команды

```bash
# Масштабирование
kubectl scale deployment codelab-gateway --replicas=3 -n codelab-dev

# Перезапуск пода
kubectl rollout restart deployment/codelab-gateway -n codelab-dev

# Проверка ресурсов
kubectl top pods -n codelab-dev

# Описание пода
kubectl describe pod <pod-name> -n codelab-dev

# Выполнение команды в поде
kubectl exec -it <pod-name> -n codelab-dev -- /bin/sh
```

## Поддержка

При возникновении проблем:
1. Проверьте логи подов
2. Проверьте события: `kubectl get events -n codelab-dev --sort-by='.lastTimestamp'`
3. Проверьте статус ресурсов: `kubectl get all -n codelab-dev`
