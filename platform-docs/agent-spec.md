# Agent Specification — v0.1

Este documento define o formato canônico de declaração de um agente.
Todo arquivo `agent.yaml` deve estar em conformidade com esta
especificação.

---

## 1. Formato

- Arquivo: `agent.yaml` (ou `agent.yml`)
- Encoding: UTF-8
- Schema validado via Pydantic v2 no carregamento

---

## 2. Campos

### 2.1 Obrigatórios

| Campo             | Tipo     | Descrição                                        |
|-------------------|----------|--------------------------------------------------|
| `nome`            | `string` | Nome legível do agente. Ex: `"Ler Agenda Google"` |
| `versao`          | `string` | Versão semântica do agente. Ex: `"1.0.0"`         |
| `modelo`          | `string` | Identificador do LLM. Ex: `"llama3.1:8b"`         |
| `instrucoes`      | `string` | Instruções de comportamento (vira system prompt)  |
| `ferramentas`     | `list[string]` | Nomes das ferramentas que o agente pode usar |
| `tarefa.descricao`| `string` | O que o agente deve fazer                        |
| `tarefa.saida_esperada` | `string` | Critério de sucesso / formato da resposta |

### 2.2 Opcionais

| Campo             | Tipo     | Default | Descrição                              |
|-------------------|----------|---------|----------------------------------------|
| `max_passos`      | `int`    | `5`     | Máximo de iterações do loop            |
| `temperatura`     | `float`  | `0.1`   | Temperatura do LLM                     |
| `timeout_segundos`| `int`    | `120`   | Timeout total da execução              |
| `modelo_fallback` | `string` | `null`  | Modelo alternativo se o principal falhar |
| `metadata`        | `dict`   | `{}`    | Campos livres (autor, tags, etc.)      |

---

## 3. Schema completo (exemplo anotado)

```yaml
# ── Identificação ──────────────────────────────
nome: "Ler Agenda Google"            # obrigatório
versao: "1.0.0"                      # obrigatório, semver

# ── LLM ───────────────────────────────────────
modelo: "llama3.1:8b"                # obrigatório
temperatura: 0.1                     # opcional, 0.0 a 2.0
modelo_fallback: "mistral:7b"        # opcional

# ── Comportamento ─────────────────────────────
instrucoes: >                        # obrigatório, multi-linha ok
  Você é um assistente que consulta a agenda do usuário.
  Responda sempre em português, de forma concisa.
  Se não houver eventos, diga explicitamente que a agenda está livre.

# ── Ferramentas ───────────────────────────────
ferramentas:                         # obrigatório, mínimo 1
  - google_calendar_list_events

# ── Tarefa ────────────────────────────────────
tarefa:                              # obrigatório
  descricao: >
    Consulte os próximos eventos da agenda do usuário
    para os próximos 7 dias.
  saida_esperada: >
    Lista formatada com data (dd/mm/aaaa), hora (hh:mm)
    e título de cada evento, ordenada cronologicamente.
    Se não houver eventos, responder: "Agenda livre."

# ── Execução ──────────────────────────────────
max_passos: 5                        # opcional
timeout_segundos: 120                # opcional

# ── Metadados livres ─────────────────────────
metadata:                            # opcional
  autor: "seu-nome"
  tags: ["produtividade", "agenda"]
  criado_em: "2026-08-06"
```
---

## 4. Regras de validação

| Regra                                     | Erro|
| ----------------------------------------- | ---------------------------------------------------------------------|
| `nome` vazio ou ausente                   | `AgentValidationError: campo 'nome' é obrigatório`                     |
| `versao` não é semver válido              | `AgentValidationError: 'versao' deve seguir MAJOR.MINOR.PATCH`         |
| `ferramentas` é lista vazia               | `AgentValidationError: agente deve ter ao menos 1 ferramenta`          |
| Ferramenta listada não existe no registry | `ToolNotFoundError: 'xyz' não registrada`                              |
| `max_passos` < 1 ou > 50                  | `AgentValidationError: 'max_passos' deve estar entre 1 e 50`           |
| `temperatura` fora de [0.0, 2.0]          | `AgentValidationError: 'temperatura' deve estar entre 0.0 e 2.0`       |
| `tarefa` ausente ou incompleta            | `AgentValidationError: 'tarefa' requer 'descricao' e 'saida_esperada'` |

## 5. Ciclo de vida do agente

```
         ┌───────────┐
         │  YAML     │
         │  em disco │
         └─────┬─────┘
               ▼
         ┌───────────┐
         │  LOAD     │  platform-core lê e parseia
         └─────┬─────┘
               ▼
         ┌───────────┐
         │  VALIDATE │  Pydantic valida schema + tools existem
         └─────┬─────┘
               ▼
         ┌───────────┐
         │  READY    │  AgentConfig montado, pronto pra executar
         └─────┬─────┘
               ▼
         ┌───────────┐
         │  RUNNING  │  Loop de execução ativo
         └─────┬─────┘
               ▼
     ┌─────────┴─────────┐
     ▼                   ▼
┌──────────┐      ┌──────────┐
│COMPLETED │      │  ERROR   │
└──────────┘      └──────────┘
```

## 6. Montagem do system prompt

A partir do YAML, o platform-core monta o seguinte system prompt:

Você é o agente "{nome}".

## Instruções
{instrucoes}

## Tarefa
{tarefa.descricao}

## Formato de saída esperado
{tarefa.saida_esperada}

## Ferramentas disponíveis
{lista de ferramentas com nome, descrição e parâmetros}

## Regras de resposta
Responda SEMPRE em JSON válido, sem markdown:
- Para usar uma ferramenta:
  {{"acao": "usar_ferramenta", "ferramenta": "<nome>", "parametros": {{...}}}}
- Para finalizar:
  {{"acao": "finalizar", "resposta": "<texto final>"}}

Não invente ferramentas que não estão na lista.
Não responda fora do formato JSON.

## 7. Exemplos adicionais
### 7.1 Agente mínimo

```yaml
nome: "Echo"
versao: "0.1.0"
modelo: "llama3.1:8b"
instrucoes: "Repita o que o usuário disser."
ferramentas:
  - echo
tarefa:
  descricao: "Repita a mensagem recebida."
  saida_esperada: "A mesma mensagem, sem alterações."
  ```

### 7.2 Agente com múltiplas ferramentas

```yaml
nome: "YouTube Publisher"
versao: "1.0.0"
modelo: "llama3.1:8b"
temperatura: 0.3
instrucoes: >
  Você é um assistente de publicação de vídeos.
  Analise o conteúdo, gere título, descrição e tags,
  e publique no YouTube.
ferramentas:
  - transcribe_audio
  - analyze_video_frames
  - youtube_upload
  - youtube_set_metadata
tarefa:
  descricao: >
    Receba um arquivo de vídeo, transcreva, analise o conteúdo,
    gere metadados (título, descrição, tags) e publique.
  saida_esperada: >
    JSON com: titulo, descricao, tags[], url_do_video, status.
max_passos: 10
timeout_segundos: 300
metadata:
  autor: "seu-nome"
  tags: ["youtube", "automação"]
```

## 8. Extensibilidade futura

Campos reservados para versões futuras (não implementar na v0.1):

| Campo futuro     | Versão alvo  | Propósito                               |
|----------------- | ------------ | --------------------------------------- |
| memoria          | 0.3          | Configuração de memória de longo prazo  |
| multi_modelo     | 0.2          | Roteamento entre modelos por etapa      |
| aprovacao_humana | 0.3          | Pausar e pedir confirmação              |
| dependencias     | 0.4          | Agentes que dependem de outros agentes  |
| schedule         | 1.0          | Execução agendada (cron)                |



---