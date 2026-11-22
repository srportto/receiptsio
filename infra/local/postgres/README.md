# PostgreSQL 18 Local — Catálogo de Modelos de Comprovante

Ambiente PostgreSQL 18 local em Docker para o catálogo relacional de modelos de comprovante (`receiptsio`).
Inclui extensões (`pg_cron`, `pg_partman`, `vector`), schema dedicado `catalogo`, roles de privilégio mínimo,
triggers de imutabilidade e um seed de inspeção.

Documentos relacionados:
- `explicacao.md` — explicação do modelo, diagramas e aderência ao desenho de `docs/`.
- `exemplos-queries.sql` — consultas e operações de exemplo (rodam numa transação revertida).
- `verificar-catalogo.sql` e `verificar-concorrencia.sh` — a prova executável das regras.

## Variáveis do ambiente

Todas vêm do `.env` da raiz do repositório (modelo: `.env.example`). Os nomes de banco e de usuário **não são fixos**:
use os valores do seu `.env`.

| Variável | Uso |
|---|---|
| `DB_NAME` | nome do banco (padrão `db-receiptsio`) |
| `DB_USER_NAME` | superusuário do container (padrão `docker`) |
| `DB_PASSWORD` | senha do superusuário |
| `DB_PORT` | porta no host (padrão `5432`) |
| `DB_CATALOGO_LEITURA_PASSWORD` | senha da role `catalogo_leitura` |
| `DB_CATALOGO_ESCRITA_PASSWORD` | senha da role `catalogo_escrita` |

Para os comandos abaixo, carregue as variáveis na sua sessão de shell (a partir de `infra/local/postgres`):

```bash
set -a; . ../../../.env; set +a
```

## Subir o ambiente

```bash
cd infra/local/postgres
docker compose --env-file ../../../.env -f postgres-db-v18.yml up -d --build
docker compose --env-file ../../../.env -f postgres-db-v18.yml ps
```

Aguardar status `healthy` (cerca de 10 s). A confirmação:

```bash
docker exec postgres18-receiptsio pg_isready -U "$DB_USER_NAME" -d "$DB_NAME"
# Esperado: accepting connections
docker logs postgres18-receiptsio 2>&1 | grep -c ERROR
# Esperado logo após a subida: 0 (depois, testes manuais de bloqueio também aparecem como ERROR no log)
```

## Validar o catálogo

Duas provas, ambas com código de saída lido (`0` = tudo certo):

```bash
cd infra/local/postgres

# 1) Regras de dados, em transação revertida (nenhum dado fica). Cada cenário confere o SQLSTATE exato.
docker exec -i postgres18-receiptsio psql -v ON_ERROR_STOP=1 -U "$DB_USER_NAME" -d "$DB_NAME" < verificar-catalogo.sql
echo "saída: $?"
# Esperado: "Cenários: 75  OK: 75  FALHA: 0", "VERIFICAÇÃO OK" e saída 0.
# Se algum cenário falhar o script lista o SQLSTATE obtido e termina com código 3.

# 2) Concorrência entre publicar um modelo e editar o template dele (duas sessões psql reais)
./verificar-concorrencia.sh
echo "saída: $?"
# Esperado: "VERIFICAÇÃO DE CONCORRÊNCIA OK" e saída 0 (1 se a corrida passar).
```

`verificar-concorrencia.sh` lê `DB_NAME` e `DB_USER_NAME` do `.env` (ou das variáveis de ambiente) e usa o container
`postgres18-receiptsio` (troque com `CONTAINER=...`). Ele cria dados `CONC_*`, mantém uma transação aberta por 4 s e
confere que a outra sessão ESPERA; os dados são removidos ao final.

## Parar o ambiente

```bash
docker compose --env-file ../../../.env -f postgres-db-v18.yml down
```

Para apagar os dados e recriar tudo (migrations e seed rodam de novo):

```bash
docker compose --env-file ../../../.env -f postgres-db-v18.yml down -v
docker compose --env-file ../../../.env -f postgres-db-v18.yml up -d --build
```

## Conectar ao banco

Superusuário (administração do ambiente e testes):

```bash
docker exec -it postgres18-receiptsio psql -U "$DB_USER_NAME" -d "$DB_NAME"
```

Pelo host (cliente gráfico, DBeaver etc.): `localhost:$DB_PORT`, banco `$DB_NAME`, usuário `$DB_USER_NAME` e a senha de `DB_PASSWORD`.

Como role de leitura (carregador de cache) ou de escrita (aplicação de administração):

```bash
docker exec -it postgres18-receiptsio psql -U catalogo_leitura -d "$DB_NAME"
docker exec -it postgres18-receiptsio psql -U catalogo_escrita -d "$DB_NAME"
```

> Dentro do container (`docker exec`, socket local ou `127.0.0.1`) a imagem oficial usa `trust` e **não pede senha**.
> Pelo host (`localhost:$DB_PORT`) ou por outro container da rede `receiptsio_postgres` a senha é exigida:
> `DB_CATALOGO_LEITURA_PASSWORD` para `catalogo_leitura` e `DB_CATALOGO_ESCRITA_PASSWORD` para `catalogo_escrita`.

## Schema e tabelas

Schema dedicado: `catalogo`.

| Tabela | O que é | Colunas principais |
|---|---|---|
| `campo` | dicionário de campos reutilizáveis | `id_campo` (identity), `nome_campo`, `tipo_dado`, `descricao_base`, `data_version` |
| `template_estrutural` | estrutura obrigatória do comprovante | `id_template_estrutural` (UUIDv7), `nome_template`, `descricao`, `data_version` |
| `template_estrutural_campo` | campos do template estrutural | `ordem`, `posicao_indexador` (1–5 ou nulo), `aceita_nulo_vazio`, `descricao_campo_template` |
| `template_variavel` | campos complementares | `id_template_variavel` (UUIDv7), `nome_template`, `descricao`, `data_version` |
| `template_variavel_campo` | campos do template variável | `ordem`, `aceita_nulo_vazio`, `descricao_campo_template` |
| `modelo` | uma versão de um tipo de comprovante | PK `(id_modelo, versao)`, `descricao`, `situacao`, FKs dos dois templates, `data_version` |
| `vw_modelo_completo` (view) | o que o cache carrega | uma linha por modelo, campos dos dois templates em `jsonb` |

Todas as tabelas têm `data_hora_criacao` e `data_hora_atualizacao` (`timestamptz`).

### `data_version` (lock otimista)

`data_version BIGINT` em `campo`, `template_estrutural`, `template_variavel` e `modelo`. É controle técnico de concorrência,
por isso não se chama `version` (não confundir com `modelo.versao`, dado de negócio). A aplicação incrementa (JPA `@Version`
com `@Column(name = "data_version")`); não há trigger. As tabelas de associação não têm a coluna: o lock fica no template
(a aplicação usa `OPTIMISTIC_FORCE_INCREMENT` ao incluir, alterar ou excluir associações).

### Datas de auditoria: não há trigger

O banco **só preenche as datas no INSERT** (`DEFAULT now()`). **Quem renova `data_hora_atualizacao` em cada UPDATE é a aplicação**
(`@UpdateTimestamp` ou valor explícito). Um UPDATE feito direto no banco (psql) não renova a data. `data_hora_criacao` não pode ser
alterada pela role de escrita (ela não tem UPDATE nessa coluna).

```sql
-- como a aplicação atualiza (exemplo completo em exemplos-queries.sql, seção 7)
UPDATE catalogo.campo
   SET descricao_base = 'nova', data_hora_atualizacao = now(), data_version = data_version + 1
 WHERE id_campo = 1 AND data_version = 0;   -- 0 linhas = conflito de lock otimista
```

## Regras de negócio no banco

**Restrições (constraints)**
- Campo único por `lower(nome_campo)` + `tipo_dado`; `tipo_dado` em domínio fechado (`TEXTO, INTEIRO, DECIMAL, DATA, DATA_HORA, BOOLEANO, UUID`).
- Campo em uso não pode ser excluído (FK `RESTRICT`).
- Um campo aparece no máximo uma vez por template; `ordem` única por template.
- Indexador: posição 1–5, única por template, e **não aceita nulo/vazio**. O template variável não tem indexador.
- Modelo = um template estrutural + um variável (FKs `NOT NULL`); `id_modelo` em `[A-Z0-9_]{1,10}`; `versao` 1–999.
- No máximo uma versão `ATIVO` por `id_modelo` (índice único parcial).

**Triggers (somente de regra de negócio; "publicado" = `ATIVO` ou `INATIVO`)**
1. **Transições de situação:** `RASCUNHO → ATIVO`, `ATIVO ↔ INATIVO`. Publicado não volta a `RASCUNHO`; `RASCUNHO → INATIVO` direto é rejeitado.
2. **Publicação exige indexador na posição 1** do template estrutural, tanto no `UPDATE` para `ATIVO` quanto num `INSERT` que já nasça publicado.
3. **Modelo publicado é imutável:** a chave `(id_modelo, versao)`, a `descricao` e os templates não mudam; só `situacao` e colunas de controle. Só `RASCUNHO` pode ser excluído.
4. **Templates de modelo publicado são imutáveis:** não se altera nem exclui o template, nem se inclui/altera/exclui campo dele (inclusive mover associação para um template publicado).
5. **Campo em uso por modelo publicado** não muda de `nome_campo` nem de `tipo_dado` (`descricao_base` pode mudar).
6. **Concorrência:** publicar trava (`FOR UPDATE`) os templates e (`FOR SHARE`) os campos antes de validar; editar associação trava (`FOR SHARE`) o template antes de checar. Os dois se enfileiram, e o segundo enxerga o que o primeiro confirmou. Se duas sessões se cruzarem, o PostgreSQL aborta uma com `40P01` e a aplicação repete.

Erros de regra usam SQLSTATE `23514` (`check_violation`) e a mensagem nomeia o modelo, o template ou o campo.

> **Para evoluir uma versão publicada** crie novos templates (cópia) para a nova versão: os templates da versão publicada ficam congelados.

## Seed de inspeção

Carregado na primeira subida (`v1.0.07`). Cada modelo mostra uma regra:

| Modelo | Versão | Situação | O que demonstra |
|---|---|---|---|
| `COMPPIX` | 1 | `INATIVO` | versão retirada continua imutável |
| `COMPPIX` | 2 | `ATIVO` | versão vigente; `data_hora_transacao` está nos dois templates com descrições diferentes |
| `COMPPIX` | 3 | `RASCUNHO` | editável; tem indexador 1, então pode ser publicada |
| `COMPTED` | 1 | `ATIVO` | estrutural com os 5 indexadores |
| `COMPBOL` | 1 | `ATIVO` | mínimo publicável: só o indexador 1 |
| `COMPBOL` | 2 | `RASCUNHO` | **sem indexador 1**: `UPDATE ... SET situacao = 'ATIVO'` é rejeitado |

29 campos, vários compartilhados entre modelos (`valor`, `data_hora_transacao`, `status_liquidacao`...). Algumas associações têm
`descricao_campo_template`; as demais usam `descricao_base`.

Inspecionar:

```bash
docker exec -it postgres18-receiptsio psql -U "$DB_USER_NAME" -d "$DB_NAME"
```

```sql
SELECT id_modelo, versao, situacao FROM catalogo.modelo ORDER BY 1, 2;

-- modelo completo, como o cache carrega (um elemento por associação, ordenado)
SELECT campos_estruturais, campos_variaveis FROM catalogo.vw_modelo_completo
 WHERE id_modelo = 'COMPPIX' AND versao = 2;

-- versão vigente
SELECT versao FROM catalogo.modelo WHERE id_modelo = 'COMPPIX' AND situacao = 'ATIVO';

-- a regra de publicação: deve falhar com "Publicação exige indexador na posição 1"
UPDATE catalogo.modelo SET situacao = 'ATIVO' WHERE id_modelo = 'COMPBOL' AND versao = 2;
```

Mais exemplos (inclusive como publicar o `COMPBOL` v2) em `exemplos-queries.sql`.

## Roles e privilégios

| Role | Privilégios | Uso |
|---|---|---|
| `catalogo_leitura` | `SELECT` em tudo do schema `catalogo` (tabelas e view) | carregador de cache |
| `catalogo_escrita` | `SELECT`, `INSERT`, `DELETE` e `UPDATE` **por coluna**, sem DDL | aplicação de administração |

O `UPDATE` da role de escrita é concedido tabela a tabela e **nunca inclui `data_hora_criacao`**; em `modelo` também não inclui
`id_modelo` nem `versao`. **Tabela nova do schema precisa ganhar a sua lista de colunas em `v1.0.06`**, senão a escrita recebe
`permission denied`. Nenhuma das roles é dona dos objetos: migrations e DDL ficam com o superusuário.

## Timezone

Banco padrão: `America/Sao_Paulo`. Todos os `timestamptz` são exibidos nesse fuso (o instante armazenado é absoluto).

## Extensões

A receita de somar uma extensão nova vive em **três arquivos diferentes**, e nenhum deles se
refere aos outros — ler qualquer um isolado não revela o procedimento completo:

| Etapa | Arquivo | O que fazer |
|---|---|---|
| 1. instalar | `dockerfile` | pacote PGDG via `apt` ou compilação da fonte |
| 2. declarar (quando exigido) | `postgres-db-v18.yml` | acrescentar a biblioteca em `shared_preload_libraries` |
| 3. criar | `migrations/vX.Y.Z...sql` | `CREATE EXTENSION IF NOT EXISTS <nome>;` |

### 1. Instalar na imagem

O `dockerfile` exercita os dois caminhos de instalação que o projeto se propõe a demonstrar:

- **Pacote pré-compilado do repositório PGDG**: `postgresql-18-partman` e `postgresql-18-cron` (`pg_partman` e `pg_cron`).
- **Compilação a partir do código-fonte**: `pgvector` (tipo `vector` e operadores de distância).

### 2. Declarar em `shared_preload_libraries` (quando exigido)

Nem toda extensão precisa estar no preload. Critério: a extensão registra um *background worker* ou se engancha em um ponto de extensão do servidor.

| Extensão | Biblioteca | Preload? |
|---|---|---|
| `pg_partman` | `pg_partman_bgw` | sim |
| `pg_cron` | `pg_cron` | sim |
| `vector` (pgvector) | — | não |

### 3. Criar a extensão no banco

Na migration v1.0.00:

```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_partman;
CREATE EXTENSION IF NOT EXISTS vector;
```

> Hoje nenhuma tabela do catálogo usa essas extensões; elas ficam disponíveis para os próximos serviços.

### Verificar cada etapa

Bibliotecas carregadas:

```bash
docker exec postgres18-receiptsio psql -U "$DB_USER_NAME" -d "$DB_NAME" -c "SHOW shared_preload_libraries;"
# pg_partman_bgw,pg_cron
```

Extensões criadas:

```bash
docker exec postgres18-receiptsio psql -U "$DB_USER_NAME" -d "$DB_NAME" -c "SELECT extname, extversion FROM pg_extension ORDER BY extname;"
```

## Migrations

Ordenadas lexicograficamente (dois dígitos finais). Rodam pelo entrypoint do Docker **só na primeira subida (volume vazio)**:

```
v1.0.00.-extensoes-schema-timezone-funcoes.sql    extensões, schema, timezone e search_path
v1.0.01.-cria-tabela-campo.sql
v1.0.02.-cria-template-estrutural-e-campos.sql
v1.0.03.-cria-template-variavel-e-campos.sql
v1.0.04.-cria-tabela-modelo.sql                   modelo e view vw_modelo_completo
v1.0.05.-triggers-imutabilidade-e-publicacao.sql  triggers de regra de negócio
v1.0.06.-roles-privilegio-minimo.sh               roles e privilégios por coluna
v1.0.07.-seed-modelo-exemplo.sql                  seed de inspeção
```

Como o init só roda com volume vazio, editar uma migration exige `down -v` + `up`. Rollback: `down -v`.
Flyway/Liquibase ficam para quando existir uma aplicação (a partir daí, só migrations incrementais).

## Volumes

- `receiptsio_pg_data` — dados do PostgreSQL (isolado do projeto de origem).

```bash
docker volume ls | grep receiptsio
```

## Troubleshooting

### Erro: "DB_PASSWORD não definida" (ou das senhas das roles)
Copie `.env.example` para `.env` na raiz e defina os valores. O Compose nomeia a variável ausente.

### Erro: "Database already exists" / volume já existe
O volume `receiptsio_pg_data` já existe com dados antigos. Execute `down -v` antes de `up`.

### Migrations não rodaram
Verifique `docker logs postgres18-receiptsio | grep ERROR`. Lembre que o init só roda com volume vazio.

### Porta 5432 ocupada
Defina `DB_PORT` no `.env` (por exemplo `5433`).

### Script de verificação falha
Recrie tudo com `down -v` + `up -d --build` e rode de novo. Se persistir, a linha `FALHA` mostra o SQLSTATE e a mensagem obtidos.

## Próximos passos

- Aplicação Java de administração com a role `catalogo_escrita`: `@Version` em `data_version`, `@UpdateTimestamp` em
  `data_hora_atualizacao`, `@Column(updatable = false)` em `data_hora_criacao`, `OPTIMISTIC_FORCE_INCREMENT` no template ao editar
  associações, e repetição da transação em `40P01`.
- Carregador de cache (Redis/Valkey) com a role `catalogo_leitura` lendo `vw_modelo_completo` só de versões publicadas.
- Emissão de comprovante (NoSQL) referenciando `(id_modelo, versao)`.
