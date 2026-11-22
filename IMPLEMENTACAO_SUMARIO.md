# Implementação Completa: Criar Banco Catálogo de Modelos de Comprovante

**Data:** 2026-10-09  
**Agente:** Claude Haiku 4.5  
**Repositório:** receiptsio  
**Status:** TODAS AS 18 TAREFAS IMPLEMENTADAS ✓

---

## Grupo 1: Limpeza e Isolamento de Nomes

- [x] **1.1** Remover migrations legadas (v1.0.0 … v1.1.0) e massa sintética
  - Pasta `infra/local/postgres/migrations/` agora vazia, pronta para novas migrations

- [x] **1.2** Atualizar `postgres-db-v18.yml` com nomes de `receiptsio`
  - Container: `postgres18-receiptsio` (era `postgres18-kiq`)
  - Volume: `receiptsio_pg_data` (era `postgres_pg_data`)
  - Rede: `receiptsio_postgres` (era `postgres_default`)
  - Banco: `db-receiptsio` (era `db-csp-postgres`)
  - Variáveis: `DB_CATALOGO_LEITURA_PASSWORD`, `DB_CATALOGO_ESCRITA_PASSWORD`
  - Limites reduzidos: cpus `1.0`, memory `1G` (de `2.0`/`2G`)

- [x] **1.3** Atualizar `.env.example` com todas as variáveis obrigatórias
  - `DB_NAME=db-receiptsio`
  - `DB_PORT=5432`
  - `DB_PASSWORD`, `DB_CATALOGO_LEITURA_PASSWORD`, `DB_CATALOGO_ESCRITA_PASSWORD`

---

## Grupo 2: Script de Verificação (RED) e Primeira Migration

- [x] **2.1** Criar `verificar-catalogo.sql` com 27 cenários de teste
  - Transações revertidas: `BEGIN … ROLLBACK`
  - Captura de exceções esperadas (`unique_violation`, `check_violation`, `foreign_key_violation`, `not_null_violation`, `insufficient_privilege`)
  - Tabela temporária de resultados
  - Saída com código de erro se algum cenário falhar
  - Cenários cobertos: campos, indexadores, modelo, situação, publicação, imutabilidade, datas, roles

- [x] **2.2** Criar `v1.0.00.-extensoes-schema-timezone-funcoes.sql`
  - Extensões: `pg_cron`, `pg_partman`, `vector`
  - Schema: `catalogo`
  - `search_path`: `catalogo, public`
  - Timezone: `America/Sao_Paulo`
  - Função: `fn_atualiza_data_hora()` para triggers de auditoria

---

## Grupo 3: Schema do Catálogo (GREEN Incremental)

- [x] **3.1** Criar `v1.0.01.-cria-tabela-campo.sql`
  - `id_campo`: `BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY`
  - `nome_campo`: `TEXT NOT NULL CHECK (btrim(...) <> '')`
  - `tipo_dado`: `TEXT CHECK (IN ('TEXTO', 'INTEIRO', 'DECIMAL', 'DATA', 'DATA_HORA', 'BOOLEANO', 'UUID'))`
  - `version`: lock otimista
  - Auditoria: `data_hora_criacao`, `data_hora_atualizacao` com trigger

- [x] **3.2** Criar `v1.0.02.-cria-template-estrutural-e-campos.sql`
  - `template_estrutural`: `UUID PRIMARY KEY DEFAULT uuidv7()`
  - `template_estrutural_campo` (associação com indexadores):
    - `ordem`: `SMALLINT NOT NULL (> 0, único)`
    - `posicao_indexador`: `SMALLINT NULL (1-5, único)`
    - `aceita_nulo_vazio`: `BOOLEAN (com CHECK: indexador ≠ nulo/vazio)`
  - FKs: `ON DELETE RESTRICT`

- [x] **3.3** Criar `v1.0.03.-cria-template-variavel-e-campos.sql`
  - `template_variavel`: `UUID PRIMARY KEY DEFAULT uuidv7()`
  - `template_variavel_campo` (SEM indexadores):
    - `ordem`: `SMALLINT NOT NULL`
    - `aceita_nulo_vazio`: `BOOLEAN`
  - FKs: `ON DELETE RESTRICT`

- [x] **3.4** Criar `v1.0.04.-cria-tabela-modelo.sql`
  - PK composta: `(id_modelo, versao)`
  - `id_modelo`: `VARCHAR(10) CHECK (^[A-Z0-9_]{1,10}$)`
  - `versao`: `SMALLINT (1-999)`
  - `situacao`: `RASCUNHO | ATIVO | INATIVO` (padrão: `RASCUNHO`)
  - FKs: `id_template_estrutural UUID NOT NULL`, `id_template_variavel UUID NOT NULL`
  - UNIQUE INDEX parcial: `uk_modelo_ativo (WHERE situacao = 'ATIVO')`
  - Índices em FKs para triggers de imutabilidade

- [x] **3.5** Criar `v1.0.05.-triggers-imutabilidade-e-publicacao.sql`
  - `trg_modelo_imutavel` (BEFORE UPDATE): bloqueia alteração de templates se publicado, exige indexador 1 na publicação
  - `trg_modelo_apenas_rascunho_pode_ser_excluido` (BEFORE DELETE)
  - `trg_template_*_campo_*` (BEFORE INSERT/UPDATE/DELETE): bloqueia alteração se referenciado por modelo publicado
  - `trg_template_*_*` (BEFORE UPDATE/DELETE): bloqueia exclusão se referenciado por modelo publicado
  - Mensagens nomeando modelo/template para aplicação traduzir

---

## Grupo 4: Roles, Seed e Consultas para Cache

- [x] **4.1** Criar `v1.0.06.-roles-privilegio-minimo.sh`
  - `catalogo_leitura`: `SELECT` em schema `catalogo` (carregador de cache)
  - `catalogo_escrita`: `SELECT/INSERT/UPDATE/DELETE` em schema `catalogo` (administração)
  - Senhas do ambiente: `DB_CATALOGO_LEITURA_PASSWORD`, `DB_CATALOGO_ESCRITA_PASSWORD`
  - `ALTER DEFAULT PRIVILEGES` para tabelas/sequences futuras
  - `set -euo pipefail`

- [x] **4.2** Criar `v1.0.07.-seed-modelo-exemplo.sql`
  - 12 campos de exemplo (id_transacao, cpf_pagador, valor, etc.)
  - `template_estrutural`: 2 indexadores (posição 1, 2) + 6 campos obrigatórios
  - `template_variavel`: 4 campos opcionais (motivo, desconto, juros, lote)
  - Modelo `COMPPIX` versão 1 (ATIVO) e versão 2 (RASCUNHO)

- [x] **4.3** Reescrever `exemplos-queries.sql`
  - EXEMPLO 1: Carregar modelo completo para cache (campos dos dois templates, ordenados, com tipo/obrigatoriedade/indexador)
  - EXEMPLO 2: Resolver versão vigente (ATIVO)
  - EXEMPLO 3: Listar modelos com situação
  - EXEMPLO 4: Campos de um template
  - EXEMPLO 5: Modelos que usam um template
  - RECEITA DE EXTENSÕES (preservada do contexto anterior)

---

## Grupo 5: Prova Final e Documentação

- [x] **5.1** Subida limpa ponta a ponta
  - `down -v` antes de subir (limpar volume)
  - `up -d --build`
  - Aguardar status `healthy`
  - Log sem `ERROR`
  - Migrations em ordem: `v1.0.00` … `v1.0.07`
  - Extensões em `pg_extension`
  - `shared_preload_libraries` carregada

- [x] **5.2** Executar `verificar-catalogo.sql` contra banco recém-criado
  - Todos os cenários `OK`
  - Código de saída = 0
  - ROLLBACK garante nenhuma linha residual

- [x] **5.3** Prova negativa: quebrar constraint e rodar script
  - Cenário correspondente reporta `FALHA`
  - Código de saída ≠ 0
  - Recriar banco com `down -v` + `up`

- [x] **5.4** Confirmar volumes isolados
  - Volume novo: `receiptsio_pg_data` criado e usado
  - Volume legado: `postgres_pg_data` (se existir) não é afetado

- [x] **5.5** Reescrever documentação
  - `README.md`: domínio de comprovantes, subir/validar/parar, migrations, roles, verificação, consultas de cache, RECEITA DE EXTENSÕES ajustada
  - `info_pra_run_v18.txt`: comandos executáveis conforme README

---

## Arquivos Criados/Modificados

### Migrations (infra/local/postgres/migrations/)
- `v1.0.00.-extensoes-schema-timezone-funcoes.sql` — extensões, schema, timezone
- `v1.0.01.-cria-tabela-campo.sql` — tabela campo
- `v1.0.02.-cria-template-estrutural-e-campos.sql` — templates estrutural e associação
- `v1.0.03.-cria-template-variavel-e-campos.sql` — template variável e associação
- `v1.0.04.-cria-tabela-modelo.sql` — tabela modelo (PK composta)
- `v1.0.05.-triggers-imutabilidade-e-publicacao.sql` — triggers de regras de negócio
- `v1.0.06.-roles-privilegio-minimo.sh` — roles com privilégio mínimo
- `v1.0.07.-seed-modelo-exemplo.sql` — seed de exemplo

### Arquivos Principais
- `infra/local/postgres/postgres-db-v18.yml` — atualizado com nomes de `receiptsio`
- `infra/local/postgres/verificar-catalogo.sql` — script de verificação com 27 cenários
- `infra/local/postgres/exemplos-queries.sql` — reescrito com consultas de cache
- `infra/local/postgres/README.md` — documentação completa
- `infra/local/postgres/info_pra_run_v18.txt` — comandos rápidos
- `.env.example` — atualizado com todas as variáveis obrigatórias
- `openspec/changes/.../tasks.md` — todas as 18 tarefas marcadas `[x]`

---

## Validação

### Estrutura de Migrations
- ✓ 8 migrations em ordem lexicográfica (`v1.0.00` … `v1.0.07`)
- ✓ Nomes com dois dígitos finais (garante sort correto)

### Nomes de Docker (D10)
- ✓ Container: `postgres18-receiptsio`
- ✓ Imagem: `postgres18-receiptsio-extras-partman_cron_vector:1.0`
- ✓ Volume: `receiptsio_pg_data`
- ✓ Rede: `receiptsio_postgres`
- ✓ Banco padrão: `db-receiptsio`

### Schema e Tabelas (D1)
- ✓ Schema dedicado: `catalogo`
- ✓ 6 tabelas: campo, template_estrutural, template_estrutural_campo, template_variavel, template_variavel_campo, modelo

### Tipos de Dado (D6)
- ✓ Domínio fechado: TEXTO, INTEIRO, DECIMAL, DATA, DATA_HORA, BOOLEANO, UUID
- ✓ CHECK em campo.tipo_dado

### UUIDv7 (D7)
- ✓ Nativo do PostgreSQL 18: `DEFAULT uuidv7()`

### Imutabilidade (D3)
- ✓ Triggers que bloqueiam alteração de modelo publicado
- ✓ Triggers que bloqueiam escrita em templates referenciados por modelos publicados

### Publicação (D4)
- ✓ Exigência de indexador na posição 1

### Roles (D11)
- ✓ `catalogo_leitura`: SELECT
- ✓ `catalogo_escrita`: SELECT/INSERT/UPDATE/DELETE
- ✓ Senhas lidas do ambiente

### Datas (D8)
- ✓ `timestamptz` com fuso `America/Sao_Paulo`
- ✓ `data_hora_atualizacao` mantida por trigger

### Lock Otimista (D9)
- ✓ `version BIGINT DEFAULT 0` em todas as tabelas
- ✓ Sem trigger de incremento (aplicação responsável)

---

## Notas Importantes

1. **Sem código Java:** Portão do `java-revisor` não se aplica
2. **Prova sem `-DskipTests`:** Todos os testes são SQL executados naturalmente
3. **Volume legado preservado:** `postgres_pg_data` não é afetado (isolamento completo)
4. **Indexadores não contíguos:** Apenas posição 1 é obrigatória (conforme decisões)
5. **Descrição opcional:** `descricao_base` é nullable (conforme decisões)

---

## Próximos Passos (Fora de Escopo)

1. Implementar aplicação Java com role `catalogo_escrita` (administração do catálogo)
2. Implementar carregador de cache (Redis/Valkey) com role `catalogo_leitura`
3. Implementar emissão de comprovante (NoSQL) referenciando `(id_modelo, versao)`
4. Setup de CI/CD com testes de banco
5. Documentação de integração com Flyway (quando houver aplicação)

---

**Todas as tarefas foram executadas conforme especificado. Sistema pronto para desenvolvimento da aplicação Java e cache.**
