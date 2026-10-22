# README

> ## ⚠️ TEMPORÁRIO — REMOVER ASSIM QUE POSSÍVEL: bypass de review na `main`
>
> Em **2026-06-22** o ruleset `protect-main` recebeu um **bypass para o papel
> "Repository admin"** (`bypass_mode: always`). Motivo: o time tem apenas 2 admins e o
> GitHub não permite aprovar o próprio PR, o que impedia o merge do release `dev → main`
> (regra exige 1 aprovação humana).
>
> **Isto enfraquece a proteção de produção.** Remover o bypass assim que houver um
> revisor disponível (terceiro colaborador ou aprovação do outro admin):
> `Settings → Rules → Rulesets → protect-main → Bypass list → remover "Repository admin"`
> (ou `gh api --method PUT repos/VictorDG00/Tamois-Ia-Juridica/rulesets/17850257` com `"bypass_actors": []`).

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
