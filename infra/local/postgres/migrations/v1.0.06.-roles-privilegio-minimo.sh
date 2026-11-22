#!/bin/bash
# v1.0.06.-roles-privilegio-minimo.sh
# Cria roles de privilégio mínimo para o catálogo: leitura e escrita

set -euo pipefail

# Função para executar SQL com variáveis do ambiente
run_sql() {
  local sql="$1"
  psql -v ON_ERROR_STOP=1 -U docker -d "db-receiptsio" <<< "$sql"
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
# Criar role de LEITURA: SELECT apenas no schema catalogo
# ============================================================================

run_sql "
  -- Criar role
  CREATE ROLE catalogo_leitura WITH LOGIN PASSWORD :'senha_leitura' VALID UNTIL 'infinity';

  -- Permissões no schema catalogo
  GRANT USAGE ON SCHEMA catalogo TO catalogo_leitura;

  -- SELECT em todas as tabelas do schema catalogo (atuais e futuras)
  GRANT SELECT ON ALL TABLES IN SCHEMA catalogo TO catalogo_leitura;
  ALTER DEFAULT PRIVILEGES IN SCHEMA catalogo GRANT SELECT ON TABLES TO catalogo_leitura;

  -- SELECT em sequences (para consultas)
  GRANT SELECT ON ALL SEQUENCES IN SCHEMA catalogo TO catalogo_leitura;
  ALTER DEFAULT PRIVILEGES IN SCHEMA catalogo GRANT SELECT ON SEQUENCES TO catalogo_leitura;
" \
  -v senha_leitura="$DB_CATALOGO_LEITURA_PASSWORD"

# ============================================================================
# Criar role de ESCRITA: SELECT, INSERT, UPDATE, DELETE no schema catalogo
# ============================================================================

run_sql "
  -- Criar role
  CREATE ROLE catalogo_escrita WITH LOGIN PASSWORD :'senha_escrita' VALID UNTIL 'infinity';

  -- Permissões no schema catalogo
  GRANT USAGE ON SCHEMA catalogo TO catalogo_escrita;

  -- SELECT, INSERT, UPDATE, DELETE em todas as tabelas do schema catalogo (atuais e futuras)
  GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA catalogo TO catalogo_escrita;
  ALTER DEFAULT PRIVILEGES IN SCHEMA catalogo GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO catalogo_escrita;

  -- USAGE em sequences (para identity)
  GRANT USAGE ON ALL SEQUENCES IN SCHEMA catalogo TO catalogo_escrita;
  ALTER DEFAULT PRIVILEGES IN SCHEMA catalogo GRANT USAGE ON SEQUENCES TO catalogo_escrita;
" \
  -v senha_escrita="$DB_CATALOGO_ESCRITA_PASSWORD"

echo "Roles catalogo_leitura e catalogo_escrita criadas com sucesso"
