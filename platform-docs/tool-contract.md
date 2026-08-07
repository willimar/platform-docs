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