# Архитектура CodeLab Helm Chart

Этот документ описывает архитектуру развертывания платформы CodeLab в Kubernetes с использованием Helm.

## Обзор архитектуры

CodeLab представляет собой микросервисную платформу, состоящую из нескольких взаимосвязанных компонентов, развернутых в Kubernetes кластере.

```
┌─────────────────────────────────────────────────────────────────┐
│                         Ingress (Nginx)                          │
│                    TLS/SSL + WebSocket Support                   │
└────────────┬────────────────────────────────────┬────────────────┘
             │                                    │
             │ /api/v1                           │ /oauth, /.well-known
             │                                    │
    ┌────────▼────────┐                  ┌───────▼────────┐
    │    Gateway      │                  │  Auth Service  │
    │   (Port 8000)   │◄─────────────────┤  (Port 8003)   │
    │  WebSocket API  │   JWT Validation │  OAuth2 Server │
    └────────┬────────┘                  └────────────────┘
             │
             │ Internal API
             │
    ┌────────▼────────┐                  ┌────────────────┐
    │ Agent Runtime   │◄─────────────────┤   LLM Proxy    │
    │  (Port 8001)    │   LLM Requests   │  (Port 8002)   │
    │ Multi-Agent AI  │                  │  LiteLLM/Ollama│
    └────────┬────────┘                  └────────────────┘
             │
             │
    ┌────────▼────────┐                  ┌────────────────┐
    │     Redis       │                  │   PostgreSQL   │
    │  (Port 6379)    │                  │  (Port 5432)   │
    │ Cache & Sessions│                  │  Persistent DB │
    └─────────────────┘                  └────────────────┘
```

## Компоненты системы

### 1. Gateway (Шлюз)

**Назначение**: Точка входа для клиентских приложений, обеспечивает WebSocket соединения и маршрутизацию запросов.

**Основные функции**:
- WebSocket сервер для real-time коммуникации
- JWT аутентификация запросов
- Маршрутизация к Agent Runtime
- Rate limiting
- Heartbeat для поддержания соединений

**Технологии**: Python, FastAPI, WebSocket

**Зависимости**:
- Auth Service (для валидации JWT токенов)
- Agent Runtime (для обработки запросов)
- Redis (для управления сессиями)

### 2. Auth Service (Сервис аутентификации)

**Назначение**: OAuth2 Authorization Server для управления аутентификацией и авторизацией.

**Основные функции**:
- OAuth2 Authorization Code Flow
- Выдача JWT токенов (RS256)
- Управление пользователями
- Refresh token механизм
- JWKS endpoint для публичных ключей

**Технологии**: Python, FastAPI, SQLAlchemy

**Зависимости**:
- PostgreSQL или SQLite (для хранения пользователей и токенов)
- Redis (для кэширования)

**Endpoints**:
- `/oauth/authorize` - Авторизация
- `/oauth/token` - Получение токенов
- `/.well-known/jwks.json` - Публичные ключи

### 3. Agent Runtime (Мультиагентная система)

**Назначение**: Ядро AI-системы, управляет агентами и обрабатывает запросы пользователей.

**Основные функции**:
- Управление жизненным циклом агентов
- Обработка запросов через мультиагентную систему
- HITL (Human-in-the-Loop) механизм
- Управление контекстом и историей
- Event-driven архитектура

**Технологии**: Python, FastAPI, SQLAlchemy, asyncio

**Зависимости**:
- LLM Proxy (для доступа к LLM)
- PostgreSQL или SQLite (для хранения сессий и HITL данных)
- Redis (для кэширования и очередей)

**Агенты**:
- Code Agent - генерация и редактирование кода
- Debug Agent - отладка и исправление ошибок
- Ask Agent - ответы на вопросы
- Architect Agent - проектирование архитектуры
- Orchestrator Agent - координация работы агентов

### 4. LLM Proxy (Прокси для LLM)

**Назначение**: Унифицированный интерфейс для доступа к различным LLM провайдерам.

**Основные функции**:
- Прокси к LiteLLM или Ollama
- Унификация API различных провайдеров
- Rate limiting
- Кэширование ответов
- Метрики использования

**Технологии**: Python, FastAPI

**Поддерживаемые провайдеры**:
- OpenAI (через LiteLLM)
- Anthropic (через LiteLLM)
- Ollama (локальные модели)
- Другие провайдеры через LiteLLM

### 5. Redis

**Назначение**: In-memory хранилище для кэширования и управления сессиями.

**Использование**:
- Кэширование JWT токенов
- Управление WebSocket сессиями
- Rate limiting счетчики
- Очереди задач
- Pub/Sub для событий

**Технологии**: Redis 7 Alpine

### 6. PostgreSQL

**Назначение**: Реляционная база данных для персистентного хранения.

**Базы данных**:
- `auth_db` - пользователи, токены, audit logs
- `agent_runtime` - сессии, HITL данные, история

**Технологии**: PostgreSQL 16 Alpine

**Особенности**:
- Поддержка множественных баз данных
- Init scripts для автоматической инициализации
- Persistent volumes для сохранения данных

### 7. Website (опционально)

**Назначение**: Веб-интерфейс документации или landing page.

**Технологии**: Docusaurus или статический сайт

## Сетевая архитектура

### Ingress маршрутизация

```yaml
Paths:
  /oauth/*          → Auth Service (8003)
  /.well-known/*    → Auth Service (8003)
  /api/v1/*         → Gateway (8000)
  /*                → Website (80)
```

### Внутренняя коммуникация

Все сервисы взаимодействуют через Kubernetes Services (ClusterIP):

```
gateway:8000          → codelab-gateway:8000
auth-service:8003     → codelab-auth-service:8003
agent-runtime:8001    → codelab-agent-runtime:8001
llm-proxy:8002        → codelab-llm-proxy:8002
redis:6379            → codelab-redis:6379
postgres:5432         → codelab-postgres:5432
```

### Безопасность

**Аутентификация**:
- Внешние запросы: JWT токены (RS256)
- Внутренние запросы: Internal API Keys

**Шифрование**:
- TLS/SSL для внешних соединений (через Ingress)
- Незашифрованные соединения внутри кластера (ClusterIP)

**Network Policies** (рекомендуется для production):
- Ограничение трафика между подами
- Разрешение только необходимых соединений

## Хранение данных

### Persistent Volumes

**Auth Service**:
- `/data` - SQLite база данных (если используется SQLite)
- `/app/keys` - RSA ключи для JWT подписи

**Agent Runtime**:
- `/data` - SQLite база данных (если используется SQLite)

**PostgreSQL**:
- `/var/lib/postgresql/data` - Данные PostgreSQL

### Размеры по умолчанию

| Компонент | Volume | Размер (dev) | Размер (prod) |
|-----------|--------|--------------|---------------|
| Auth Service | data | 1Gi | 5Gi |
| Auth Service | keys | 100Mi | 1Gi |
| Agent Runtime | data | 5Gi | 20Gi |
| PostgreSQL | data | 10Gi | 50Gi+ |

## Масштабирование

### Горизонтальное масштабирование

**Stateless сервисы** (можно масштабировать):
- Gateway
- Auth Service (с внешней БД)
- Agent Runtime (с внешней БД)
- LLM Proxy
- Website

**Stateful сервисы** (требуют особого подхода):
- Redis (использовать Redis Cluster)
- PostgreSQL (использовать репликацию)

### Рекомендации по репликам

| Окружение | Gateway | Auth | Agent Runtime | LLM Proxy |
|-----------|---------|------|---------------|-----------|
| Development | 1 | 1 | 1 | 1 |
| Staging | 2 | 2 | 2 | 2 |
| Production | 3+ | 3+ | 3+ | 3+ |

## Ресурсы

### CPU и Memory

Рекомендуемые ресурсы для production:

| Сервис | CPU Request | CPU Limit | Memory Request | Memory Limit |
|--------|-------------|-----------|----------------|--------------|
| Gateway | 500m | 2000m | 512Mi | 1Gi |
| Auth Service | 500m | 2000m | 512Mi | 1Gi |
| Agent Runtime | 1000m | 4000m | 1Gi | 4Gi |
| LLM Proxy | 500m | 2000m | 512Mi | 1Gi |
| Redis | 250m | 1000m | 256Mi | 512Mi |
| PostgreSQL | 250m | 1000m | 512Mi | 1Gi |

## Мониторинг и логирование

### Метрики

Все сервисы предоставляют:
- Health check endpoints (`/health`)
- Prometheus метрики (опционально)

### Логирование

**Уровни логирования**:
- Development: `DEBUG`
- Staging: `INFO`
- Production: `INFO` или `WARNING`

**Централизованное логирование** (рекомендуется):
- ELK Stack (Elasticsearch, Logstash, Kibana)
- Loki + Grafana
- CloudWatch (для AWS)

## High Availability (HA)

Для обеспечения высокой доступности:

1. **Множественные реплики** всех stateless сервисов
2. **Внешняя PostgreSQL** с репликацией и автоматическим failover
3. **Redis Cluster** или Redis Sentinel
4. **Multi-AZ развертывание** в облаке
5. **Pod Disruption Budgets** для контроля обновлений
6. **Readiness и Liveness probes** для всех подов

## Disaster Recovery

### Резервное копирование

**Что нужно бэкапить**:
- PostgreSQL базы данных
- Auth Service RSA ключи
- Persistent Volumes

**Частота**:
- PostgreSQL: ежедневно + continuous WAL archiving
- Ключи: при изменении
- Volumes: еженедельно

### Восстановление

1. Восстановить PostgreSQL из бэкапа
2. Восстановить RSA ключи Auth Service
3. Переустановить Helm chart
4. Проверить работоспособность всех сервисов

## Обновление и миграция

### Rolling Updates

Helm chart поддерживает rolling updates для всех сервисов:
- Постепенная замена подов
- Zero-downtime для stateless сервисов
- Автоматический rollback при ошибках

### Миграция баз данных

**Auth Service**:
- Использует Alembic для миграций
- Миграции выполняются автоматически при старте

**Agent Runtime**:
- Использует Alembic для миграций
- Миграции выполняются автоматически при старте

## Безопасность

### Рекомендации

1. **Секреты**: Использовать Kubernetes Secrets или внешние системы (Vault)
2. **RBAC**: Настроить Role-Based Access Control
3. **Network Policies**: Ограничить сетевой трафик
4. **Pod Security Policies**: Запретить привилегированные контейнеры
5. **Image Scanning**: Сканировать образы на уязвимости
6. **TLS**: Использовать TLS для всех внешних соединений

### Security Context

По умолчанию все поды запускаются с:
- `runAsNonRoot: true`
- `runAsUser: 1000`
- `runAsGroup: 1000`
- `fsGroup: 1000`

## Производительность

### Оптимизация

1. **Redis кэширование**: Кэшировать JWT токены и частые запросы
2. **Connection pooling**: Использовать пулы соединений к БД
3. **Async I/O**: Все сервисы используют асинхронный I/O
4. **Resource limits**: Правильно настроить CPU и Memory limits
5. **HPA**: Использовать Horizontal Pod Autoscaler для автомасштабирования

### Bottlenecks

Потенциальные узкие места:
- LLM Proxy (зависит от внешних провайдеров)
- PostgreSQL (при большой нагрузке)
- Redis (при большом количестве сессий)

## Заключение

Архитектура CodeLab Helm Chart спроектирована для:
- **Масштабируемости**: Горизонтальное масштабирование stateless сервисов
- **Надежности**: HA конфигурация с множественными репликами
- **Безопасности**: JWT аутентификация, TLS, Network Policies
- **Гибкости**: Поддержка различных окружений (dev, stage, prod)
- **Простоты**: Легкое развертывание через Helm

Для получения дополнительной информации см.:
- [Руководство по развертыванию](DEPLOYMENT.md)
- [Конфигурация](CONFIGURATION.md)
- [Быстрый старт](../QUICKSTART.md)
