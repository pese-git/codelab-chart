{{/*
Expand the name of the chart.
*/}}
{{- define "codelab.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "codelab.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "codelab.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "codelab.labels" -}}
helm.sh/chart: {{ include "codelab.chart" . }}
{{ include "codelab.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "codelab.selectorLabels" -}}
app.kubernetes.io/name: {{ include "codelab.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component labels
*/}}
{{- define "codelab.componentLabels" -}}
{{- $component := . -}}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{/*
Auth Service Database URL
*/}}
{{- define "codelab.authService.dbUrl" -}}
{{- if .Values.services.authService.database.url }}
{{- .Values.services.authService.database.url }}
{{- else if eq .Values.services.authService.database.type "sqlite" }}
{{- .Values.services.authService.database.sqliteUrl }}
{{- else }}
{{- $host := .Values.services.authService.database.host }}
{{- if .Values.services.authService.database.useInternal }}
{{- $host = printf "%s-postgres" (include "codelab.fullname" .) }}
{{- end }}
{{- printf "postgresql+asyncpg://%s:%s@%s:%d/%s" .Values.services.authService.database.user .Values.services.authService.database.password $host (int .Values.services.authService.database.port) .Values.services.authService.database.name }}
{{- end }}
{{- end }}

{{/*
Agent Runtime Database URL
*/}}
{{- define "codelab.agentRuntime.dbUrl" -}}
{{- if .Values.services.agentRuntime.database.url }}
{{- .Values.services.agentRuntime.database.url }}
{{- else if eq .Values.services.agentRuntime.database.type "sqlite" }}
{{- .Values.services.agentRuntime.database.sqliteUrl }}
{{- else }}
{{- $host := .Values.services.agentRuntime.database.host }}
{{- if .Values.services.agentRuntime.database.useInternal }}
{{- $host = printf "%s-postgres" (include "codelab.fullname" .) }}
{{- end }}
{{- printf "postgresql+asyncpg://%s:%s@%s:%d/%s" .Values.services.agentRuntime.database.user .Values.services.agentRuntime.database.password $host (int .Values.services.agentRuntime.database.port) .Values.services.agentRuntime.database.name }}
{{- end }}
{{- end }}
