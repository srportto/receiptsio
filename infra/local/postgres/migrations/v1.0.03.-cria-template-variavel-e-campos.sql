-- v1.0.03.-cria-template-variavel-e-campos.sql
-- Tabela: template_variavel com UUIDv7 nativo
-- Tabela: template_variavel_campo (associação sem indexadores)

-- ============================================================================
-- Tabela: template_variavel
-- ============================================================================

CREATE TABLE catalogo.template_variavel (
  -- Identificador único: UUIDv7 (nativo do PostgreSQL 18)
  id_template_variavel UUID PRIMARY KEY DEFAULT uuidv7(),

  -- Nome do template
  nome_template TEXT NOT NULL,

  -- Lock otimista
  version BIGINT NOT NULL DEFAULT 0,

  -- Auditoria
  data_hora_criacao TIMESTAMPTZ NOT NULL DEFAULT now(),
  data_hora_atualizacao TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger para atualizar data_hora_atualizacao
CREATE TRIGGER trg_template_variavel_atualiza_data_hora
  BEFORE UPDATE ON catalogo.template_variavel
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_atualiza_data_hora();

COMMENT ON TABLE catalogo.template_variavel IS
  'Template variável: conjunto de campos opcionais que variam conforme o comprovante.';

COMMENT ON COLUMN catalogo.template_variavel.id_template_variavel IS
  'Identificador único, gerado como UUIDv7 (ordenado por tempo).';

-- ============================================================================
-- Tabela: template_variavel_campo (Associação N:N sem indexadores)
-- ============================================================================

CREATE TABLE catalogo.template_variavel_campo (
  -- Chave primária composta
  id_template_variavel UUID NOT NULL REFERENCES catalogo.template_variavel ON DELETE RESTRICT,
  id_campo BIGINT NOT NULL REFERENCES catalogo.campo ON DELETE RESTRICT,

  -- Posição do campo no template (ordem de exibição)
  ordem SMALLINT NOT NULL CHECK (ordem > 0),

  -- Se o campo pode aceitar nulo/vazio
  aceita_nulo_vazio BOOLEAN NOT NULL DEFAULT false,

  -- Chave primária composta
  PRIMARY KEY (id_template_variavel, id_campo),

  -- Ordem única por template
  UNIQUE (id_template_variavel, ordem)
);

-- Índices para performance em buscas de FK
CREATE INDEX ix_template_variavel_campo_template ON catalogo.template_variavel_campo (id_template_variavel);
CREATE INDEX ix_template_variavel_campo_campo ON catalogo.template_variavel_campo (id_campo);

COMMENT ON TABLE catalogo.template_variavel_campo IS
  'Associação entre template variável e campos. Define ordem e obrigatoriedade. Sem indexadores.';

COMMENT ON COLUMN catalogo.template_variavel_campo.ordem IS
  'Ordem de exibição do campo no template (> 0, único por template).';

COMMENT ON COLUMN catalogo.template_variavel_campo.aceita_nulo_vazio IS
  'Se true, o campo pode não ter valor.';
