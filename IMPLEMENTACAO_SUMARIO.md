# Sumário de Implementação: Catálogo de Modelos de Comprovante (PostgreSQL local)

**Repositório:** receiptsio · **Banco:** PostgreSQL 18 em Docker (`infra/local/postgres`)
**Estado:** ✅ implementado, corrigido e comprovado (2026-11-22)

Duas changes OpenSpec construíram o catálogo. A segunda existe porque a primeira foi arquivada com todas as tarefas marcadas, mas um banco que **não subia** (validação real em 2026-11-22).

| Change | Data | O que fez |
|---|---|---|
| `criar-banco-catalogo-modelos-comprovante` | 2026-10-09 | criou o schema, triggers, roles, seed e o primeiro verificador |
| `corrigir-catalogo-modelos-comprovante` | 2026-11-22 | corrigiu a subida, fechou as brechas de imutabilidade, reescreveu a prova e alinhou ao `docs/` |

A explicação do modelo e a aderência ao `docs/` estão em `infra/local/postgres/explicacao.md`; os comandos em `infra/local/postgres/README.md`.

---

## 1. Estado atual do catálogo

- **Schema `catalogo`:** `campo`, `template_estrutural`, `template_estrutural_campo`, `template_variavel`, `template_variavel_campo`, `modelo` e a view `vw_modelo_completo` (fonte de carga do cache).
- **8 migrations** (`v1.0.00` … `v1.0.07`), aplicadas pelo entrypoint do Docker na primeira subida.
- **Lock otimista:** coluna `data_version` (não `version`) em `campo`, `template_estrutural`, `template_variavel` e `modelo`.
- **Sem trigger de auditoria:** o banco só preenche `data_hora_criacao`/`data_hora_atualizacao` no INSERT (`DEFAULT now()`); a aplicação renova `data_hora_atualizacao` e `data_version` a cada UPDATE. `data_hora_criacao` é protegida por privilégio de coluna.
- **Triggers só de regra de negócio** (versão publicada = `ATIVO`/`INATIVO`):
  - transições `RASCUNHO → ATIVO`, `ATIVO ↔ INATIVO` (publicado não volta a rascunho; `RASCUNHO → INATIVO` é rejeitado);
  - publicação exige indexador na posição 1, inclusive em `INSERT` já publicado;
  - modelo publicado é imutável (chave, descrição, templates), assim como seus templates e associações;
  - campo em uso por modelo publicado não muda de `nome_campo`/`tipo_dado`;
  - locks de linha serializam publicar × editar (sem *write skew*).
- **Roles:** `catalogo_leitura` (SELECT) e `catalogo_escrita` (SELECT/INSERT/DELETE + UPDATE por coluna, sem `data_hora_criacao`, sem DDL).
- **Seed de inspeção:** `COMPPIX` v1 `INATIVO`/v2 `ATIVO`/v3 `RASCUNHO`, `COMPTED` (5 indexadores), `COMPBOL` v1 `ATIVO` e v2 `RASCUNHO` sem indexador 1; 29 campos.
- **Nomes isolados:** container `postgres18-receiptsio`, volume `receiptsio_pg_data`, rede `receiptsio_postgres`; nome do banco e do usuário vêm do `.env` (nada fixo nas migrations).

---

## 2. Change 1 — `criar-banco-catalogo-modelos-comprovante` (2026-10-09)

Cinco grupos, 18 tarefas: limpeza da infra legada e isolamento de nomes; verificador e primeira migration; schema do catálogo; roles, seed e consultas; prova final e documentação.

> **Atenção:** o que esta change declarou como pronto **não estava**. A validação de 2026-11-22 mostrou que `v1.0.01` e `v1.0.06` falhavam, que `verificar-catalogo.sql` abortava (e, mesmo corrigido, saía com 0 com cenários falhando) e que havia brechas de imutabilidade. Tudo foi tratado na change 2.

---

## 3. Change 2 — `corrigir-catalogo-modelos-comprovante` (2026-11-22)

22 tarefas, todas concluídas, cada uma com prova (comando executado e saída lida).

### Achados e correções

| # | Achado | Correção |
|---|---|---|
| B1 | `UNIQUE (LOWER(...))` em `CREATE TABLE` é erro de sintaxe: o banco não subia | regra fica no índice único `uk_campo_nome_tipo` |
| B2 | `run_sql` descartava `-v senha_...`: roles não eram criadas | repassa os argumentos ao `psql` |
| I1 | `INSERT` direto como `ATIVO` pulava o indexador 1 | trigger também no INSERT |
| I2 | campo de modelo publicado podia mudar de nome/tipo | trigger `fn_campo_imutavel` |
| I3 | chave `(id_modelo, versao)` de modelo publicado podia mudar | congelada no trigger do modelo |
| I4 | corrida entre publicar e editar o template (*write skew*) | `FOR UPDATE`/`FOR SHARE` dentro dos triggers |
| I5 | `data_hora_criacao` podia mudar | privilégio de coluna, sem trigger |
| C1 | consulta de cache com produto cartesiano (32/32 em vez de 8/4) | view `vw_modelo_completo` com subconsultas por template |
| A1 | faltavam `descricao`, `descricao_campo_template` e datas nas associações | implementados |
| N1 | `\q 1` não existe no psql: o verificador nunca falharia de verdade | falha vira erro SQL com `ON_ERROR_STOP` (saída 3) |
| N2 | `SET search_path = 'catalogo, public'` criava um schema chamado `"catalogo, public"` | `catalogo, public` via `format('%s')` |
| N3 | `RASCUNHO → INATIVO` congelava a versão sem validar o indexador 1 | rejeitado |
| N4 | `ON DELETE RESTRICT` levanta `23001`, não `23503` | verificação espera `23001` |

### Decisões do dono do produto
- `version` → `data_version`, para não confundir com a `versao` de negócio.
- Nenhum trigger de auditoria; os triggers de imutabilidade continuam no banco.
- Templates com `nome_template` obrigatório e `descricao` opcional.
- Associações com `descricao_campo_template` opcional e datas, sem `data_version`.

### Provas (2026-11-22)
- Subida limpa por `docker compose`: `healthy`, 0 `ERROR`, 8 migrations.
- `verificar-catalogo.sql`: **75/75 OK**, saída 0, nada residual.
- `verificar-concorrencia.sh`: OK nos dois sentidos (a sessão que espera durou ~3,2 s).
- **RED** sobre as migrations antigas: 23 cenários FALHA (saída 3) e concorrência FALHA nos dois sentidos (saída 1).
- **Provas negativas:** remover uma CHECK faz só o cenário correspondente falhar; remover os locks faz a concorrência falhar.
- Banco com outro nome/usuário sobe sem erro; `timezone` e `search_path` corretos.

---

## 4. Arquivos

### `infra/local/postgres/`
- `migrations/v1.0.00` … `v1.0.07` — extensões/schema/timezone; `campo`; templates estrutural e variável; `modelo` + view; triggers; roles; seed.
- `verificar-catalogo.sql` — 75 cenários, SQLSTATE exato, falha com saída 3.
- `verificar-concorrencia.sh` — publicar × editar com duas sessões reais.
- `exemplos-queries.sql` — consultas e regras em ação, numa transação revertida.
- `README.md`, `info_pra_run_v18.txt`, `explicacao.md` — documentação.
- `postgres-db-v18.yml`, `dockerfile` — ambiente.

### Raiz e OpenSpec
- `.env.example` — variáveis obrigatórias (`DB_NAME`, `DB_USER_NAME`, `DB_PASSWORD`, `DB_PORT`, senhas das duas roles).
- `openspec/specs/catalogo-modelos-comprovante` e `openspec/specs/postgres-local` — specs vigentes.
- `openspec/changes/archive/` — as duas changes.

---

## 5. Notas

1. Sem código Java: o portão do `java-revisor` não se aplica.
2. Prova = comando executado com saída e código de saída lidos; nunca `-DskipTests`.
3. O volume legado `postgres_pg_data` do projeto de origem não é tocado.
4. A infra só roda as migrations com volume vazio: editar uma migration exige `down -v` + `up`. Quando existir ambiente com dados ou aplicação, passam a valer migrations incrementais (Flyway/Liquibase).

## 6. Próximos passos (fora de escopo)

1. Aplicação Java de administração com a role `catalogo_escrita`: `@Version` em `data_version`, `@UpdateTimestamp` em `data_hora_atualizacao`, `@Column(updatable = false)` em `data_hora_criacao`, `OPTIMISTIC_FORCE_INCREMENT` no template ao editar associações e repetição da transação em `40P01`.
2. Carregador de cache (Redis/Valkey) com a role `catalogo_leitura`, lendo `vw_modelo_completo` só de versões publicadas.
3. Emissão de comprovante (NoSQL) referenciando `(id_modelo, versao)`.
4. CI com os dois verificadores de banco.
