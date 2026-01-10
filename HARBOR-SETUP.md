# Настройка доступа к Harbor Registry

Этот документ описывает, как настроить доступ к приватному Harbor registry для Kubernetes кластера.

## Проблема

При развертывании вы можете столкнуться с ошибками:
- `ImagePullBackOff`
- `ErrImagePull`

Это означает, что Kubernetes не может скачать образы из приватного Harbor registry.

## Решение

### Шаг 1: Создание Docker Registry Secret

Создайте Kubernetes Secret с учетными данными для доступа к Harbor:

```bash
kubectl create secret docker-registry harbor-registry \
  --docker-server=harbor.openidealab.com \
  --docker-username=YOUR_HARBOR_USERNAME \
  --docker-password=YOUR_HARBOR_PASSWORD \
  --docker-email=your-email@example.com \
  -n codelab
```

**Замените:**
- `YOUR_HARBOR_USERNAME` - ваше имя пользователя в Harbor
- `YOUR_HARBOR_PASSWORD` - ваш пароль в Harbor
- `your-email@example.com` - ваш email
- `codelab` - namespace, куда устанавливаете chart

### Шаг 2: Настройка values файла

Добавьте imagePullSecrets в ваш values файл:

```yaml
imagePullSecrets:
  - name: harbor-registry
```

Это уже настроено в [`values-stage-minimal.yaml`](values-stage-minimal.yaml).

### Шаг 3: Установка или обновление Helm chart

#### Новая установка:

```bash
helm install codelab ./codelab \
  -f ./codelab/values-stage-minimal.yaml \
  -n codelab --create-namespace
```

#### Обновление существующего релиза:

```bash
helm upgrade codelab ./codelab \
  -f ./codelab/values-stage-minimal.yaml \
  -n codelab
```

## Проверка

### Проверка Secret:

```bash
kubectl get secret harbor-registry -n codelab
kubectl describe secret harbor-registry -n codelab
```

### Проверка подов:

```bash
kubectl get pods -n codelab
```

Все поды должны быть в статусе `Running` или `ContainerCreating`.

### Проверка событий:

```bash
kubectl get events -n codelab --sort-by='.lastTimestamp' | grep -i pull
```

Не должно быть ошибок типа "Failed to pull image".

## Альтернативные методы

### Метод 1: Использование существующего Secret

Если Secret уже создан в другом namespace:

```bash
# Экспорт Secret
kubectl get secret harbor-registry -n source-namespace -o yaml > harbor-secret.yaml

# Редактирование namespace в файле
sed -i 's/namespace: source-namespace/namespace: codelab/' harbor-secret.yaml

# Применение в новом namespace
kubectl apply -f harbor-secret.yaml
```

### Метод 2: Создание Secret из файла

Создайте файл `docker-config.json`:

```json
{
  "auths": {
    "harbor.openidealab.com": {
      "username": "YOUR_USERNAME",
      "password": "YOUR_PASSWORD",
      "email": "your-email@example.com",
      "auth": "BASE64_ENCODED_USERNAME:PASSWORD"
    }
  }
}
```

Для получения `auth` значения:

```bash
echo -n "YOUR_USERNAME:YOUR_PASSWORD" | base64
```

Создайте Secret:

```bash
kubectl create secret generic harbor-registry \
  --from-file=.dockerconfigjson=docker-config.json \
  --type=kubernetes.io/dockerconfigjson \
  -n codelab
```

### Метод 3: ServiceAccount с imagePullSecrets

Создайте ServiceAccount с автоматическим использованием imagePullSecrets:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: codelab-sa
  namespace: codelab
imagePullSecrets:
  - name: harbor-registry
```

Затем укажите в values:

```yaml
serviceAccount:
  create: false
  name: codelab-sa
```

## Troubleshooting

### Ошибка: "unauthorized: authentication required"

Проверьте правильность учетных данных:

```bash
# Тест доступа к Harbor
docker login harbor.openidealab.com
Username: YOUR_USERNAME
Password: YOUR_PASSWORD
```

Если docker login успешен, пересоздайте Secret с теми же учетными данными.

### Ошибка: "manifest unknown"

Образ не существует в Harbor. Проверьте:

1. Войдите в Harbor UI: https://harbor.openidealab.com
2. Проверьте наличие проекта `codelab`
3. Проверьте наличие образов:
   - `codelab/auth-service:latest`
   - `codelab/gateway:latest`
   - `codelab/agent-runtime:latest`
   - `codelab/llm-proxy:latest`

### Ошибка: "pull access denied"

У пользователя нет прав на скачивание образов. Проверьте права в Harbor:

1. Войдите в Harbor UI
2. Перейдите в проект `codelab`
3. Вкладка "Members"
4. Убедитесь, что ваш пользователь имеет роль минимум "Developer"

### Secret создан, но поды все равно не могут скачать образы

Проверьте, что Secret правильно указан в Deployment:

```bash
kubectl get deployment codelab-gateway -n codelab -o yaml | grep -A 5 imagePullSecrets
```

Должно быть:

```yaml
imagePullSecrets:
- name: harbor-registry
```

Если нет, обновите Helm chart:

```bash
helm upgrade codelab ./codelab \
  --set imagePullSecrets[0].name=harbor-registry \
  -n codelab
```

## Автоматизация для CI/CD

Для автоматического создания Secret в CI/CD pipeline:

```bash
#!/bin/bash
NAMESPACE="codelab"
HARBOR_SERVER="harbor.openidealab.com"
HARBOR_USERNAME="${HARBOR_USERNAME}"  # из переменных окружения
HARBOR_PASSWORD="${HARBOR_PASSWORD}"  # из переменных окружения

kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry harbor-registry \
  --docker-server=${HARBOR_SERVER} \
  --docker-username=${HARBOR_USERNAME} \
  --docker-password=${HARBOR_PASSWORD} \
  -n ${NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Безопасность

⚠️ **Важно:**

1. Никогда не коммитьте учетные данные в Git
2. Используйте отдельные учетные записи для разных окружений
3. Регулярно ротируйте пароли
4. Используйте минимальные необходимые права (принцип наименьших привилегий)
5. Для production используйте системы управления секретами (Vault, Sealed Secrets, External Secrets)

## Дополнительные ресурсы

- [Kubernetes imagePullSecrets](https://kubernetes.io/docs/concepts/containers/images/#specifying-imagepullsecrets-on-a-pod)
- [Harbor документация](https://goharbor.io/docs/)
- [Docker Registry Authentication](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)
