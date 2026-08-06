# Estrutura de repositórios


| # | Repository     | Content                                                                                                                                             |
| - | -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
|   | docs           | Archtecture, guides, designer options, tutorials                                                                                                    |
|   | platform-core  | Execution core, tools records, LLM connection, memory manager                                                                                       |
|   | agent-sdk      | Libraries + template imported from agents.<br />Set the contract:<br />how the agent is set, <br />how declare the tool, <br />how the data return? |
|   | agente-\<nome> | One repository by agent. Example:`google-calendar-agent`, `youtube-publisher-agent`                                                                 |

> **Por que o SDK separado?**
> Porque a plataforma não pode conhecer os agentes, e os agentes não podem conhecer os detalhes internos da plataforma. O SDK é o contrato entre os dois. Se amanhã outra pessoa quiser criar um agente, ela instala o SDK e segue o template. Não precisa ler o código do `platform-core`.

## Visão geral das fases

```
Semana  1  2  3  4  5  6  7  8  9  10  11  12
        ├──F0──┤
              ├────F1────┤
                       ├────F2────┤
                                ├──F3──┤
                                     ├────F4────┤
                                              ├──F5──┤
                                                   ├────F6────┤
F0  Fundação e contratos
F1  Motor de execução (MVP)
F2  Primeiro agente real
F3  Endurecimento da plataforma
F4  Segundo agente (prova de genericidade)
F5  Documentação e DX
F6  Evolução e features avançadas
```

## Detalhamento por fase

### F0 — Fundação e Contratos *(Semana 1–2)*

O objetivo aqui é **não escrever código ainda**. É pensar.


| Tarefa                                                                                | Repo            | Entregável              |
| ------------------------------------------------------------------------------------- | --------------- | ------------------------ |
| Definir a arquitetura geral (o diagrama de camadas)                                   | docs            | `architecture.md`        |
| Definir o formato de declaração de um agente (YAML? JSON? classe Python?)           | docs            | `agent-spec.md`          |
| Definir o contrato de uma ferramenta (assinatura, entrada/saída, tratamento de erro) | docs            | `tool-contract.md`       |
| Criar os 4 repositórios no GitHub com README inicial                                 | todos           | Repos vazios com`README` |
| Configurar branch strategy (`main` protegida, branches `feat/*`, `fix/*`)             | todos           | `CONTRIBUTING.md`        |
| Escolher stack (Python 3.11+, Poetry ou uv pra dependências, pytest)                 | `platform-core` | `pyproject.toml` inicial |

> Dica de estudo: antes de definir o formato do agente, instale o CrewAI e o LangGraph e veja como eles definem agentes. Roube o que fizer sentido, descarte o que for excessivo.

### F1 — Motor de Execução MVP *(Semana 3–5)*

Aqui nasce o coração da plataforma.


| Tarefa                                                                                         | Repo            | Entregável                   |
| ---------------------------------------------------------------------------------------------- | --------------- | ----------------------------- |
| Implementar conexão com Ollama (chat, streaming)                                              | `platform-core` | `llm/ollama_client.py`        |
| Implementar o Tool Registry (decorator @tool, descoberta, validação de assinatura            | `platform-core` | `tools/registry.py`           |
| Implementar o execution loop (pensar → agir → observar → repetir)                           | platform-core   | `platform-core`               |
| Criar 2 ferramentas mock (retornam dados fake) pra testar o loop sem depender de APIs externas | `platform-core` | `tools/mock/`                 |
| Criar o esqueleto do SDK: classe base Agent, método declare(), método execute()              | `agent-sdk`     | Pacote`agent_sdk` instalável |
| Testes unitários do loop com mocks                                                            | `platform-core` | `tests/` com pytest           |

Critério de saída da fase: rodar um comando que carrega um agente mock em YAML, executa 2-3 passos no loop com ferramentas fake, e imprime o resultado. Tudo local, sem nenhuma API externa.

### F2 — Primeiro Agente Real *(Semana 5–7)*

Aqui a plataforma encontra o mundo real. O piloto: Google Calendar


| Tarefa                                                                                | Repo                        | Entregável                  |
| ------------------------------------------------------------------------------------- | --------------------------- | --------------------------- |
| Configurar projeto no Google Cloud Console, habilitar Calendar API, gerar OAuth2      | — (setup externo)           | Credenciais + guia em`docs` |
| Implementar ferramenta `google_calendar_list_events`                                  | `google-calendar-agent`     | `tools/calendar.py`         |
| Implementar ferramenta `google_calendar_create_event` (opcional, stretch)             | `google-calendar-agent`     | `tools/calendar.py`         |
| Definir o YAML do agente com objetivo, ferramentas, modelo                            | `google-calendar-agent`     | `agent.yaml`                |
| Testar ponta a ponta: plataforma carrega o agente → agente lê a agenda → resultado    | `platform-core` + `*-agent` | Teste de integração         |
| Documentar o passo a passo do OAuth (ninguém merece refazer isso sem guia)            | `docs`                      | `guides/google-oauth.md`    |

Critério de saída: `python -m platform run agentes/google-calendar/agent.yaml` retorna os próximos 5 eventos da sua agenda.

### F3 — Endurecimento da Plataforma (Semana 7–8)

Fase *"chata"* mas essencial. Sem ela o projeto quebra na segunda API.

| Tarefa                                                                                        | Repo                | Entregável                  |
| --------------------------------------------------------------------------------------------- | ------------------- | --------------------------- |
| Tratamento de erros no loop (LLM respondeu JSON inválido? ferramenta estourou timeout?)       | `platform-core`     | `engine/error_handling.py`  |
| Sistema de logging estruturado (cada passo do agente gera log com timestamp, tool, resultado) | `platform-core`     | `logging/`                  |
| Configuração centralizada (`.env` pra chaves, `config.yaml` pra settings da plataforma)       | `platform-core`     | `config/`                   |
| Validação de agentes no carregamento (YAML mal formado? ferramenta não registrada?)           | `platform-core`     | `engine/validator.py`       |
| CI básico no GitHub Actions (roda pytest + lint a cada push)                                  | todos               | `.github/workflows/ci.yml`  |
| Versionamento semântico inicial `(v0.1.0) `                                                   | `platform-core` + `agent-sdk` | Tags no GitHub    |

### F4 — Segundo Agente: a Prova de Fogo *(Semana 9–10)*

> Esta é a fase mais importante do projeto.
> Se pra adicionar o segundo agente você precisar alterar o platform-core, a abstração está errada e precisa ser corrigida. A plataforma só é genérica se o agente novo for 100% plug-and-play.

Sugestão de segundo agente: YouTube Publisher (conecta com a ideia original do seu colega) ou Gmail Reader.

| Tarefa                                                                             | Repo                      | Entregável                              |
| -----------------------------------------------------------------------------------| ------------------------- | --------------------------------------- |
| Criar repo `youtube-publisher-agent` usando o template do SDK                      | `youtube-publisher-agent` | Repo novo                               |
| Implementar ferramentas (transcrição via Whisper API, upload via YouTube Data API) | `youtube-publisher-agent` | `tools/`                                |
| Definir `agent.yaml`                                                               | `youtube-publisher-agent` | YAML                                    |
| Rodar na plataforma sem alterar nada no core                                       | __                        | ✅ ou ❌ (se ❌, corrigir a abstração) |
| Registrar no `docs` o que funcionou e o que precisou mudar                         | `docs`                    | `retrospective-agent2.md`               |

### F5 — Documentação e Developer Experience *(Semana 10–11)*

| Tarefa                                                                                                | Repo           | Entregável           |
| ----------------------------------------------------------------------------------------------------- | -------------- | -------------------- |
| Guia "Criando seu primeiro agente em 30 minutos"                                                      | `docs`         | Repo novo            |
| Referência da API do SDK (classes, métodos, decorators)                                               | `agent-sdk`    | `tools/`             |
| Template de agente com `cookiecutter` ou `copier` (gera o boilerplate de um agente novo com um comando) | `agent-sdk`    | `agent-template/   |
| `README` polido em cada repo                                                                          | todos          | READMEs completos    |
| Exemplo de `docker-compose` pra rodar plataforma + Ollama                                             | `platform-core`| `docker-compose.yml` |

### F6 — Evolução *(Semana 12+, contínuo)*

Aqui o projeto está funcional e você começa a iterar conforme interesse:

| Feature                                                                    | Complexidade |
| -------------------------------------------------------------------------- | ------------ | 
| Memória de longo prazo (ChromaDB, Qdrant)                                  | Média        |
| Múltiplos LLMs simultâneos (Ollama + API na nuvem, roteamento por tarefa)  | Média        |
| Interface web simples pra disparar agentes (FastAPI + frontend leve)       | Média        |
| Execução paralela de agentes                                               | Alta         |
| Marketplace de agentes (outros contribuem com agente-*)                    | Alta         |
| Suporte a MCP (Model Context Protocol) como padrão de ferramentas          | Média-Alta   |

### Resumo visual dos repos ao longo do tempo

```
Semana:     1   2   3   4   5   6   7   8   9  10  11  12+
            │   │   │   │   │   │   │   │   │   │   │   │
docs        ██  ██  ░░  ░░  ░░  ░░  ░░  ██  ░░  ░░  ██  ░░
platform    ░░  ██  ██  ██  ██  ░░  ██  ██  ░░  ░░  ░░  ██
agent-sdk   ░░  ░░  ░░  ██  ██  ░░  ░░  ██  ░░  ░░  ██  ░░
agente-cal  ░░  ░░  ░░  ░░  ██  ██  ██  ░░  ░░  ░░  ░░  ░░
agente-yt   ░░  ░░  ░░  ░░  ░░  ░░  ░░  ░░  ██  ██  ░░  ░░

██ = trabalho ativo    ░░ = manutenção / sem foco
```

### Três conselhos pra quem está estudando

1. Comece feio, termine funcional.
O primeiro loop de execução vai ser um `while True` com `json.loads` e `try/except`. Tudo bem. Refatore depois. Se tentar fazer perfeito na `F1`, você nunca sai dela.

2. A `F4` é o verdadeiro teste.
Muita gente constrói uma plataforma, faz UM agente funcionar, e acha que está genérica. Só quando o segundo agente entra sem alterar o core é que você sabe. Se precisar mudar o core, mude. É assim que a abstração amadurece.

3. Documente as decisões, não só o código.
No repo `docs`, crie uma pasta `decisions/` e pra cada escolha relevante escreva um ADR curto:

```
# ADR-003: Formato de definição de agente será YAML
- Data: 2026-08-10
- Contexto: Precisávamos de um formato legível, com suporte a comentários...
- Decisão: YAML em vez de JSON ou TOML
- Consequências: Precisamos de validação com pydantic + pyyaml
```