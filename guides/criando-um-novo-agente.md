# Guia: criando um novo agente (baby steps)

> Do zero até um agente rodando no motor, em passos pequenos com
> checkpoint em cada um. Troque `meu-novo-agente` pelo nome do seu
> agente (kebab-case). O que o agente FAZ é escolha sua — este guia
> ensina o CONTRATO da plataforma.

---

## Passo 0 — Pré-requisitos

```powershell
cd F:\ai-platform
uv run platform version     # esperado: "platform-core 0.1.0"
ollama list                 # esperado: llama3.1:8b na lista
```

Se o Ollama não estiver rodando: `ollama serve`.

✅ Os dois comandos OK? Siga. ❌? Resolva antes de continuar.

---

## Passo 1 — Criar o esqueleto

```powershell
New-Item -ItemType Directory -Force meu-novo-agente\tools, meu-novo-agente\tests
```

Layout alvo:

```
meu-novo-agente/
├── agent.yaml          # declaração do agente (passo 6)
├── tools/
│   ├── __init__.py     # OBRIGATÓRIO (torna tools/ um pacote)
│   └── minhas_tools.py # suas ferramentas @tool
├── tests/
├── test_manual.py      # teste rápido fora do pytest
└── pyproject.toml
```

---

## Passo 2 — `pyproject.toml` (versão LOCAL)

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "meu-novo-agente"
version = "0.1.0"
description = "Descricao curta do meu agente."
readme = "README.md"
license = { text = "PolyForm-Noncommercial-1.0.0" }
requires-python = ">=3.11"
dependencies = [
    "agent-sdk",
    # ...deps da SUA API externa entram aqui depois...
]

[dependency-groups]
dev = ["pytest>=8.0", "pytest-mock>=3.14", "ruff>=0.5"]

[tool.hatch.build.targets.wheel]
packages = ["tools"]

[tool.ruff]
target-version = "py311"
line-length = 100
src = ["tools", "tests"]

[tool.ruff.lint]
select = ["E", "W", "F", "I", "N", "UP", "B", "SIM", "RUF"]
ignore = ["E501", "SIM117"]

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = ["--strict-markers", "--tb=short", "-q"]
markers = ["integration: chama APIs reais"]

[tool.uv.sources]
agent-sdk = { workspace = true }
```

> ⚠️ `workspace = true` é a versão **LOCAL** (obrigatória porque o agente
> será membro do workspace). A versão **COMMITADA** usa fonte git —
> trocamos no passo 12.

---

## Passo 3 — Entrar no workspace

Edite o `pyproject.toml` da **raiz** (`F:\ai-platform`):

```toml
[tool.uv.workspace]
members = [
    "agent-sdk",
    "platform-core",
    "google-calendar-agent",
    "youtube-publisher-agent",
    "meu-novo-agente",
]
```

Sincronize:

```powershell
uv sync --group dev
```

✅ Sem erros de resolução? Siga.

---

## Passo 4 — Primeira tool (SEM API externa)

`tools/__init__.py`:

```python
"""Ferramentas do meu-novo-agente."""
```

`tools/minhas_tools.py` — tool de treino, só stdlib:

```python
"""Ferramentas do meu-novo-agente."""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

from agent_sdk import ToolExecutionError, ToolResult, tool


@tool("hora_atual")
def hora_atual(fuso: str = "America/Sao_Paulo") -> ToolResult:
    """Retorna a data e hora atuais no fuso informado.

    Args:
        fuso: Nome do fuso horario (ex: America/Sao_Paulo).

    Returns:
        Dicionario com agora (ISO) e fuso.
    """
    try:
        agora = datetime.now(ZoneInfo(fuso))
        return ToolResult.ok({"agora": agora.isoformat(), "fuso": fuso})
    except Exception as exc:
        raise ToolExecutionError(f"Fuso invalido: {fuso} ({exc})", retry=False) from exc
```

### Regras do contrato (decorar uma vez, ler sempre)

| Regra | Como é |
|---|---|
| Nome da tool | `@tool("nome")` **posicional** — nunca `name=` |
| Descrição pro LLM | **1ª linha do docstring** |
| Parâmetros | assinatura com type hints + defaults |
| Sucesso | `ToolResult.ok(dados)` |
| Erro controlado | `raise ToolExecutionError(msg, retry=True/False)` |
| Atributos do resultado | `sucesso`, `dados`, `erro` (português!) |
| `retry` | `True` = transitório (rede/timeout); `False` = permanente (arquivo não existe, ID inválido) |

---

## Passo 5 — Teste manual da tool

`test_manual.py` (raiz do agente):

```python
from tools.minhas_tools import hora_atual

r = hora_atual()
print(r.sucesso, r.dados)
```

```powershell
cd meu-novo-agente
uv run python test_manual.py
```

✅ Esperado: `True {'agora': '...', 'fuso': 'America/Sao_Paulo'}`

---

## Passo 6 — `agent.yaml`

```yaml
nome: "Meu Novo Agente"
versao: "0.1.0"
modelo: "llama3.1:8b"
temperatura: 0.1
instrucoes: >
  Voce e um assistente prestativo.
  Use as ferramentas disponiveis antes de responder.
  NUNCA invente dados que as ferramentas podem obter.
  Responda em portugues, de forma concisa.
ferramentas:
  - hora_atual
tarefa:
  descricao: >
    Consulte a hora atual e responda que horas sao agora
    no fuso de Sao Paulo.
  saida_esperada: >
    Uma frase com a data e hora atuais.
max_passos: 5
timeout_segundos: 120
metadata:
  tags: ["exemplo"]
```

> O YAML pode ficar na raiz (ao lado de `tools/`) ou em `agents/` —
> a plataforma acha `tools/` por busca ascendente (ADR-004).
> Campo opcional `tools_dir: "../tools"` torna isso explícito.

---

## Passo 7 — Validação pré-voo

```powershell
cd F:\ai-platform
uv run platform validate meu-novo-agente/agent.yaml
```

✅ `[OK] YAML valido: Meu Novo Agente v0.1.0`

---

## Passo 8 — Descoberta de ferramentas

```powershell
uv run platform tools list meu-novo-agente/agent.yaml
```

✅ `hora_atual` aparece com a descrição do docstring.

---

## Passo 9 — Primeiro run end-to-end

```powershell
uv run platform run meu-novo-agente/agent.yaml --verbose
```

✅ Painel verde com a resposta do LLM usando `hora_atual`.

**Parabéns: seu agente roda no motor.** A partir daqui é iteração.

---

## Passo 10 — Sua primeira tool REAL (API externa)

Quando for implementar o que o agente realmente faz, nesta ordem:

1. **Cliente separado**: `tools/meu_client.py` (auth/conexão) + `tools/minhas_tools.py` (tools). Imports internos: `from tools.meu_client import ...`
2. **Segredos fora do repo**: `<raiz>/secrets/<agente>/` + override por env var (ex: `MEU_AGENT_SECRETS_PATH`). Nunca commitar `client_secret.json`/`token.json`
3. **Menor privilégio**: só os escopos/permissões que a tarefa precisa; primeira tarefa do YAML **somente leitura**
4. **Teste manual** de cada tool nova (`test_manual.py`) ANTES de colocar no YAML
5. **Uma tool por vez** no YAML, com re-run entre elas
6. **Quota**: se a API tiver limite (ex: YouTube = 10k unidades/dia), anote no README

---

## Passo 11 — Testes automatizados

`tests/test_minhas_tools.py`:

```python
from tools.minhas_tools import hora_atual


def test_hora_atual_ok():
    r = hora_atual()
    assert r.sucesso
    assert "agora" in r.dados
```

```powershell
cd meu-novo-agente
uv run python -m pytest tests/ -q
uv run ruff check --fix tools tests
uv run ruff check tools tests
```

✅ `1 passed` + `All checks passed!`

---

## Passo 12 — Housekeeping + push

1. `.gitignore` no agente:

```gitignore
__pycache__/
*.pyc
.venv/
token.json
client_secret.json
```

2. `LICENSE` = cópia do PolyForm (igual aos outros repos) + `README.md`
3. **Trocar a fonte pra versão COMMITADA** no `pyproject.toml`:

```toml
[tool.uv.sources]
agent-sdk = { git = "https://github.com/willimar/agent-sdk.git" }
```

4. Commit + push (novo agente entra **por último** na ordem):

```
agent-sdk → platform-core → google-calendar-agent
→ youtube-publisher-agent → platform-docs → agent-platform → meu-novo-agente
```

5. Restaurar o modo local e travar:

```powershell
# volte a linha para: agent-sdk = { workspace = true }
git update-index --assume-unchanged pyproject.toml
```

---

## Apêndice — Erros reais já vistos (e suas curas)

| Sintoma | Causa | Cura |
|---|---|---|
| `tool() got an unexpected keyword argument 'name'` | `@tool(name=...)` | `@tool("nome")` posicional |
| `'ToolResult' object has no attribute 'data'` | atributo em inglês | `.dados` / `.sucesso` / `.erro` |
| `No module named 'tools.x'` | `__init__.py` ausente | criar `tools/__init__.py` |
| `List should have at least 1 item` (ferramentas) | YAML ou teste com `ferramentas: []` | mínimo 1 tool |
| `does not exist` no validate | caminho errado do YAML | caminho relativo à raiz do workspace |
| `duplicate key [tool.uv.sources]` | duas seções no pyproject commitado | exatamente UMA seção |
| `invalid_scope` no OAuth | escopo descontinuado | conferir scopes atuais na doc do provedor |
| LLM repetindo a mesma tool em loop | tool falhando sempre | olhar `ferramenta_erro_controlado` no log; corrigir a tool, não o prompt |