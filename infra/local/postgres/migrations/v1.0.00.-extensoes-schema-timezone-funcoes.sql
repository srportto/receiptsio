-- v1.0.00.-extensoes-schema-timezone-funcoes.sql
-- Extensões, schema catalogo e timezone padrão do banco.
--
-- Não há função/trigger de auditoria: as colunas de data têm DEFAULT now() (preenchidas no INSERT)
-- e quem renova data_hora_atualizacao a cada UPDATE é a aplicação.

-- ============================================================================
-- Extensões: pg_cron, pg_partman, vector
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_partman;
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================================
-- Schema dedicado: catalogo
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS catalogo;

-- ============================================================================
-- Timezone e search_path do banco corrente (o nome vem de POSTGRES_DB / DB_NAME,
-- por isso não é fixado aqui). Valem para as próximas conexões.
-- ============================================================================

DO $$
BEGIN
  EXECUTE format('ALTER DATABASE %I SET timezone = %L', current_database(), 'America/Sao_Paulo');
  -- %s (e não %L): search_path é uma lista de schemas, não uma string única
  EXECUTE format('ALTER DATABASE %I SET search_path = %s', current_database(), 'catalogo, public');
END
$$;

-- Aplica o search_path na sessão atual (as demais migrations qualificam catalogo.* mesmo assim)
SET search_path = catalogo, public;
