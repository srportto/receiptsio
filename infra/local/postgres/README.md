# PostgreSQL 18 Local — Catálogo de Modelos de Comprovante

Ambiente PostgreSQL 18 local em Docker para o catálogo relacional de modelos de comprovante (`receiptsio`).
Inclui extensões (`pg_cron`, `pg_partman`, `vector`), schema dedicado `catalogo`, roles de privilégio mínimo, triggers de imutabilidade e seed de exemplo.

## Subir o ambiente

Pré-requisito: `.env` na raiz com todas as variáveis (copie `.env.example`):

```bash
cd infra/local/postgres
docker compose --env-file ../../../.env -f postgres-db-v18.yml up -d --build
docker compose --env-file ../../../.env -f postgres-db-v18.yml ps
```

Aguardar status `healthy` (pode levar ~10s):

```bash
docker compose --env-file ../../../.env -f postgres-db-v18.yml exec postgres18-receiptsio \
  pg_isready -U docker -d db-receiptsio
# Esperado: accepting connections
```

## Validar o catálogo

Após a subida, executar o script de verificação (testa todos os cenários):

```bash
cd infra/local/postgres
docker exec -i postgres18-receiptsio psql -v ON_ERROR_STOP=1 -U docker -d db-receiptsio < verificar-catalogo.sql
echo "Código de saída: $?"
```

Esperado: todos os cenários `OK`, código 0.

## Parar o ambiente

```bash
cd infra/local/postgres
docker compose --env-file ../../../.env -f postgres-db-v18.yml down
```

Para remover o volume (limpar dados) e recriar tudo:

```bash
docker compose --env-file ../../../.env -f postgres-db-v18.yml down -v
docker compose --env-file ../../../.env -f postgres-db-v18.yml up -d --build
```

## Conectar ao banco

Com o container rodando, conectar como superusuário (testes):

```bash
docker exec -it postgres18-receiptsio \
  psql -U docker -d db-receiptsio
```

Ou como role de leitura (cache):

```bash
docker exec -it postgres18-receiptsio \
  psql -U catalogo_leitura -d db-receiptsio
# Pedir senha: use a da variável DB_CATALOGO_LEITURA_PASSWORD do .env
```

Ou como role de escrita (administração):

```bash
docker exec -it postgres18-receiptsio \
  psql -U catalogo_escrita -d db-receiptsio
# Pedir senha: use a da variável DB_CATALOGO_ESCRITA_PASSWORD do .env
```

## Schema e tabelas

Schema dedicado: `catalogo`

Tabelas:
- `campo` — campos que compõem os templates
- `template_estrutural` — estrutura obrigatória
- `template_estrutural_campo` — associação com indexadores e ordem
- `template_variavel` — campos opcionais
- `template_variavel_campo` — associação com ordem
- `modelo` — modelo de comprovante (PK composta: `id_modelo, versao`)

## Regras de negócio (triggers)

1. **Imutabilidade de modelo publicado:** uma vez `ATIVO`, só `situacao` pode mudar; `INATIVO` e `ATIVO` não voltam a `RASCUNHO`.
2. **Publicação exige indexador 1:** modelo só passa `RASCUNHO → ATIVO` se o template estrutural tem campo em `posicao_indexador = 1`.
3. **Templates de modelos publicados são imutáveis:** não pode adicionar, alterar ou remover campos em templates referenciados por modelos `ATIVO` ou `INATIVO`.
4. **Máximo uma versão ativa:** índice único parcial garante no máximo uma `(id_modelo, ATIVO)`.

## Seed de exemplo

Ao subir, carrega automaticamente:
- 12 campos de exemplo (id_transacao, cpf_pagador, valor, etc.)
- Template estrutural com 2 indexadores (posição 1, 2) e 6 campos
- Template variável com 4 campos opcionais
- Modelo `COMPPIX` versão 1 (`ATIVO`) e versão 2 (`RASCUNHO`)

Consultar modelo completo para cache:

```sql
-- Carrega modelo e campos para cache (veja exemplos-queries.sql para sintaxe completa)
SELECT * FROM catalogo.modelo m
  LEFT JOIN catalogo.template_estrutural_campo tec 
    ON m.id_template_estrutural = tec.id_template_estrutural
  LEFT JOIN catalogo.campo c ON tec.id_campo = c.id_campo
WHERE m.id_modelo = 'COMPPIX' AND m.versao = 1
ORDER BY tec.ordem;

-- Resolver versão vigente
SELECT versao FROM catalogo.modelo
WHERE id_modelo = 'COMPPIX' AND situacao = 'ATIVO';
```

## Roles e privilégios

- `catalogo_leitura` — `SELECT` em schema `catalogo` (carregador de cache)
- `catalogo_escrita` — `SELECT`, `INSERT`, `UPDATE`, `DELETE` em schema `catalogo` (administração)

Ambos não têm DDL; migrations e schema ficam com o superusuário.

## Timezone

Banco padrão: `America/Sao_Paulo`. Todos os `timestamptz` exibem neste fuso.

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

### Verificar cada etapa

Bibliotecas carregadas:

```bash
docker exec postgres18-receiptsio psql -U docker -d db-receiptsio -c "SHOW shared_preload_libraries;"
# pg_partman_bgw,pg_cron
```

Extensões criadas:

```bash
docker exec postgres18-receiptsio psql -U docker -d db-receiptsio -c "SELECT extname, extversion FROM pg_extension ORDER BY extname;"
```

## Lock otimista

`version BIGINT` em `campo`, `template_estrutural`, `template_variavel`, `modelo`.
Incrementado pela aplicação (padrão JPA `@Version`). Sem trigger de incremento.

## Migrations

Ordenadas lexicograficamente (dois dígitos finais):

```
v1.0.00.-extensoes-schema-timezone-funcoes.sql
v1.0.01.-cria-tabela-campo.sql
v1.0.02.-cria-template-estrutural-e-campos.sql
v1.0.03.-cria-template-variavel-e-campos.sql
v1.0.04.-cria-tabela-modelo.sql
v1.0.05.-triggers-imutabilidade-e-publicacao.sql
v1.0.06.-roles-privilegio-minimo.sh
v1.0.07.-seed-modelo-exemplo.sql
```

Executadas pelo entrypoint Docker na primeira subida (volume vazio). Rollback: `down -v` (remove apenas `receiptsio_pg_data`).

## Volumes

- `receiptsio_pg_data` — dados do PostgreSQL (isolado do projeto anterior)

Verificar:

```bash
docker volume ls | grep receiptsio
```

Se havia um volume legado (`postgres_pg_data`), ele fica intacto; este projeto não o toca.

## Troubleshooting

### Erro: "DB_PASSWORD não definida"
Copie `.env.example` para `.env` na raiz e defina os valores.

### Erro: "Database already exists"
O volume `receiptsio_pg_data` já existe. Execute `down -v` antes de `up`.

### Migrations não rodaram
Verifique logs: `docker logs postgres18-receiptsio | grep ERROR`.

### Script de verificação falha
Execute novamente com `down -v` + `up -d --build` para recriar tudo.

## Próximos passos

- Desenvolver aplicação Java com role `catalogo_escrita` para administração
- Implementar carregador de cache (Redis/Valkey) com role `catalogo_leitura`
- Implementar emissão de comprovante (NoSQL) referenciando `(id_modelo, versao)`
