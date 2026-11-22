-- v1.0.00.-extensoes-schema-timezone-funcoes.sql
-- Extensões, schema catalogo, timezone padrão e função de auditoria.

-- ============================================================================
-- Extensões: pg_cron, pg_partman, vector
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_partman;
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================================
-- Timezone padrão: America/Sao_Paulo
-- ============================================================================

ALTER DATABASE "db-receiptsio" SET timezone = 'America/Sao_Paulo';

-- ============================================================================
-- Schema dedicado: catalogo
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS catalogo;

-- search_path inclui catalogo antes de public
ALTER DATABASE "db-receiptsio" SET search_path = 'catalogo, public';

-- Aplicar search_path na sessão atual
SET search_path = 'catalogo, public';

-- ============================================================================
-- Função de auditoria: atualiza data_hora_atualizacao
-- ============================================================================

CREATE OR REPLACE FUNCTION catalogo.fn_atualiza_data_hora()
RETURNS TRIGGER AS $$
BEGIN
  NEW.data_hora_atualizacao := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   IMMUTABLE
   SECURITY DEFINER;

COMMENT ON FUNCTION catalogo.fn_atualiza_data_hora() IS
  'Trigger para atualizar data_hora_atualizacao em BEFORE UPDATE.';
