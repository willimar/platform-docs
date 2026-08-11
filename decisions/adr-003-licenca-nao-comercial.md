# ADR-003: Licença não-comercial (PolyForm Noncommercial)

| Campo         | Valor              |
|---------------|--------------------|
| **Status**    | Aceita             |
| **Data**      | 2026-08-12         |
| **Autor**     | [seu nome]         |
| **Repositório** | `platform-docs`  |

---

## 1. Contexto

O projeto tem propósito educacional. O autor deseja que terceiros
possam estudar e aprender com o código, mas **não** que oportunistas
o utilizem comercialmente sem compensação ao autor.

Licenças open source tradicionais (MIT, GPL, LGPL, AGPL) permitem
uso comercial por definição — a OSI exige não-discriminação de
campos de atuação. Portanto, nenhuma delas atende ao objetivo.

---

## 2. Decisão

Adotar **PolyForm Noncommercial License 1.0.0** para todo o código:

- `agent-sdk`
- `platform-core`
- `google-calendar-agent`
- `agent-platform` (orquestrador)

Adotar **CC BY-NC 4.0** para a documentação (`platform-docs`).

Modelo de negócio futuro: **licenciamento duplo** — uso não-comercial
gratuito sob PolyForm; uso comercial mediante licença paga negociada
com o autor.

---

## 3. Alternativas consideradas

| Alternativa | Veredito | Motivo |
|-------------|----------|--------|
| MIT | ❌ | Permite uso comercial sem restrições |
| GPL/AGPL | ❌ | Permitem vender o software; "livre" inclui lucro |
| LGPL | ❌ | Idem, e ainda permite link com software proprietário |
| CC BY-NC em código | ❌ | A própria Creative Commons desaconselha CC para software |
| Licença caseira | ❌ | Risco de brechas jurídicas por texto não revisado |
| BUSL / SSPL | ❌ | Focadas em competição SaaS, não em uso educacional |
| **PolyForm Noncommercial** | ✅ | Padrão escrito por advogados, curto, claro, foco em "não-comercial" |

---

## 4. Consequências

### Positivas

- Uso educacional/pessoal/pesquisa explicitamente liberado
- Uso comercial exige licença paga — base legal pra cobrar
- Texto padronizado e testado (menos risco jurídico)
- Coerente com o propósito declarado do projeto

### Negativas / riscos aceitos

- Não é licença OSI-approved: não pode ser chamado de "open source"
- Comunidade potencial menor (empresas evitam licenças NC)
- Fiscalização é responsabilidade do autor (a licença dá base legal,
  mas não impede cópia por si só)
- Definição de "não-comercial" tem zona cinzenta em casos limítrofes

---

## 5. Referências

- [PolyForm Noncommercial 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0/)
- [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/)
- [OSI Definition](https://opensource.org/osd)