# platform-docs

Documentação central da Agent Platform. Contém arquitetura,
especificações, decisões de design (ADRs) e guias de uso.

---

## Índice

| Documento | Descrição |
|-----------|-----------|
| [architecture.md](architecture.md) | Visão geral, componentes, fluxo de execução |
| [agent-spec.md](agent-spec.md) | Especificação do formato `agent.yaml` |
| [tool-contract.md](tool-contract.md) | Contrato de ferramentas |
| [guides/google-oauth.md](guides/google-oauth.md) | Setup OAuth do Google (Calendar) |
| [decisions/](decisions/) | ADRs |

## Decisões registradas

| ADR | Título | Status | Data |
|-----|--------|--------|------|
| [ADR-001](decisions/adr-001-modelo-de-agentes.md) | Modelo de Agentes — Composição CrewAI + LangGraph | Aceita | 2026-08-06 |
| [ADR-002](decisions/adr-002-escopo-somente-leitura.md) | Escopo OAuth somente leitura no google-calendar-agent | Aceita | 2026-08-11 |

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

Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0).

- ✅ Compartilhar e adaptar com atribuição
- ❌ Sem uso comercial

Veja [LICENSE](LICENSE) para os termos completos.