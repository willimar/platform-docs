# platform-docs

Documentação central da Agent Platform. Contém arquitetura,
especificações, decisões de design (ADRs) e guias de uso.

---

## Índice

| Documento | Descrição |
|-----------|-----------|
| [architecture.md](platform-docs/architecture.md) | Visão geral, componentes, fluxo de execução |
| [agent-spec.md](platform-docs/agent-spec.md) | Especificação do formato `agent.yaml` |
| [tool-contract.md](platform-docs/tool-contract.md) | Contrato de ferramentas (decorator, tipos, regras) |
| [decisions/](decisions/) | Architecture Decision Records (ADRs) |
| [guides/](guides/) | Tutoriais e guias passo a passo |

---

## Decisões registradas

| ADR | Título | Status | Data |
|-----|--------|--------|------|
| [ADR-001](decisions/adr-001-modelo-de-agentes.md) | Modelo de Agentes — Composição CrewAI + LangGraph | Aceita | 2026-08-06 |

---

## Como contribuir

### Novo documento

1. Crie uma branch: `feat/doc-<nome-curto>`
2. Adicione o arquivo na pasta adequada
3. Atualize o índice neste README
4. Abra PR com descrição do que o documento cobre

### Novo ADR

- Numeração sequencial: `adr-NNN-titulo-curto.md`
- Use o template em [decisions/TEMPLATE.md](decisions/TEMPLATE.md)
- Campos obrigatórios: Status, Data, Contexto, Decisão, Consequências

### Convenções

- Idioma: português brasileiro
- Nomes de arquivo: `kebab-case`
- Diagramas: ASCII ou Mermaid (GitHub renderiza nativamente)
- Todo documento tem data e versão no header

---

## Repositórios relacionados

| Repo | Propósito |
|------|-----------|
| [`platform-core`](https://github.com/<org>/platform-core) | Motor de execução |
| [`agent-sdk`](https://github.com/<org>/agent-sdk) | SDK e template de agentes |
| [`google-calendar-agent`](https://github.com/<org>/google-calendar-agent) | Agente: Google Calendar |
| [`youtube-publisher-agent`](https://github.com/<org>/youtube-publisher-agent) | Agente: YouTube Publisher |

---

## Licença

Este projeto é licenciado sob a **PolyForm Noncommercial License 1.0.0**.

- ✅ Livre para uso educacional, pessoal e de pesquisa
- ❌ Uso comercial requer licença paga — entre em contato