-- v1.0.01.-cria-tabela-campo.sql
-- Tabela: campo (com identity, CHECK de tipo_dado, unicidade de nome+tipo, auditoria)

CREATE TABLE catalogo.campo (
  -- Identificador único
  id_campo BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  -- Nome do campo (obrigatório, não vazio)
  nome_campo TEXT NOT NULL CHECK (btrim(nome_campo) <> ''),

  -- Tipo de dado (obrigatório, domínio fechado)
  tipo_dado TEXT NOT NULL CHECK (
    tipo_dado IN ('TEXTO', 'INTEIRO', 'DECIMAL', 'DATA', 'DATA_HORA', 'BOOLEANO', 'UUID')
  ),

  -- Descrição (opcional)
  descricao_base TEXT,

  -- Lock otimista
  version BIGINT NOT NULL DEFAULT 0,

  -- Auditoria
  data_hora_criacao TIMESTAMPTZ NOT NULL DEFAULT now(),
  data_hora_atualizacao TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Unicidade: nome (case-insensitive) + tipo_dado
  UNIQUE (LOWER(nome_campo), tipo_dado)
);

-- Índices
CREATE UNIQUE INDEX uk_campo_nome_tipo ON catalogo.campo (LOWER(nome_campo), tipo_dado);
CREATE INDEX ix_campo_tipo_dado ON catalogo.campo (tipo_dado);

-- Trigger para atualizar data_hora_atualizacao
CREATE TRIGGER trg_campo_atualiza_data_hora
  BEFORE UPDATE ON catalogo.campo
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_atualiza_data_hora();

COMMENT ON TABLE catalogo.campo IS
  'Campos que compõem os templates (estrutural e variável). Cada campo tem nome único por tipo de dado.';

COMMENT ON COLUMN catalogo.campo.nome_campo IS
  'Nome do campo, case-sensitive, mas unicidade é case-insensitive.';

COMMENT ON COLUMN catalogo.campo.tipo_dado IS
  'Tipo de dado: TEXTO, INTEIRO, DECIMAL, DATA, DATA_HORA, BOOLEANO, UUID.';

COMMENT ON COLUMN catalogo.campo.descricao_base IS
  'Descrição do campo (opcional).';

COMMENT ON COLUMN catalogo.campo.version IS
  'Lock otimista para controle de concorrência. Incrementado pela aplicação.';
