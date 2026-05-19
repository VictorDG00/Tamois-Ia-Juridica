# Tamois — IA Jurídica · CLAUDE.md

## Visão Geral

**Tamois** é uma aplicação web Ruby on Rails que recebe arquivos DOCX e realiza revisão jurídica com IA (DeepSeek). Funciona como um revisor de contratos: extrai o texto do DOCX, envia para análise e retorna correções ortográficas, sugestões de redação e insights jurídicos classificados por risco.

**Stack**: Rails 8.1.3 · SQLite · Devise (auth) · Active Storage · DeepSeek API

---

## Estrutura

```
app/
├── controllers/
│   ├── analyses_controller.rb    # Upload + exibição de análises
│   ├── chats_controller.rb       # Chat jurídico por análise
│   ├── dashboard_controller.rb   # Painel do usuário
│   ├── pages_controller.rb       # Landing page
│   └── users/                    # Devise customizado
├── models/
│   ├── user.rb                   # Devise + has_many :analyses
│   ├── analysis.rb               # Análise de documento (DOCX → IA)
│   └── chat_message.rb           # Mensagens do chat jurídico
├── services/
│   ├── docx_extractor.rb         # Extrai texto de DOCX (Zip + Nokogiri)
│   ├── deepseek_client.rb        # Cliente DeepSeek (análise + chat)
│   └── analysis_service.rb       # Orquestra upload → extração → IA
└── views/
    ├── pages/home.html.erb       # Landing (design Tamois v2)
    ├── analyses/                 # Upload (new), resultado (show), histórico (index)
    ├── chats/show.html.erb       # Chat jurídico
    ├── dashboard/index.html.erb  # Painel com KPIs
    └── devise/                   # Auth customizada com design Tamois
```

---

## Variáveis de Ambiente

| Variável | Descrição |
|---|---|
| `DEEPSEEK_API_KEY` | **Obrigatória** — chave da API DeepSeek |
| `SECRET_KEY_BASE` | Gerado com `rails secret` (produção) |

Criar `.env` na raiz do projeto (está no .gitignore):
```
DEEPSEEK_API_KEY=sua_chave_aqui
```

---

## Setup Local

```bash
bundle install
bundle exec rails db:create db:migrate
bundle exec rails server
```

Acesse `http://localhost:3000`.

---

## Testes

**73 testes · 124 assertions** — rodar antes de qualquer commit.

```bash
bundle exec rails test                    # suite completa
bundle exec rails test test/models/
bundle exec rails test test/services/
bundle exec rails test test/controllers/
bundle exec rails test test/jobs/
```

Cobertura atual:

| Arquivo de teste | O que cobre |
|---|---|
| `test/models/user_test.rb` | Validações, associações, contagem de análises |
| `test/models/analysis_test.rb` | Status, JSON parsing, defaults, associações |
| `test/models/chat_message_test.rb` | Roles, validações de conteúdo |
| `test/services/deepseek_client_test.rb` | Normalização, anti-alucinação, parsing JSON |
| `test/services/docx_extractor_test.rb` | Extração de texto, indexação de parágrafos |
| `test/services/docx_annotator_test.rb` | Track Changes, comentários, ZIP válido |
| `test/jobs/analysis_job_test.rb` | Enfileiramento, resiliência a análise inexistente |
| `test/controllers/analyses_controller_test.rb` | Auth, upload, acesso entre usuários |
| `test/controllers/dashboard_controller_test.rb` | Auth, stats |
| `test/controllers/pages_controller_test.rb` | Landing, redirect autenticado |

---

## Contrato da API DeepSeek (análise)

```json
{
  "orthography": [{"original":"...","suggestion":"...","reason":"..."}],
  "writing_suggestions": [{"excerpt":"...","suggestion":"...","reason":"..."}],
  "legal_insights": [{"topic":"...","insight":"...","risk_level":"low|medium|high","paragraph_id":INT}]
}
```

Sem limite de itens por seção · 600 chars por campo · disclaimer automático nos insights · temperatura 0.1.

---

## Fluxo de Análise

1. Upload em `POST /analyses` → salva DOCX via Active Storage, enfileira `AnalysisJob`
2. `AnalysisJob` chama `AnalysisService#run` em background (SolidQueue)
3. `DocxExtractor` abre o DOCX como ZIP, extrai texto indexado por parágrafo
4. `DeepseekClient#analyze_section` — **3 chamadas separadas** ao DeepSeek:
   - `:orthography` → salva `orthography_json` (checkpoint 1 acende na UI)
   - `:writing` → salva `writing_suggestions_json` (checkpoint 2 acende)
   - `:insights` → salva `legal_insights_json`, status → `completed` (checkpoint 3 acende)
5. UI faz meta-refresh a cada 3s enquanto `status != completed`
6. Download via `GET /analyses/:id/download` → `DocxAnnotator` gera DOCX anotado

## Estrutura de serviços

| Serviço | Responsabilidade |
|---|---|
| `DocxExtractor` | Abre DOCX como ZIP, extrai `word/document.xml` com Nokogiri |
| `DeepseekClient` | 3 chamadas focadas, temperatura 0.1, anti-alucinação |
| `AnalysisService` | Orquestra extração → 3 chamadas → saves incrementais |
| `DocxAnnotator` | Gera DOCX com Track Changes (ortografia) e comentários (redação/insights) |

## Regras de Commit e Push

**A cada 2 alterações significativas:**

```bash
bundle exec rails test                    # obrigatório — nenhum commit com testes falhando
git add <arquivos alterados>
git commit -m "tipo: descrição curta"
git push origin main
```

- Rodar a suite completa antes de todo commit — sem exceção
- Push vai direto para `main` (branch único de produção)
- Tipos de commit: `feat`, `fix`, `chore`, `test`, `docs`, `refactor`
- Se os testes falharem após uma mudança: corrigir antes de continuar

**Nunca commitar:**
- Arquivos `.env` (chaves de API)
- `storage/` (uploads dos usuários)
- `tmp/` e `log/`

## Design

Design visual baseado no sistema Tamois v2 (arquivo `tamois-v2.css`).
Paleta: Crimson (`#C1121F`) · Parchment (`#FDF0D5`) · Abyss (`#003049`) · Steel (`#669BBC`).
Fontes: Cormorant Garamond (display) · Instrument Sans (body) · DM Mono (mono).
