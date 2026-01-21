# Changelog

Все значимые изменения в проекте CodeLab Helm Chart будут документированы в этом файле.

Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.0.0/),
и этот проект придерживается [Semantic Versioning](https://semver.org/lang/ru/).

## [0.1.0] - 2026-01-21

### Добавлено

- Первый релиз Helm chart для CodeLab платформы
- Поддержка всех основных сервисов:
  - Gateway (WebSocket API)
  - Auth Service (OAuth2 сервер)
  - Agent Runtime (мультиагентная система)
  - LLM Proxy (прокси для LLM провайдеров)
  - Redis (кэширование и сессии)
  - PostgreSQL (персистентное хранилище)
  - Website (опционально)
- Конфигурации для различных окружений:
  - `values-dev.yaml` - для разработки
  - `values-stage.yaml` - для staging
  - `values-stage-minimal.yaml` - минимальная конфигурация для staging
  - `values-prod.yaml` - для production
- Ingress с поддержкой:
  - TLS/SSL через cert-manager
  - WebSocket соединений
  - Гибкой маршрутизации путей
- Поддержка SQLite и PostgreSQL для баз данных
- Persistent Volumes для хранения данных
- Health checks для всех сервисов
- Security context для безопасного запуска подов
- Документация:
  - README.md - общее описание и быстрый старт
  - QUICKSTART.md - пошаговое руководство
  - HARBOR-SETUP.md - настройка доступа к Harbor registry
  - LETSENCRYPT.md - настройка автоматических SSL сертификатов
  - doc/ARCHITECTURE.md - архитектура системы
  - doc/DEPLOYMENT.md - руководство по развертыванию
  - doc/CONFIGURATION.md - описание параметров конфигурации

### Особенности

- Гибкая конфигурация через values файлы
- Поддержка внутреннего и внешнего PostgreSQL
- Автоматическое создание множественных баз данных
- Поддержка imagePullSecrets для приватных registry
- Настраиваемые ресурсы (CPU, Memory) для каждого сервиса
- Горизонтальное масштабирование stateless сервисов
- Rolling updates с zero-downtime

### Технические детали

- Kubernetes 1.19+
- Helm 3.0+
- Nginx Ingress Controller
- cert-manager для автоматических сертификатов
- PostgreSQL 16 Alpine
- Redis 7 Alpine

## [Unreleased]

### Планируется

- Поддержка Horizontal Pod Autoscaler (HPA)
- Network Policies для изоляции сервисов
- ServiceMonitor для Prometheus
- Поддержка внешнего Redis Cluster
- Helm hooks для миграций БД
- Поддержка Blue-Green и Canary развертываний
- Интеграция с External Secrets Operator
- Поддержка multi-region развертывания

---

## Формат версий

- **MAJOR** версия - несовместимые изменения API
- **MINOR** версия - новая функциональность с обратной совместимостью
- **PATCH** версия - исправления ошибок с обратной совместимостью

## Типы изменений

- **Добавлено** - новая функциональность
- **Изменено** - изменения в существующей функциональности
- **Устарело** - функциональность, которая будет удалена в будущих версиях
- **Удалено** - удаленная функциональность
- **Исправлено** - исправления ошибок
- **Безопасность** - исправления уязвимостей
