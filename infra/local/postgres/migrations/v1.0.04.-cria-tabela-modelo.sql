-- v1.0.04.-cria-tabela-modelo.sql
-- Tabela: modelo (PK composta, situação, versão vigente)

CREATE TABLE catalogo.modelo (
  -- Identificador do modelo (código: 1-10 caracteres em [A-Z0-9_])
  id_modelo VARCHAR(10) NOT NULL CHECK (id_modelo ~ '^[A-Z0-9_]{1,10}$'),

  -- Versão (1-999)
  versao SMALLINT NOT NULL CHECK (versao BETWEEN 1 AND 999),

  -- Descrição do modelo
  descricao TEXT NOT NULL,

  -- Situação (RASCUNHO, ATIVO, INATIVO)
  situacao TEXT NOT NULL DEFAULT 'RASCUNHO' CHECK (
    situacao IN ('RASCUNHO', 'ATIVO', 'INATIVO')
  ),

  -- Template estrutural (FK UUID NOT NULL, como corrigido em D2)
  id_template_estrutural UUID NOT NULL REFERENCES catalogo.template_estrutural ON DELETE RESTRICT,

  -- Template variável (FK UUID NOT NULL, como corrigido em D2)
  id_template_variavel UUID NOT NULL REFERENCES catalogo.template_variavel ON DELETE RESTRICT,

  -- Lock otimista
  version BIGINT NOT NULL DEFAULT 0,

  -- Auditoria
  data_hora_criacao TIMESTAMPTZ NOT NULL DEFAULT now(),
  data_hora_atualizacao TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Chave primária composta: (id_modelo, versao)
  PRIMARY KEY (id_modelo, versao)
);

-- Índice parcial: máximo uma versão ATIVO por id_modelo
CREATE UNIQUE INDEX uk_modelo_ativo ON catalogo.modelo (id_modelo) WHERE situacao = 'ATIVO';

-- Índices nas FKs (para performance do trigger de imutabilidade em D3)
CREATE INDEX ix_modelo_template_estrutural ON catalogo.modelo (id_template_estrutural);
CREATE INDEX ix_modelo_template_variavel ON catalogo.modelo (id_template_variavel);

-- Trigger para atualizar data_hora_atualizacao
CREATE TRIGGER trg_modelo_atualiza_data_hora
  BEFORE UPDATE ON catalogo.modelo
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_atualiza_data_hora();

COMMENT ON TABLE catalogo.modelo IS
  'Modelo de comprovante: versão do catálogo com templates estrutural e variável.';

COMMENT ON COLUMN catalogo.modelo.id_modelo IS
  'Identificador único do modelo (código, 1-10 caracteres: A-Z, 0-9, _).';

COMMENT ON COLUMN catalogo.modelo.versao IS
  'Versão do modelo (1-999). Chave composta: (id_modelo, versao) é única.';

COMMENT ON COLUMN catalogo.modelo.descricao IS
  'Descrição do modelo.';

COMMENT ON COLUMN catalogo.modelo.situacao IS
  'RASCUNHO = em construção; ATIVO = publicado e imutável; INATIVO = retirado.';

COMMENT ON COLUMN catalogo.modelo.id_template_estrutural IS
  'UUID do template estrutural que define os campos obrigatórios e indexadores.';

COMMENT ON COLUMN catalogo.modelo.id_template_variavel IS
  'UUID do template variável que define os campos opcionais.';

COMMENT ON COLUMN catalogo.modelo.version IS
  'Lock otimista para controle de concorrência. Incrementado pela aplicação.';
