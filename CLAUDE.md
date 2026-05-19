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

```bash
bundle exec rails test          # todos os 58 testes
bundle exec rails test test/models/
bundle exec rails test test/services/
bundle exec rails test test/controllers/
```

---

## Contrato da API DeepSeek (análise)

```json
{
  "orthography": [{"original":"...","suggestion":"...","reason":"..."}],
  "writing_suggestions": [{"excerpt":"...","suggestion":"...","reason":"..."}],
  "legal_insights": [{"topic":"...","insight":"...","risk_level":"low|medium|high","paragraph_id":INT}]
}
```

Limites: máx 8 itens por seção · 400 chars por campo · disclaimer automático nos insights.

---

## Fluxo de Análise

1. Usuário faz upload de `.docx` em `POST /analyses`
2. `AnalysesController#create` salva o arquivo via Active Storage
3. `AnalysisService#run` chama `DocxExtractor` → extrai texto parágrafo a parágrafo
4. Texto enviado para `DeepseekClient#analyze` → DeepSeek API
5. JSON normalizado salvo nas colunas `*_json` do `Analysis`
6. Usuário redirecionado para `analyses#show` com os resultados

## Regras de Commit

A cada 2 alterações significativas, fazer commit para rastreabilidade.

## Design

Design visual baseado no sistema Tamois v2 (arquivo `tamois-v2.css`).
Paleta: Crimson (`#C1121F`) · Parchment (`#FDF0D5`) · Abyss (`#003049`) · Steel (`#669BBC`).
Fontes: Cormorant Garamond (display) · Instrument Sans (body) · DM Mono (mono).
