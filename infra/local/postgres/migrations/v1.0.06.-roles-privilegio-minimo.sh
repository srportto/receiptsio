#!/bin/bash
# v1.0.06.-roles-privilegio-minimo.sh
# Cria as roles de privilégio mínimo do catálogo:
#   catalogo_leitura : SELECT em tudo do schema (tabelas e view) - carregador de cache
#   catalogo_escrita : SELECT/INSERT/DELETE e UPDATE coluna a coluna - aplicação de administração
#
# UPDATE é concedido por coluna, tabela a tabela, e NUNCA inclui data_hora_criacao
# (a data de criação não pode ser alterada pela aplicação). Tabela nova do schema precisa
# ganhar a sua lista de colunas aqui; sem isso a role de escrita recebe "permission denied".
# ALTER DEFAULT PRIVILEGES não aceita lista de colunas, por isso o default de tabelas futuras
# da role de escrita não inclui UPDATE.

set -euo pipefail

# O entrypoint do container exporta POSTGRES_USER e POSTGRES_DB (vindos de DB_USER_NAME e DB_NAME)
: "${POSTGRES_USER:?POSTGRES_USER não definida}"
: "${POSTGRES_DB:?POSTGRES_DB não definida}"

# Executa SQL no banco corrente. Argumentos após o SQL (ex.: -v senha=...) vão para o psql,
# onde o SQL usa :'senha'.
run_sql() {
  local sql="$1"
  shift
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@" <<< "$sql"
}

# ============================================================================
# Validar variáveis de ambiente obrigatórias
# ============================================================================

if [ -z "${DB_CATALOGO_LEITURA_PASSWORD:-}" ]; then
  echo "Erro: DB_CATALOGO_LEITURA_PASSWORD não definida" >&2
  exit 1
fi

if [ -z "${DB_CATALOGO_ESCRITA_PASSWORD:-}" ]; then
  echo "Erro: DB_CATALOGO_ESCRITA_PASSWORD não definida" >&2
  exit 1
fi

# ============================================================================
# Role de LEITURA: somente SELECT no schema catalogo (inclui a view vw_modelo_completo)
# ============================================================================

run_sql "
  CREATE ROLE catalogo_leitura WITH LOGIN PASSWORD :'senha_leitura';

  GRANT USAGE ON SCHEMA catalogo TO catalogo_leitura;

  -- SELECT em todas as tabelas e views do schema (atuais e futuras)
  GRANT SELECT ON ALL TABLES IN SCHEMA catalogo TO catalogo_leitura;
  ALTER DEFAULT PRIVILEGES IN SCHEMA catalogo GRANT SELECT ON TABLES TO catalogo_leitura;

  -- SELECT em sequences (para consultas)
  GRANT SELECT ON ALL SEQUENCES IN SCHEMA catalogo TO catalogo_leitura;
  ALTER DEFAULT PRIVILEGES IN SCHEMA catalogo GRANT SELECT ON SEQUENCES TO catalogo_leitura;
" -v senha_leitura="$DB_CATALOGO_LEITURA_PASSWORD"

# ============================================================================
# Role de ESCRITA: SELECT/INSERT/DELETE + UPDATE por coluna (sem data_hora_criacao), sem DDL
# ============================================================================

run_sql "
  CREATE ROLE catalogo_escrita WITH LOGIN PASSWORD :'senha_escrita';

  GRANT USAGE ON SCHEMA catalogo TO catalogo_escrita;

  -- SELECT, INSERT e DELETE em todas as tabelas (atuais e futuras); a view recebe SELECT
  GRANT SELECT, INSERT, DELETE ON ALL TABLES IN SCHEMA catalogo TO catalogo_escrita;
  ALTER DEFAULT PRIVILEGES IN SCHEMA catalogo GRANT SELECT, INSERT, DELETE ON TABLES TO catalogo_escrita;

  -- Retira o que não se aplica à view (DML) e garante só SELECT nela
  REVOKE INSERT, DELETE ON catalogo.vw_modelo_completo FROM catalogo_escrita;

  -- UPDATE coluna a coluna: data_hora_criacao fica de fora em todas as tabelas
  GRANT UPDATE (nome_campo, tipo_dado, descricao_base, data_version, data_hora_atualizacao)
    ON catalogo.campo TO catalogo_escrita;

  GRANT UPDATE (nome_template, descricao, data_version, data_hora_atualizacao)
    ON catalogo.template_estrutural TO catalogo_escrita;

  GRANT UPDATE (id_template_estrutural, id_campo, ordem, posicao_indexador, aceita_nulo_vazio,
                descricao_campo_template, data_hora_atualizacao)
    ON catalogo.template_estrutural_campo TO catalogo_escrita;

  GRANT UPDATE (nome_template, descricao, data_version, data_hora_atualizacao)
    ON catalogo.template_variavel TO catalogo_escrita;

  GRANT UPDATE (id_template_variavel, id_campo, ordem, aceita_nulo_vazio,
                descricao_campo_template, data_hora_atualizacao)
    ON catalogo.template_variavel_campo TO catalogo_escrita;

  -- Modelo: id_modelo e versao (a chave) não são atualizáveis
  GRANT UPDATE (descricao, situacao, id_template_estrutural, id_template_variavel,
                data_version, data_hora_atualizacao)
    ON catalogo.modelo TO catalogo_escrita;

  -- USAGE em sequences (identity de campo)
  GRANT USAGE ON ALL SEQUENCES IN SCHEMA catalogo TO catalogo_escrita;
  ALTER DEFAULT PRIVILEGES IN SCHEMA catalogo GRANT USAGE ON SEQUENCES TO catalogo_escrita;
" -v senha_escrita="$DB_CATALOGO_ESCRITA_PASSWORD"

echo "Roles catalogo_leitura e catalogo_escrita criadas com sucesso"
