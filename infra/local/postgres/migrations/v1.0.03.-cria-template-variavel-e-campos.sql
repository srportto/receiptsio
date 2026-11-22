-- v1.0.03.-cria-template-variavel-e-campos.sql
-- Tabela: template_variavel (UUIDv7 nativo)
-- Tabela: template_variavel_campo (associação com ordem e descrição por template; sem indexadores)

-- ============================================================================
-- Tabela: template_variavel
-- ============================================================================

CREATE TABLE catalogo.template_variavel (
  -- Identificador único: UUIDv7 (nativo do PostgreSQL 18)
  id_template_variavel UUID PRIMARY KEY DEFAULT uuidv7(),

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

COMMENT ON TABLE catalogo.template_variavel IS
  'Template variável: conjunto de campos complementares que variam conforme o comprovante. Não tem indexadores.';

COMMENT ON COLUMN catalogo.template_variavel.id_template_variavel IS
  'Identificador único, gerado como UUIDv7 (ordenado por tempo).';

COMMENT ON COLUMN catalogo.template_variavel.nome_template IS
  'Nome curto do template (obrigatório).';

COMMENT ON COLUMN catalogo.template_variavel.descricao IS
  'Descrição do template (opcional).';

COMMENT ON COLUMN catalogo.template_variavel.data_version IS
  'Lock otimista do template e de suas associações (a aplicação usa OPTIMISTIC_FORCE_INCREMENT ao editar associações).';

-- ============================================================================
-- Tabela: template_variavel_campo (associação N:N sem indexadores)
-- ============================================================================

CREATE TABLE catalogo.template_variavel_campo (
  id_template_variavel UUID NOT NULL REFERENCES catalogo.template_variavel ON DELETE RESTRICT,
  id_campo BIGINT NOT NULL REFERENCES catalogo.campo ON DELETE RESTRICT,

  -- Posição do campo no template (ordem de exibição)
  ordem SMALLINT NOT NULL CHECK (ordem > 0),

  -- Se o campo pode aceitar nulo/vazio (padrão: obrigatório; informe true para campo opcional)
  aceita_nulo_vazio BOOLEAN NOT NULL DEFAULT false,

  -- Descrição do campo neste template (opcional; se nula vale campo.descricao_base)
  descricao_campo_template TEXT,

  -- Auditoria (sem trigger e sem lock otimista: o lock fica no template)
  data_hora_criacao TIMESTAMPTZ NOT NULL DEFAULT now(),
  data_hora_atualizacao TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Um campo aparece no máximo uma vez por template
  PRIMARY KEY (id_template_variavel, id_campo),

  -- Ordem única por template
  UNIQUE (id_template_variavel, ordem)
);

-- A PK já atende a busca por template; este índice atende a busca por campo
-- (FK RESTRICT e a verificação de "campo em uso por modelo publicado").
CREATE INDEX ix_template_variavel_campo_campo ON catalogo.template_variavel_campo (id_campo);

COMMENT ON TABLE catalogo.template_variavel_campo IS
  'Associação entre template variável e campos. Define ordem, obrigatoriedade e descrição do campo no template. Sem indexadores.';

COMMENT ON COLUMN catalogo.template_variavel_campo.ordem IS
  'Ordem de exibição do campo no template (> 0, única por template).';

COMMENT ON COLUMN catalogo.template_variavel_campo.aceita_nulo_vazio IS
  'Se true, o campo pode não ter valor. Padrão false: obrigatório.';

COMMENT ON COLUMN catalogo.template_variavel_campo.descricao_campo_template IS
  'Descrição do campo neste template (opcional). Quando nula, a descrição efetiva é campo.descricao_base.';

COMMENT ON COLUMN catalogo.template_variavel_campo.data_hora_atualizacao IS
  'Instante da última alteração. O banco só preenche no INSERT; a aplicação deve renová-la em todo UPDATE.';
