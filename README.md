# CodeLab Helm Chart

Helm chart для развертывания AI-powered IDE платформы CodeLab с мультиагентной системой в Kubernetes.

**Версия Chart**: 0.1.0  
**Версия приложения**: 1.0.0  
**Дата обновления**: 21 января 2026  
**Статус**: ✅ Production Ready

## Описание

Этот Helm chart развертывает полную микросервисную платформу CodeLab, включающую:

### Основные сервисы

- **Gateway** (порт 8000) - WebSocket прокси с JWT аутентификацией для взаимодействия с клиентами
- **Auth Service** (порт 8003) - OAuth2 Authorization Server с RS256 JWT для управления аутентификацией
- **Agent Runtime** (порт 8001) - Мультиагентная система с поддержкой HITL (Human-in-the-Loop)
- **LLM Proxy** (порт 8002) - Унифицированный прокси для доступа к различным LLM провайдерам

### Инфраструктурные компоненты

- **Redis** (порт 6379) - Кэширование, управление сессиями, rate limiting
- **PostgreSQL** (порт 5432) - Персистентное хранилище данных (сессии, пользователи, HITL данные)
- **Website** (порт 80) - Веб-интерфейс (опционально)

### Сетевые компоненты

- **Ingress** - Nginx Ingress Controller для внешнего доступа
- Поддержка TLS/SSL через cert-manager
- Поддержка WebSocket соединений

## Быстрый старт

### Предварительные требования

- Kubernetes 1.19+
- Helm 3.0+
- Nginx Ingress Controller (если используется Ingress)
- Persistent Volume provisioner для хранения данных

### Базовая установка

```bash
# Создать namespace
kubectl create namespace codelab

# Установить chart с настройками для разработки
helm install codelab ./codelab-chart -f ./codelab-chart/values-dev.yaml -n codelab
```

### Проверка статуса

```bash
# Проверить статус релиза
helm status codelab -n codelab

# Проверить поды
kubectl get pods -n codelab

# Просмотреть логи
kubectl logs -n codelab -l app.kubernetes.io/instance=codelab -f
```

## Документация

Подробная документация находится в директории [`doc/`](doc/):

- **[Архитектура](doc/ARCHITECTURE.md)** - Описание архитектуры и компонентов системы
- **[Развертывание](doc/DEPLOYMENT.md)** - Руководство по развертыванию в различных окружениях
- **[Конфигурация](doc/CONFIGURATION.md)** - Подробное описание параметров конфигурации
- **[Быстрый старт](QUICKSTART.md)** - Пошаговое руководство для быстрого запуска
- **[Настройка Harbor](HARBOR-SETUP.md)** - Настройка доступа к приватному Harbor registry
- **[Настройка Let's Encrypt](LETSENCRYPT.md)** - Настройка автоматических SSL сертификатов

## Примеры конфигураций

### Development окружение

```bash
helm install codelab ./codelab-chart -f ./codelab-chart/values-dev.yaml -n codelab-dev
```

Особенности:
- SQLite для баз данных
- Минимальные ресурсы
- Отключена JWT аутентификация
- Локальный домен `codelab.local`

### Staging окружение

```bash
helm install codelab ./codelab-chart -f ./codelab-chart/values-stage.yaml -n codelab-stage
```

Особенности:
- PostgreSQL (внутренний)
- Средние ресурсы
- TLS с Let's Encrypt staging
- 2 реплики сервисов

### Production окружение

```bash
helm install codelab ./codelab-chart -f ./codelab-chart/values-prod.yaml -n codelab-prod
```

Особенности:
- PostgreSQL (внешний, рекомендуется)
- Максимальные ресурсы
- TLS с Let's Encrypt production
- 3 реплики сервисов
- Все секреты должны быть изменены

## Основные параметры

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `environment` | Окружение развертывания | `development` |
| `replicaCount` | Количество реплик | `1` |
| `ingress.enabled` | Включить Ingress | `true` |
| `ingress.host` | Хост для доступа | `codelab.example.com` |
| `ingress.tls` | Включить TLS | `false` |

Полный список параметров см. в [документации по конфигурации](doc/CONFIGURATION.md).

## Обновление

```bash
# Обновить релиз
helm upgrade codelab ./codelab-chart -f ./codelab-chart/values-dev.yaml -n codelab

# Откатить к предыдущей версии
helm rollback codelab -n codelab
```

## Удаление

```bash
# Удалить релиз
helm uninstall codelab -n codelab

# Удалить PersistentVolumeClaims (опционально)
kubectl delete pvc -l app.kubernetes.io/instance=codelab -n codelab
```

## Безопасность

⚠️ **ВАЖНО:** Перед развертыванием в production:

1. Измените все секретные значения в values файле
2. Используйте Kubernetes Secrets или внешние системы управления секретами (Vault, Sealed Secrets)
3. Включите TLS для Ingress
4. Настройте Network Policies
5. Используйте внешнюю PostgreSQL БД с резервным копированием
6. Настройте мониторинг и алертинг

## Troubleshooting

### Проблемы с образами

Если возникают ошибки `ImagePullBackOff`, см. [HARBOR-SETUP.md](HARBOR-SETUP.md).

### Проблемы с базой данных

```bash
# Проверить логи сервиса
kubectl logs -n codelab -l app.kubernetes.io/component=auth-service

# Проверить подключение к PostgreSQL
kubectl exec -it -n codelab deployment/codelab-postgres -- psql -U codelab -d codelab -c '\l'
```

### Проблемы с Ingress

```bash
# Проверить Ingress
kubectl describe ingress codelab -n codelab

# Проверить логи Ingress контроллера
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

## Структура проекта

```
codelab-chart/
├── Chart.yaml              # Метаданные chart
├── values.yaml             # Значения по умолчанию
├── values-dev.yaml         # Конфигурация для development
├── values-stage.yaml       # Конфигурация для staging
├── values-stage-minimal.yaml # Минимальная конфигурация для staging
├── values-prod.yaml        # Конфигурация для production
├── templates/              # Kubernetes манифесты
│   ├── _helpers.tpl        # Вспомогательные шаблоны
│   ├── ingress.yaml        # Ingress конфигурация
│   ├── *-deployment.yaml   # Deployments для сервисов
│   ├── *-service.yaml      # Services для сервисов
│   ├── *-secret.yaml       # Secrets для сервисов
│   ├── *-pvc.yaml          # PersistentVolumeClaims
│   └── NOTES.txt           # Инструкции после установки
├── doc/                    # Документация
│   ├── ARCHITECTURE.md     # Архитектура системы
│   ├── DEPLOYMENT.md       # Руководство по развертыванию
│   └── CONFIGURATION.md    # Описание конфигурации
├── README.md               # Этот файл
├── QUICKSTART.md           # Быстрый старт
├── HARBOR-SETUP.md         # Настройка Harbor
└── LETSENCRYPT.md          # Настройка Let's Encrypt
```

## Поддержка

При возникновении проблем:

1. Проверьте логи подов: `kubectl logs -n codelab -l app.kubernetes.io/instance=codelab`
2. Проверьте события: `kubectl get events -n codelab --sort-by='.lastTimestamp'`
3. Проверьте статус ресурсов: `kubectl get all -n codelab`
4. Обратитесь к документации в директории `doc/`

## Лицензия

См. файл [LICENSE](../LICENSE) в корне проекта.

## Связанные проекты

- [codelab-ai-service](../codelab-ai-service/) - Backend сервисы CodeLab
- [codelab_ide](../codelab_ide/) - Flutter IDE клиент
