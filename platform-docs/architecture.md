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

## 2. `agent-spec.md`

```markdown
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

## 3. `tool-contract.md`

```markdown
# Tool Contract — v0.1

Este documento define o contrato que toda ferramenta deve seguir
para ser registrada e utilizada pela plataforma.

---

## 1. O que é uma ferramenta

Uma ferramenta é uma **função Python** que:

- Executa uma ação concreta (chamar API, ler arquivo, processar dado)
- Recebe parâmetros tipados
- Retorna um resultado serializável (string ou dict)
- É registrada no Tool Registry via decorator `@tool`
- É descrita ao LLM pelo **nome + docstring + assinatura**

A ferramenta **não conhece** o agente, o motor, nem o LLM.
Ela é uma função pura com efeitos colaterais controlados.

---

## 2. Definição

### 2.1 Decorator

```python
from agent_sdk import tool

@tool("google_calendar_list_events")
def listar_eventos(qtd: int = 5, dias: int = 7) -> str:
    """Busca os próximos eventos na agenda do Google Calendar.

    Args:
        qtd: Número máximo de eventos a retornar.
        dias: Quantos dias à frente consultar.

    Returns:
        String formatada com os eventos encontrados.
    """
    # implementação
    ...
```

### 2.2 O que o decorator faz

1. Registra a função no TOOL_REGISTRY global.
2. Extrai o nome (primeiro argumento do decorator).
3. Extrai a descrição (primeira linha da docstring).
4. Inspeciona a assinatura (parâmetros, tipos, defaults).
5. Gera a representação que o LLM verá.

## 3. Regras obrigatórias

| # | Regra                                  | Motivo                                                         |
| - | -------------------------------------- | -------------------------------------------------------------- |
| 1 | Nome em `snake_case`, prefixo do domínio | Evita colisão: `google_calendar_*`, `youtube_*`              | 
| 2 | Docstring presente e em inglês         | O LLM usa como descrição. Sem docstring = ferramenta invisível | 
| 3 | Parâmetros com type hints              | Necessário pra gerar o schema JSON pro LLM                     | 
| 4 | Retorno: `str` ou `dict[str, Any]`     | O motor serializa e injeta nas mensagens                       | 
| 5 | Sem estado global mutável              | Ferramentas devem ser idempotentes quando possível             | 
| 6 | Erros lançam `ToolExecutionError`      | O motor captura e decide se retry ou aborta                    | 
| 7 | Timeout interno                        | Toda chamada externa (HTTP, arquivo) deve ter timeout          | 
| 8 | Sem `print()`                          | Usar `logging` do módulo. Output vai pro log estruturado       |  

## 4. Tipos compartilhados

```python
# agent_sdk/types.py

from dataclasses import dataclass
from typing import Any

@dataclass
class ToolResult:
    """Resultado padronizado de uma ferramenta."""
    sucesso: bool
    dados: str | dict[str, Any]
    erro: str | None = None
    duracao_ms: float = 0.0

class ToolExecutionError(Exception):
    """Erro controlado de execução de ferramenta."""
    def __init__(self, mensagem: str, retry: bool = False):
        super().__init__(mensagem)
        self.retry = retry  # motor decide se tenta de novo
```

## 5. Como o LLM vê a ferramenta

O Tool Registry gera a seguinte descrição pra injetar no prompt:

```text
- google_calendar_list_events
  Descrição: Busca os próximos eventos na agenda do Google Calendar.
  Parâmetros:
    - qtd (int, default=5): Número máximo de eventos a retornar.
    - dias (int, default=7): Quantos dias à frente consultar.
  Retorno: str
```

Essa descrição é derivada automaticamente de:

* Nome → primeiro argumento do @tool()
* Descrição → primeira linha da docstring
* Parâmetros → inspect.signature() + type hints
* Default → valor default dos parâmetros

## 6. Registro e descoberta
### 6.1 Registro automático

Ao importar o módulo tools/ de um agente, todas as funções decoradas com `@tool` são automaticamente registradas:

```python
# platform-core carrega assim:
import importlib

modulo = importlib.import_module(f"{agent_repo}.tools")
# O import executa os decorators → registry populado
```

### 6.2 Validação no carregamento

```python
# engine/validator.py
def validar_ferramentas(config: AgentConfig, registry: ToolRegistry):
    for nome in config.ferramentas:
        if nome not in registry:
            raise ToolNotFoundError(
                f"Ferramenta '{nome}' declarada em agent.yaml "
                f"não está registrada. Verifique o import."
            )
```

## 7. Tratamento de erros

| Cenário                           | Comportamento do motor                        | 
| --------------------------------- | --------------------------------------------- | 
| `ToolExecutionError(retry=True)`  | Retry até 2x com backoff de 2s                | 
| `ToolExecutionError(retry=False)` | Retorna erro ao LLM, deixa ele decidir        | 
| Timeout da ferramenta             | `ToolExecutionError(retry=True)` automático   | 
| Exceção não tratada (`Exception`) | Log de erro, retorna mensagem genérica ao LLM | 
| 3 retries falharam                | Motor finaliza com `status: "erro"`           | 

O LLM sempre recebe o erro como texto na conversa:

```json
{
  "role": "tool",
  "content": "ERRO na ferramenta 'google_calendar_list_events': Timeout após 30s. Tente novamente ou finalize."
}
```

## 8. Convenção de nomenclatura

```
<dominio>_<acao>[_<qualificador>]

Exemplos:
  google_calendar_list_events
  google_calendar_create_event
  youtube_upload_video
  youtube_set_metadata
  file_read_text
  file_write_text
  http_get
  http_post
```

| Parte          | Regra                                                            | 
| -------------- | ---------------------------------------------------------------- | 
| `dominio`      | Serviço ou sistema. `google_calendar`, `youtube`, `file`, `http` | 
| `acao`         | Verbo no infinitivo. `list`, `create`, `read`, `upload`, `send`  | 
| `qualificador` | Opcional, desambigua. `events`, `video`, `text`                  | 

## 9. Testes

Toda ferramenta deve ter testes unitários sem dependência externa:

```python
# tests/test_calendar.py
from unittest.mock import patch
from tools.calendar import listar_eventos

def test_listar_eventos_retorna_formato_correto():
    with patch("tools.calendar.chamar_google_api") as mock_api:
        mock_api.return_value = [
            {"summary": "Reunião", "start": {"dateTime": "2026-08-07T10:00:00"}}
        ]
        resultado = listar_eventos(qtd=1, dias=1)
        assert "Reunião" in resultado
        assert "07/08/2026" in resultado

def test_listar_eventos_api_fora_do_ar():
    with patch("tools.calendar.chamar_google_api", side_effect=TimeoutError):
        with pytest.raises(ToolExecutionError) as exc_info:
            listar_eventos(qtd=1)
        assert exc_info.value.retry is True
```

## 10. Checklist de conformidade
Antes de submeter uma ferramenta nova, verificar:

* Decorada com `@tool("nome_em_snake_case")`
* Docstring presente, primeira linha descreve a ação
* Todos os parâmetros com type hint
* Retorno é `str` ou `dict`
* Erros lançam `ToolExecutionError`
* Chamadas externas têm timeout
* Sem `print()`, usa `logging`
* Testes unitários com mocks passam
* Nome segue convenção `<dominio>_<acao>[_<qualificador>]`
* Sem dependência de estado global

```

---

## Estrutura final no `platform-docs`
platform-docs/
├── README.md
├── architecture.md              ← documento 1
├── agent-spec.md                ← documento 2
├── tool-contract.md             ← documento 3
├── decisions/
│   └── adr-001-modelo-de-agentes.md   ← ADR que já fizemos
└── guides/
    └── (vazio por enquanto, preenchido na F5)
```


---

## Próximo passo

Com esses três documentos fechados, a F0 ainda pede:

| Entregável | Status |
|---|---|
| `architecture.md` | ✅ Acima |
| `agent-spec.md` | ✅ Acima |
| `tool-contract.md` | ✅ Acima |
| ADR-001 | ✅ Feito anteriormente |
| Criar os 4 repos no GitHub com README | ⬜ Próximo |
| `pyproject.toml` inicial em `platform-core` e `agent-sdk` | ⬜ Próximo |
| `CONTRIBUTING.md` + branch strategy | ⬜ Próximo |
| CI básico (GitHub Actions) | ⬜ Pode esperar pra F3 |