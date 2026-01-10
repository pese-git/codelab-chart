# Настройка Let's Encrypt для CodeLab

Этот документ описывает, как настроить автоматическое получение SSL/TLS сертификатов от Let's Encrypt с помощью cert-manager.

## Предварительные требования

1. Kubernetes кластер
2. Nginx Ingress Controller установлен
3. cert-manager установлен в кластере
4. Доменное имя с настроенными DNS записями

## Установка cert-manager

Если cert-manager еще не установлен:

```bash
# Установка cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Проверка установки
kubectl get pods -n cert-manager
```

## Создание ClusterIssuer

### Production ClusterIssuer

Создайте файл `letsencrypt-prod-issuer.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # Production сервер Let's Encrypt
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email для уведомлений об истечении сертификатов
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

Примените конфигурацию:

```bash
kubectl apply -f letsencrypt-prod-issuer.yaml
```

### Staging ClusterIssuer (для тестирования)

Для тестирования рекомендуется использовать staging окружение Let's Encrypt, чтобы не достичь лимитов:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    # Staging сервер Let's Encrypt
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

## Настройка CodeLab для использования Let's Encrypt

### Вариант 1: Использование values-prod.yaml

В [`values-prod.yaml`](values-prod.yaml) уже настроена поддержка Let's Encrypt:

```yaml
ingress:
  enabled: true
  className: nginx
  host: codelab.example.com  # Замените на ваш домен
  tls: true
  tlsSecretName: codelab-tls
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"  # Автоматическое получение сертификата
```

Установка:

```bash
# Отредактируйте values-prod.yaml, замените codelab.example.com на ваш домен
helm install codelab ./codelab -f ./codelab/values-prod.yaml -n production --create-namespace
```

### Вариант 2: Переопределение через командную строку

```bash
helm install codelab ./codelab \
  --set ingress.enabled=true \
  --set ingress.host=codelab.yourdomain.com \
  --set ingress.tls=true \
  --set ingress.tlsSecretName=codelab-tls \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
  -n production --create-namespace
```

### Вариант 3: Создание custom values файла

Создайте файл `my-values.yaml`:

```yaml
ingress:
  enabled: true
  className: nginx
  host: codelab.yourdomain.com
  tls: true
  tlsSecretName: codelab-tls
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

Установка:

```bash
helm install codelab ./codelab -f my-values.yaml -n production --create-namespace
```

## Проверка статуса сертификата

### Проверка Certificate ресурса

```bash
# Список сертификатов
kubectl get certificate -n production

# Детали сертификата
kubectl describe certificate codelab-tls -n production
```

### Проверка CertificateRequest

```bash
# Список запросов сертификатов
kubectl get certificaterequest -n production

# Детали запроса
kubectl describe certificaterequest -n production
```

### Проверка Challenge (если есть проблемы)

```bash
# Список challenges
kubectl get challenge -n production

# Детали challenge
kubectl describe challenge -n production
```

### Проверка Secret с сертификатом

```bash
# Проверить, что Secret создан
kubectl get secret codelab-tls -n production

# Посмотреть детали
kubectl describe secret codelab-tls -n production
```

## Проверка работы HTTPS

После успешного получения сертификата:

```bash
# Проверка через curl
curl -v https://codelab.yourdomain.com

# Проверка сертификата
openssl s_client -connect codelab.yourdomain.com:443 -servername codelab.yourdomain.com
```

## Troubleshooting

### Сертификат не выдается

1. Проверьте логи cert-manager:
```bash
kubectl logs -n cert-manager -l app=cert-manager -f
```

2. Проверьте события:
```bash
kubectl get events -n production --sort-by='.lastTimestamp'
```

3. Проверьте, что DNS записи настроены правильно:
```bash
nslookup codelab.yourdomain.com
```

4. Проверьте, что домен доступен извне:
```bash
curl -I http://codelab.yourdomain.com/.well-known/acme-challenge/test
```

### HTTP-01 Challenge не проходит

Убедитесь, что:
- Nginx Ingress Controller работает
- Порт 80 открыт и доступен извне
- DNS записи указывают на правильный IP адрес
- Нет других Ingress правил, конфликтующих с challenge

```bash
# Проверка Ingress
kubectl get ingress -n production
kubectl describe ingress codelab -n production

# Проверка Nginx Ingress Controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

### Использование staging для тестирования

Если вы тестируете настройку, используйте staging issuer:

```yaml
ingress:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
```

**Важно:** Staging сертификаты не будут доверенными в браузерах, но позволят проверить процесс получения сертификата.

## Автоматическое обновление сертификатов

cert-manager автоматически обновляет сертификаты за 30 дней до истечения. Никаких дополнительных действий не требуется.

Проверить дату истечения:

```bash
kubectl get certificate codelab-tls -n production -o jsonpath='{.status.notAfter}'
```

## Переход со staging на production

Если вы тестировали со staging сертификатом:

1. Удалите старый Secret:
```bash
kubectl delete secret codelab-tls -n production
```

2. Обновите Ingress аннотацию:
```bash
helm upgrade codelab ./codelab \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
  -n production
```

3. Дождитесь получения нового сертификата:
```bash
kubectl get certificate -n production -w
```

## Дополнительные настройки

### Использование DNS-01 Challenge

Для wildcard сертификатов используйте DNS-01 challenge:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-dns
    solvers:
    - dns01:
        cloudflare:
          email: your-cloudflare-email@example.com
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
```

### Мониторинг сертификатов

Настройте алерты на истечение сертификатов через Prometheus:

```yaml
- alert: CertificateExpiringSoon
  expr: certmanager_certificate_expiration_timestamp_seconds - time() < 604800
  annotations:
    summary: "Certificate {{ $labels.name }} expires in less than 7 days"
```

## Полезные ссылки

- [cert-manager документация](https://cert-manager.io/docs/)
- [Let's Encrypt лимиты](https://letsencrypt.org/docs/rate-limits/)
- [Troubleshooting cert-manager](https://cert-manager.io/docs/troubleshooting/)
