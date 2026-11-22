## Why

O receiptsio precisa de um catálogo relacional de modelos de comprovante (templates estrutural e variável, campos, indexadores) que sirva de fonte da verdade para o cache e para o comprovante transacional gravado no NoSQL. Hoje `infra/local/postgres` é uma cópia de outro projeto (tabela `autorizacoes`, expurgo, pg_cron): não sobe limpo (ordem alfabética `v1.0.10` < `v1.0.2`, migration que exige `psql -v`) e compartilha nomes globais de Docker (volume `postgres_pg_data`, container `postgres18-kiq`) que podem reaproveitar silenciosamente o banco do outro projeto.

## What Changes

- **BREAKING** (apenas local): remove as migrations, massa sintética e exemplos do domínio `autorizacoes` de `infra/local/postgres`; a nova linha de migrations começa em `v1.0.00`.
- Renomeia identificadores globais do Docker para o projeto: container `postgres18-receiptsio`, volume `receiptsio_pg_data`, rede `receiptsio_postgres`, banco `db-receiptsio` (em `.env.example`).
- Mantém o `dockerfile` (PostgreSQL 18 + `pg_cron`, `pg_partman`, `pgvector`) e o `shared_preload_libraries` existentes.
- Cria o schema do catálogo conforme `docs/modelagem-dados-para-modelo-de-comprovante.txt`, com as melhorias decididas na exploração:
  - `modelo` com PK composta `(id_modelo, versao)`, versão publicada imutável e no máximo uma versão `ATIVO` por `id_modelo`.
  - FKs de `modelo` para os templates corrigidas para `UUID NOT NULL` (o documento base as tipava como numéricas).
  - Indexadores deixam de ser colunas `indexador_1..5` em texto no template estrutural e passam a ser `posicao_indexador` (1..5) na associação template–campo; posição 1 obrigatória; indexador nunca aceita nulo/vazio.
  - Ordem de exibição dos campos (`ordem`) nas duas associações.
  - `timestamptz` com fuso padrão do banco `America/Sao_Paulo`; `data_hora_atualizacao` mantida por trigger.
  - PKs UUIDv7 geradas por `uuidv7()` nativo do PG 18; `campo` com identidade `BIGINT`.
  - Domínio fechado para `tipo_dado` e unicidade de campo por `(lower(nome_campo), tipo_dado)`.
  - Lock otimista (`version`) em modelo e templates.
- Roles de privilégio mínimo (leitura para o carregador de cache; escrita para administração do catálogo) sem depender de variável `psql -v` na inicialização.
- Seed de exemplo e consulta "modelo completo" (o que o cache carrega) em `exemplos-queries.sql`.
- Script de verificação SQL que prova cada regra do catálogo contra o banco real.
- README reescrito para o domínio de comprovantes, preservando a receita de extensões.

## Capabilities

### New Capabilities
- `catalogo-modelos-comprovante`: regras de dados do catálogo relacional — campos, templates estrutural/variável e suas associações, indexadores, modelo versionado e imutável, situação vigente.
- `postgres-local`: ambiente PostgreSQL 18 local em Docker — subida limpa com migrations ordenadas, isolamento de nomes do projeto, extensões, roles e verificação.

### Modified Capabilities
<!-- Nenhuma: openspec/specs/ está vazio neste repositório. -->

## Impact

- `infra/local/postgres/`: `postgres-db-v18.yml`, `migrations/` (substituídas), `exemplos-queries.sql`, `gerar-massa-sintetica-*.sql` (removidos), `info_pra_run_v18.txt`, `README.md`; novo script de verificação.
- `.env.example`: `DB_NAME` passa a `db-receiptsio`.
- Volume local antigo `postgres_pg_data` deixa de ser usado por este projeto (não é apagado).
- Sem código Java nesta change; aplicações futuras consomem o schema via role de leitura.

## Fora de escopo

- Banco NoSQL do comprovante transacional e camada de cache (Redis/Valkey) — apenas o contrato de referência `(id_modelo, versao)` é fixado aqui.
- API/aplicação de administração do catálogo.
- Ferramenta de migration versionada (Flyway/Liquibase); segue o padrão atual de `docker-entrypoint-initdb.d`.
- Infra de nuvem (RDS etc.).
