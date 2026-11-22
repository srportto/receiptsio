-- v1.0.04.-cria-tabela-modelo.sql
-- Tabela: modelo (PK composta, situação, versão vigente) e view de carga do cache.

CREATE TABLE catalogo.modelo (
  -- Identificador do modelo (código: 1-10 caracteres em [A-Z0-9_])
  id_modelo VARCHAR(10) NOT NULL CHECK (id_modelo ~ '^[A-Z0-9_]{1,10}$'),

  -- Versão de negócio (1-999)
  versao SMALLINT NOT NULL CHECK (versao BETWEEN 1 AND 999),

  -- Descrição do modelo
  descricao TEXT NOT NULL,

  -- Situação (RASCUNHO, ATIVO, INATIVO)
  situacao TEXT NOT NULL DEFAULT 'RASCUNHO' CHECK (
    situacao IN ('RASCUNHO', 'ATIVO', 'INATIVO')
  ),

  -- Composição: um template estrutural e um template variável
  id_template_estrutural UUID NOT NULL REFERENCES catalogo.template_estrutural ON DELETE RESTRICT,
  id_template_variavel UUID NOT NULL REFERENCES catalogo.template_variavel ON DELETE RESTRICT,

  -- Lock otimista (controle técnico; não confundir com a versao de negócio)
  data_version BIGINT NOT NULL DEFAULT 0,

  -- Auditoria (sem trigger: a aplicação renova data_hora_atualizacao no UPDATE)
  data_hora_criacao TIMESTAMPTZ NOT NULL DEFAULT now(),
  data_hora_atualizacao TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Chave primária composta: (id_modelo, versao)
  PRIMARY KEY (id_modelo, versao)
);

-- Índice parcial: no máximo uma versão ATIVO por id_modelo
CREATE UNIQUE INDEX uk_modelo_ativo ON catalogo.modelo (id_modelo) WHERE situacao = 'ATIVO';

-- Índices nas FKs (usados pelos triggers de imutabilidade: "template referenciado por modelo publicado")
CREATE INDEX ix_modelo_template_estrutural ON catalogo.modelo (id_template_estrutural);
CREATE INDEX ix_modelo_template_variavel ON catalogo.modelo (id_template_variavel);

COMMENT ON TABLE catalogo.modelo IS
  'Modelo de comprovante: uma versão do catálogo, composta por um template estrutural e um variável.';

COMMENT ON COLUMN catalogo.modelo.id_modelo IS
  'Código do modelo (1-10 caracteres: A-Z, 0-9, _).';

COMMENT ON COLUMN catalogo.modelo.versao IS
  'Versão de negócio (1-999). A chave (id_modelo, versao) é a referência gravada nos comprovantes do NoSQL e nunca muda depois de publicada.';

COMMENT ON COLUMN catalogo.modelo.descricao IS
  'Descrição do modelo.';

COMMENT ON COLUMN catalogo.modelo.situacao IS
  'RASCUNHO = em construção; ATIVO = publicado e vigente; INATIVO = publicado e retirado. ATIVO e INATIVO são imutáveis (só situacao muda).';

COMMENT ON COLUMN catalogo.modelo.id_template_estrutural IS
  'Template estrutural: campos obrigatórios e indexadores.';

COMMENT ON COLUMN catalogo.modelo.id_template_variavel IS
  'Template variável: campos complementares.';

COMMENT ON COLUMN catalogo.modelo.data_version IS
  'Lock otimista. Incrementado pela aplicação (JPA @Version). Sem trigger.';

COMMENT ON COLUMN catalogo.modelo.data_hora_atualizacao IS
  'Instante da última alteração. O banco só preenche no INSERT; a aplicação deve renová-la em todo UPDATE.';

-- ============================================================================
-- View: modelo completo (fonte de carga do cache)
-- Uma linha por (id_modelo, versao). Cada template é agregado em subconsulta própria:
-- juntar as duas associações no mesmo SELECT multiplicaria as linhas (produto cartesiano).
-- ============================================================================

CREATE VIEW catalogo.vw_modelo_completo AS
SELECT
  m.id_modelo,
  m.versao,
  m.descricao,
  m.situacao,
  m.id_template_estrutural,
  te.nome_template AS nome_template_estrutural,
  m.id_template_variavel,
  tv.nome_template AS nome_template_variavel,

  (SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
              'id_campo', c.id_campo,
              'nome_campo', c.nome_campo,
              'tipo_dado', c.tipo_dado,
              'ordem', tec.ordem,
              'aceita_nulo_vazio', tec.aceita_nulo_vazio,
              'posicao_indexador', tec.posicao_indexador,
              'descricao_campo_template', tec.descricao_campo_template,
              'descricao_base', c.descricao_base,
              'descricao_efetiva', COALESCE(tec.descricao_campo_template, c.descricao_base)
            ) ORDER BY tec.ordem
          ), '[]'::jsonb)
     FROM catalogo.template_estrutural_campo tec
     JOIN catalogo.campo c ON c.id_campo = tec.id_campo
    WHERE tec.id_template_estrutural = m.id_template_estrutural) AS campos_estruturais,

  (SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
              'id_campo', c.id_campo,
              'nome_campo', c.nome_campo,
              'tipo_dado', c.tipo_dado,
              'ordem', tvc.ordem,
              'aceita_nulo_vazio', tvc.aceita_nulo_vazio,
              'descricao_campo_template', tvc.descricao_campo_template,
              'descricao_base', c.descricao_base,
              'descricao_efetiva', COALESCE(tvc.descricao_campo_template, c.descricao_base)
            ) ORDER BY tvc.ordem
          ), '[]'::jsonb)
     FROM catalogo.template_variavel_campo tvc
     JOIN catalogo.campo c ON c.id_campo = tvc.id_campo
    WHERE tvc.id_template_variavel = m.id_template_variavel) AS campos_variaveis

FROM catalogo.modelo m
JOIN catalogo.template_estrutural te ON te.id_template_estrutural = m.id_template_estrutural
JOIN catalogo.template_variavel tv ON tv.id_template_variavel = m.id_template_variavel;

COMMENT ON VIEW catalogo.vw_modelo_completo IS
  'Modelo completo para carga do cache: uma linha por (id_modelo, versao) com os campos dos dois templates em jsonb, ordenados por ordem e sem duplicação. Use apenas versões publicadas (ATIVO/INATIVO) no cache.';
