-- v1.0.02.-cria-template-estrutural-e-campos.sql
-- Tabela: template_estrutural com UUIDv7 nativo
-- Tabela: template_estrutural_campo (associação com indexadores)

-- ============================================================================
-- Tabela: template_estrutural
-- ============================================================================

CREATE TABLE catalogo.template_estrutural (
  -- Identificador único: UUIDv7 (nativo do PostgreSQL 18)
  id_template_estrutural UUID PRIMARY KEY DEFAULT uuidv7(),

  -- Nome do template
  nome_template TEXT NOT NULL,

  -- Lock otimista
  version BIGINT NOT NULL DEFAULT 0,

  -- Auditoria
  data_hora_criacao TIMESTAMPTZ NOT NULL DEFAULT now(),
  data_hora_atualizacao TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger para atualizar data_hora_atualizacao
CREATE TRIGGER trg_template_estrutural_atualiza_data_hora
  BEFORE UPDATE ON catalogo.template_estrutural
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_atualiza_data_hora();

COMMENT ON TABLE catalogo.template_estrutural IS
  'Template estrutural: conjunto de campos que formam a estrutura obrigatória do comprovante.';

COMMENT ON COLUMN catalogo.template_estrutural.id_template_estrutural IS
  'Identificador único, gerado como UUIDv7 (ordenado por tempo).';

-- ============================================================================
-- Tabela: template_estrutural_campo (Associação N:N com indexadores)
-- ============================================================================

CREATE TABLE catalogo.template_estrutural_campo (
  -- Chave primária composta
  id_template_estrutural UUID NOT NULL REFERENCES catalogo.template_estrutural ON DELETE RESTRICT,
  id_campo BIGINT NOT NULL REFERENCES catalogo.campo ON DELETE RESTRICT,

  -- Posição do campo no template (ordem de exibição)
  ordem SMALLINT NOT NULL CHECK (ordem > 0),

  -- Posição do indexador (1-5 para busca no NoSQL, ou NULL se não indexador)
  posicao_indexador SMALLINT NULL CHECK (posicao_indexador BETWEEN 1 AND 5),

  -- Se o campo pode aceitar nulo/vazio
  aceita_nulo_vazio BOOLEAN NOT NULL DEFAULT false,

  -- Constraint: indexador não pode aceitar nulo
  CHECK (
    posicao_indexador IS NULL OR aceita_nulo_vazio = false
  ),

  -- Chave primária composta
  PRIMARY KEY (id_template_estrutural, id_campo),

  -- Ordem única por template
  UNIQUE (id_template_estrutural, ordem),

  -- Posição de indexador única por template (NULLs não colidem)
  UNIQUE (id_template_estrutural, posicao_indexador)
);

-- Índices para performance em buscas de FK
CREATE INDEX ix_template_estrutural_campo_template ON catalogo.template_estrutural_campo (id_template_estrutural);
CREATE INDEX ix_template_estrutural_campo_campo ON catalogo.template_estrutural_campo (id_campo);

COMMENT ON TABLE catalogo.template_estrutural_campo IS
  'Associação entre template estrutural e campos. Define ordem, indexadores e obrigatoriedade.';

COMMENT ON COLUMN catalogo.template_estrutural_campo.ordem IS
  'Ordem de exibição do campo no template (> 0, único por template).';

COMMENT ON COLUMN catalogo.template_estrutural_campo.posicao_indexador IS
  'Posição do campo como indexador no NoSQL (1-5, ou NULL). Uma única posição 1 por template obrigatória na publicação.';

COMMENT ON COLUMN catalogo.template_estrutural_campo.aceita_nulo_vazio IS
  'Se true, o campo pode não ter valor. Incompatível com indexador (CHECK).';
