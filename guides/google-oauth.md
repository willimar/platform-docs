# Guia: OAuth 2.0 do Google para o google-calendar-agent

Passo a passo completo para configurar as credenciais que o agente usa
para consultar a Google Calendar API. Tempo estimado: 10 minutos.

---

## 1. Pré-requisitos

- Conta Google (Gmail)
- Projeto no Google Cloud Console
- `google-calendar-agent` com a pasta `credentials/` (protegida por `.gitignore`)

---

## 2. Configuração no Google Cloud Console

### 2.1 Criar o projeto

1. Acesse [console.cloud.google.com](https://console.cloud.google.com)
2. **New Project** → nome: `agent-platform` → Create
3. Confirme no seletor de projetos (topo da página) que `agent-platform`
   está ativo

### 2.2 Habilitar a API

1. **APIs & Services → Library**
2. Busque **Google Calendar API**
3. **Enable**

### 2.3 Configurar a tela de consentimento OAuth

1. **APIs & Services → OAuth consent screen**
   *(layout novo: Google Auth platform → Audience)*
2. User Type: **External** → Create
3. Preencha:
   - App name: `Agent Platform`
   - User support e-mail: o seu
   - Developer contact: o seu
4. **Test users** → Add users → **adicione o seu e-mail Gmail** → Save

> **CRÍTICO:** sem o seu e-mail em Test users, a autorização falha com
> `Erro 403: access_denied` enquanto o app está em modo Testing.

### 2.4 Criar o OAuth Client ID

1. **APIs & Services → Credentials**
2. **Create Credentials → OAuth client ID**
3. Application type: **Desktop app**
4. Baixe o JSON gerado

### 2.5 Posicionar o arquivo

Salve o JSON baixado como:

```
google-calendar-agent/
└── credentials/
    └── google_credentials.json
```

Override por variável de ambiente (opcional):

```powershell
$env:GOOGLE_CREDENTIALS_PATH = "C:\caminho\google_credentials.json"
```

---

## 3. Primeira autorização

```powershell
cd F:\agent-platform
uv run platform run google-calendar-agent/agent.yaml --verbose
```

1. O navegador abre na tela de login do Google
2. Como o app não é verificado, aparece o aviso
   **"O Google não verificou este app"** — é esperado:
   - Clique em **Configurações avançadas**
   - Clique em **Ir para Agent Platform (não seguro)**
   - Clique em **Permitir**
3. O arquivo `credentials/token.json` é criado
4. Execuções seguintes não pedem mais nada (refresh automático)

---

## 4. Limitações do modo Testing (importante!)

Enquanto o app está com publishing status **Testing**:

| Limitação | Impacto |
|-----------|---------|
| Máximo de 100 test users | Irrelevante para uso pessoal |
| **Refresh tokens expiram em 7 dias** | Após 1 semana, o agente falha com `invalid_grant` |

### Como evitar a expiração de 7 dias

Para uso pessoal contínuo, mude o publishing status para
**In production**:

1. **OAuth consent screen → Publishing status → Back to production**
2. Confirme

O aviso de "app não verificado" continua aparecendo na autorização
(normal para app pessoal), mas os refresh tokens **não expiram mais
em 7 dias**. Não faça isso se pretende distribuir o agente para
terceiros — nesse caso, o Google exige verificação oficial.

---

## 5. Troubleshooting

| Sintoma | Causa | Solução |
|---------|-------|---------|
| `403: access_denied` na tela do Google | E-mail fora dos Test users | Adicione em OAuth consent screen → Test users |
| `RefreshError` / `invalid_grant` | Token expirado (7 dias, modo Testing) | Delete `credentials/token.json` e reautorize |
| Navegador não abre | Terminal sem GUI / SSH | Copie a URL impressa no terminal para outro navegador |
| `client secrets não encontrado` | JSON fora do caminho esperado | Confira `credentials/google_credentials.json` ou a env var |
| Autorizou com conta errada | Múltiplas contas Google | Delete `token.json` e autorize com a conta certa |
| Erro de projeto errado | Client ID criado em outro projeto | Confira o seletor de projetos no topo do Console |

---

## 6. Segurança

- `credentials/` está no `.gitignore` — **nunca** commite
  `google_credentials.json` nem `token.json`
- O escopo solicitado é **somente leitura**
  (`calendar.readonly`) — decisão registrada no
  [ADR-002](../decisions/adr-002-escopo-somente-leitura.md)
- Se um token vazar: revogue em
  [myaccount.google.com/permissions](https://myaccount.google.com/permissions)

---

## 7. Referências

- [Google Calendar API — Python Quickstart](https://developers.google.com/calendar/api/quickstart/python)
- [OAuth 2.0 for Desktop Apps](https://developers.google.com/identity/protocols/oauth2/native-app)
- [ADR-002 — Escopo somente leitura](../decisions/adr-002-escopo-somente-leitura.md)