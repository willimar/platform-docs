# ADR-002: Escopo OAuth somente leitura no google-calendar-agent

| Campo         | Valor              |
|---------------|--------------------|
| **Status**    | Aceita             |
| **Data**      | 2026-08-11         |
| **Autor**     | [seu nome]         |
| **Repositório** | `platform-docs`  |

---

## 1. Contexto

O google-calendar-agent acessa dados pessoais do usuário via
Google Calendar API. O OAuth 2.0 exige declarar **scopes**, que
definem o raio de ação do token concedido. Quanto maior o escopo,
maior o risco em caso de vazamento e maior a fricção de consentimento.

O objetivo do agente na v0.1/v0.2 é **consultar** a agenda
(listar eventos). Não há requisito de produto para criar, editar
ou remover eventos — a criação de eventos foi explicitamente
descartada como fora de escopo.

---

## 2. Decisão

Adotar **exclusivamente** o escopo de leitura:

https://www.googleapis.com/auth/calendar.readonly


- O escopo fica centralizado em `google-calendar-agent/tools/auth.py`
  (constante `SCOPES`), única fonte de verdade.
- Operações de **escrita** (criar/editar/excluir eventos) estão
  **fora de escopo** deste agente, por decisão de produto.
- Se no futuro algum agente precisar de escrita, ele será um
  **agente separado**, com consentimento próprio, escopo próprio
  e um novo ADR justificando.

---

## 3. Alternativas consideradas

| Alternativa | Veredito | Motivo |
|-------------|----------|--------|
| Escopo completo `calendar` | ❌ Rejeitada | Privilégio excessivo; token permitiria destruir a agenda do usuário |
| Escopos por ferramenta | ❌ Rejeitada (v0.1) | Complexidade de múltiplos fluxos OAuth sem benefício atual |
| Service account | ❌ Rejeitada | Não se aplica a dados de usuário pessoal (calendários não são compartilháveis com service accounts) |
| `calendar.readonly` | ✅ Adotada | Menor privilégio compatível com o objetivo |

---

## 4. Consequências

### Positivas

- **Menor privilégio:** um token vazado permite apenas ler a agenda,
  nunca alterá-la.
- **Consentimento mais simples:** o usuário autoriza "ver eventos",
  o que é intuitivo e gera confiança.
- **Agente previsível:** o LLM não tem capacidade de agir sobre a
  agenda — elimina toda uma classe de acidentes (eventos criados
  por alucinação, loops de escrita, etc.).
- **Alinha com o tool-contract:** ferramentas de leitura são
  idempotentes e seguras para retry automático.

### Negativas / riscos aceitos

- O agente não pode criar eventos, mesmo quando seria conveniente.
  Aceito: não é requisito.
- Um futuro agente de escrita exigirá novo fluxo OAuth e
  re-autorização do usuário. Aceito: será tratado em ADR próprio.

---

## 5. Referências

- [Google Calendar API — Authorization scopes](https://developers.google.com/calendar/api/authorization)
- [ADR-001 — Modelo de agentes](adr-001-modelo-de-agentes.md)
- [guides/google-oauth.md](../guides/google-oauth.md)