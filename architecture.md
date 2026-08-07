# Architecture — Agent Platform v0.1

| Campo       | Valor              |
|-------------|--------------------|
| Versão      | 0.1.0              |
| Data        | 2026-08-06         |
| Status      | Aprovada           |
| ADR ref.    | ADR-001            |

---

## 1. Visão

Plataforma genérica de execução de agentes. Recebe definições
declarativas de agentes (YAML), carrega as ferramentas
correspondentes, e executa o loop de raciocínio-ação até a
conclusão da tarefa.

A plataforma **não conhece** nenhum agente específico.
Agentes são plugáveis e independentes.

---

## 2. Diagrama de componentes

```
┌────────────────────────────────────────────────────────────────┐
│                        platform-core                           │
│                                                                │
│  ┌─────────────┐   ┌──────────────────┐   ┌─────────────────┐  │
│  │   Config    │   │     Engine       │   │   LLM Client    │  │
│  │   Loader    │──►│  (executor +     │◄─►│  (Ollama /      │  │
│  │             │   │   state machine) │   │   OpenAI / …)   │  │
│  └─────────────┘   └────────┬─────────┘   └─────────────────┘  │
│                             │                                  │
│                             ▼                                  │
│                    ┌─────────────────┐                         │
│                    │  Tool Registry  │                         │
│                    └────────┬────────┘                         │
│                             │                                  │
└─────────────────────────────┼──────────────────────────────────┘
                              │
              ┌───────────────┼───────────────────┐
              ▼               ▼                   ▼
     ┌──────────────┐ ┌──────────────┐  ┌──────────────┐
     │ google-      │ │ youtube-     │  │  <future>-   │
     │ calendar-    │ │ publisher-   │  │  agent       │
     │ agent        │ │ agent        │  │              │
     │              │ │              │  │              │
     │ agent.yaml   │ │ agent.yaml   │  │ agent.yaml   │
     │ tools/       │ │ tools/       │  │ tools/       │
     └──────────────┘ └──────────────┘  └──────────────┘
              ▲               ▲                   ▲
              └───────────────┼───────────────────┘
                              │
                     ┌────────────────┐
                     │   agent-sdk    │
                     │  (contrato)    │
                     └────────────────┘
```

---

## 3. Componentes e responsabilidades

### 3.1 platform-core

| Módulo             | Responsabilidade                                          |
|--------------------|-----------------------------------------------------------|
| `config/loader.py` | Lê e valida `agent.yaml`. Retorna um `AgentConfig` tipado |
| `engine/state.py`  | Define `AgentState` (mensagens, passo, resultado, status)  |
| `engine/executor.py`| Loop principal: raciocínio → decisão → execução → repeat  |
| `engine/validator.py`| Validações pré-execução (ferramentas existem? modelo acessível?) |
| `llm/client.py`    | Abstração de LLM. Implementações: Ollama, OpenAI-compatível |
| `llm/parser.py`    | Interpreta resposta JSON do LLM. Retry em JSON inválido    |
| `tools/registry.py`| Registro central de ferramentas. Decorator `@tool`         |
| `logging/`         | Log estruturado de cada passo (JSON lines)                 |

### 3.2 agent-sdk

| Módulo              | Responsabilidade                                         |
|---------------------|----------------------------------------------------------|
| `base.py`           | Classe/protocolo que define o contrato de um agente       |
| `decorators.py`     | `@tool` — registra função como ferramenta                 |
| `types.py`          | Tipos compartilhados (`ToolResult`, `AgentConfig`, etc.)  |
| `templates/`        | Boilerplate pra gerar um agente novo com um comando       |
| `testing.py`        | Helpers pra testar agentes com LLM e tools mockadas       |

### 3.3 Repositórios de agente (`*-agent`)

| Arquivo / Pasta     | Responsabilidade                                         |
|---------------------|----------------------------------------------------------|
| `agent.yaml`        | Definição declarativa do agente (ver `agent-spec.md`)    |
| `tools/`            | Implementação das ferramentas específicas                 |
| `tests/`            | Testes unitários das ferramentas                          |
| `README.md`         | Documentação de uso e configuração                        |
| `requirements.txt`  | Dependências específicas do agente (ex: `google-api-python-client`) |

---

## 4. Fluxo de execução

```
                   Usuário / CLI
                         │
                         ▼
┌─────────────────────────────────────────────────┐
│ 1. LOAD                                         │
│    platform-core lê agent.yaml                  │
│    → valida schema                              │
│    → carrega ferramentas listadas               │
│    → monta system prompt                        │
└───────────────────────┬─────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────┐
│ 2. LOOP (repete até finalizar ou max_passos)    │
│                                                 │
│  2a. RACIOCÍNIO                                 │
│      Envia mensagens ao LLM                     │
│      LLM responde em JSON estruturado           │
│                                                 │
│  2b. DECISÃO                                    │
│      ├── "usar_ferramenta" → vai pra 2c         │
│      └── "finalizar"       → vai pra 3          │
│                                                 │
│  2c. EXECUÇÃO                                   │
│      Tool Registry executa a função             │
│      Resultado é anexado às mensagens           │
│      Volta pra 2a                               │
│                                                 │
└───────────────────────┬─────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────┐
│ 3. RESULTADO                                    │
│    Retorna AgentState com status + resposta     │
│    Log final é gravado                          │
└─────────────────────────────────────────────────┘
```


---

## 5. Decisões tecnológicas (v0.1)

| Decisão                  | Escolha              | Justificativa                          |
|--------------------------|----------------------|----------------------------------------|
| Linguagem                | Python 3.11+         | Ecossistema de IA, tipagem, asyncio    |
| Gerenciador de deps      | `uv`                 | Rápido, lockfile, substitui pip+venv   |
| LLM local                | Ollama               | Já em uso, API compatível com OpenAI   |
| Formato de agente        | YAML                 | Legível, suporta comentários, declarativo |
| Validação de schema      | Pydantic v2          | Tipagem + validação + serialização     |
| Testes                   | pytest               | Padrão de mercado                      |
| Lint / format            | ruff                 | Rápido, substitui flake8+isort+black   |
| CI                       | GitHub Actions       | Integrado ao GitHub                    |
| Logging                  | structlog (JSON)     | Estruturado, fácil de filtrar          |
| Versionamento            | SemVer               | `MAJOR.MINOR.PATCH`                   |

---

## 6. Restrições e premissas da v0.1

- **Um agente por execução.** Sem paralelismo entre agentes.
- **Estado em memória.** Sem persistência entre execuções.
- **LLM único por agente.** Sem roteamento entre modelos.
- **Ferramentas síncronas.** Sem `async` no loop de ferramentas.
- **Sem interface web.** Execução via CLI.
- **Sem multi-agente.** Um agente não invoca outro.

Essas restrições serão revisitadas a partir da v0.2.

---

## 7. Modelo de comunicação

- `agent.yaml`  ── (YAML parse) ──► `AgentConfig` (Pydantic)
- `AgentConfig` ── (validação) ───► `Engine`
- `Engine`      ── (HTTP POST) ───► LLM (Ollama localhost:11434)
- `Engine`      ── (chamada direta) ──► `ToolRegistry` ──► `tool function`
- `ToolRegistry` ── (retorno) ──► `Engine` (string / dict)


Nenhuma comunicação entre agentes. Nenhuma comunicação assíncrona.
Tudo síncrono, single-thread, na v0.1.

---

## 8. Estrutura de diretórios

```
platform-core/
├── src/
│   └── platform_core/
│       ├── init.py
│       ├── cli.py                  # entry point: platform run <agent.yaml>
│       ├── config/
│       │   ├── init.py
│       │   ├── loader.py
│       │   └── schema.py           # modelos Pydantic do YAML
│       ├── engine/
│       │   ├── init.py
│       │   ├── executor.py
│       │   ├── state.py
│       │   └── validator.py
│       ├── llm/
│       │   ├── init.py
│       │   ├── client.py           # interface abstrata
│       │   ├── ollama.py
│       │   └── parser.py
│       ├── tools/
│       │   ├── init.py
│       │   └── registry.py
│       └── logging/
│           ├── init.py
│           └── structured.py
├── tests/
├── pyproject.toml
├── Makefile
└── README.md
agent-sdk/
├── src/
│   └── agent_sdk/
│       ├── init.py
│       ├── base.py
│       ├── decorators.py
│       ├── types.py
│       └── testing.py
├── templates/
│   └── agent-template/
│       ├── agent.yaml
│       ├── tools/
│       │   └── example.py
│       ├── tests/
│       └── README.md
├── pyproject.toml
└── README.md
google-calendar-agent/
├── agent.yaml
├── tools/
│   ├── init.py
│   └── calendar.py
├── tests/
│   └── test_calendar.py
├── requirements.txt
└── README.md
```


---

## 9. Interface CLI (v0.1)

```bash
# Executa um agente
platform run ./google-calendar-agent/agent.yaml

# Valida um YAML sem executar
platform validate ./google-calendar-agent/agent.yaml

# Lista ferramentas registradas
platform tools list

# Executa com verbose (log de cada passo)
platform run ./google-calendar-agent/agent.yaml --verbose
```

## 10. Roadmap de versões

| Versão | Escopo                                        |
| ------ | --------------------------------------------- |
| 0.1    | Loop funcional, 1 agente, Ollama, CLI         |
| 0.2    | Múltiplos modelos, retry, logging estruturado |
| 0.3    | Persistência de estado, human-in-the-loop     |
| 0.4    | Execução assíncrona, paralelismo de tools     |
| 1.0    | API estável, documentação completa, marketplace    |

---