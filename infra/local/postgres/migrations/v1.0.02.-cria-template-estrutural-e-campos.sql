-- v1.0.02.-cria-template-estrutural-e-campos.sql
-- Tabela: template_estrutural (UUIDv7 nativo)
-- Tabela: template_estrutural_campo (associação com ordem, indexadores e descrição por template)

-- ============================================================================
-- Tabela: template_estrutural
-- ============================================================================

CREATE TABLE catalogo.template_estrutural (
  -- Identificador único: UUIDv7 (nativo do PostgreSQL 18)
  id_template_estrutural UUID PRIMARY KEY DEFAULT uuidv7(),

  -- Nome curto do template (obrigatório, não vazio)
  nome_template TEXT NOT NULL CHECK (btrim(nome_template) <> ''),

  -- Descrição do template (opcional)
  descricao TEXT,

  -- Lock otimista (controle técnico)
  data_version BIGINT NOT NULL DEFAULT 0,

  -- Auditoria (sem trigger: a aplicação renova data_hora_atualizacao no UPDATE)
  data_hora_criacao TIMESTAMPTZ NOT NULL DEFAULT now(),
  data_hora_atualizacao TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE catalogo.template_estrutural IS
  'Template estrutural: conjunto de campos que formam a estrutura obrigatória do comprovante, incluindo os indexadores (chaves de busca no NoSQL).';

COMMENT ON COLUMN catalogo.template_estrutural.id_template_estrutural IS
  'Identificador único, gerado como UUIDv7 (ordenado por tempo).';

COMMENT ON COLUMN catalogo.template_estrutural.nome_template IS
  'Nome curto do template (obrigatório).';

COMMENT ON COLUMN catalogo.template_estrutural.descricao IS
  'Descrição do template (opcional).';

COMMENT ON COLUMN catalogo.template_estrutural.data_version IS
  'Lock otimista do template e de suas associações (a aplicação usa OPTIMISTIC_FORCE_INCREMENT ao editar associações).';

-- ============================================================================
-- Tabela: template_estrutural_campo (associação N:N com indexadores)
-- ============================================================================

CREATE TABLE catalogo.template_estrutural_campo (
  id_template_estrutural UUID NOT NULL REFERENCES catalogo.template_estrutural ON DELETE RESTRICT,
  id_campo BIGINT NOT NULL REFERENCES catalogo.campo ON DELETE RESTRICT,

  -- Posição do campo no template (ordem de exibição)
  ordem SMALLINT NOT NULL CHECK (ordem > 0),

  -- Posição do indexador (1-5, chave de busca no NoSQL) ou NULL se não for indexador
  posicao_indexador SMALLINT NULL CHECK (posicao_indexador BETWEEN 1 AND 5),

  -- Se o campo pode aceitar nulo/vazio (padrão: obrigatório)
  aceita_nulo_vazio BOOLEAN NOT NULL DEFAULT false,

  -- Descrição do campo neste template (opcional; se nula vale campo.descricao_base)
  descricao_campo_template TEXT,

  -- Auditoria (sem trigger e sem lock otimista: o lock fica no template)
  data_hora_criacao TIMESTAMPTZ NOT NULL DEFAULT now(),
  data_hora_atualizacao TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Indexador não pode aceitar nulo/vazio
  CHECK (posicao_indexador IS NULL OR aceita_nulo_vazio = false),

  -- Um campo aparece no máximo uma vez por template
  PRIMARY KEY (id_template_estrutural, id_campo),

  -- Ordem única por template
  UNIQUE (id_template_estrutural, ordem),

  -- Posição de indexador única por template (NULLs não colidem)
  UNIQUE (id_template_estrutural, posicao_indexador)
);

-- A PK já atende a busca por template; este índice atende a busca por campo
-- (FK RESTRICT e a verificação de "campo em uso por modelo publicado").
CREATE INDEX ix_template_estrutural_campo_campo ON catalogo.template_estrutural_campo (id_campo);

COMMENT ON TABLE catalogo.template_estrutural_campo IS
  'Associação entre template estrutural e campos. Define ordem, indexadores, obrigatoriedade e descrição do campo no template.';

COMMENT ON COLUMN catalogo.template_estrutural_campo.ordem IS
  'Ordem de exibição do campo no template (> 0, única por template).';

COMMENT ON COLUMN catalogo.template_estrutural_campo.posicao_indexador IS
  'Posição do campo como indexador no NoSQL (1-5) ou NULL. A posição 1 é obrigatória para publicar o modelo.';

COMMENT ON COLUMN catalogo.template_estrutural_campo.aceita_nulo_vazio IS
  'Se true, o campo pode não ter valor. Incompatível com indexador (CHECK). Padrão false: obrigatório.';

COMMENT ON COLUMN catalogo.template_estrutural_campo.descricao_campo_template IS
  'Descrição do campo neste template (opcional). Quando nula, a descrição efetiva é campo.descricao_base.';

COMMENT ON COLUMN catalogo.template_estrutural_campo.data_hora_atualizacao IS
  'Instante da última alteração. O banco só preenche no INSERT; a aplicação deve renová-la em todo UPDATE.';
