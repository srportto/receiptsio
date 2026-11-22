-- v1.0.01.-cria-tabela-campo.sql
-- Tabela: campo (identity, CHECK de tipo_dado, unicidade de nome+tipo, lock otimista, auditoria)

CREATE TABLE catalogo.campo (
  -- Identificador único
  id_campo BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  -- Nome do campo (obrigatório, não vazio)
  nome_campo TEXT NOT NULL CHECK (btrim(nome_campo) <> ''),

  -- Tipo de dado (obrigatório, domínio fechado)
  tipo_dado TEXT NOT NULL CHECK (
    tipo_dado IN ('TEXTO', 'INTEIRO', 'DECIMAL', 'DATA', 'DATA_HORA', 'BOOLEANO', 'UUID')
  ),

  -- Descrição base de uso do campo (opcional)
  descricao_base TEXT,

  -- Lock otimista (controle técnico; não confundir com a versao de negócio do modelo)
  data_version BIGINT NOT NULL DEFAULT 0,

  -- Auditoria (sem trigger: o INSERT usa o DEFAULT; o UPDATE é responsabilidade da aplicação)
  data_hora_criacao TIMESTAMPTZ NOT NULL DEFAULT now(),
  data_hora_atualizacao TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Unicidade: nome (sem distinguir maiúsculas) + tipo_dado.
-- Precisa ser índice único: constraint UNIQUE de tabela não aceita expressão.
CREATE UNIQUE INDEX uk_campo_nome_tipo ON catalogo.campo (LOWER(nome_campo), tipo_dado);
CREATE INDEX ix_campo_tipo_dado ON catalogo.campo (tipo_dado);

COMMENT ON TABLE catalogo.campo IS
  'Campos que compõem os templates (estrutural e variável). Cada campo tem nome único por tipo de dado.';

COMMENT ON COLUMN catalogo.campo.nome_campo IS
  'Nome do campo, case-sensitive, mas a unicidade (com tipo_dado) é case-insensitive. Imutável depois que o campo entra em template de modelo publicado.';

COMMENT ON COLUMN catalogo.campo.tipo_dado IS
  'Tipo de dado: TEXTO, INTEIRO, DECIMAL, DATA, DATA_HORA, BOOLEANO, UUID. Imutável depois que o campo entra em template de modelo publicado.';

COMMENT ON COLUMN catalogo.campo.descricao_base IS
  'Descrição de uso do campo (opcional). Vale como descrição efetiva quando a associação ao template não define descricao_campo_template.';

COMMENT ON COLUMN catalogo.campo.data_version IS
  'Lock otimista. Incrementado pela aplicação (JPA @Version). Sem trigger.';

COMMENT ON COLUMN catalogo.campo.data_hora_criacao IS
  'Instante da criação. Preenchido pelo DEFAULT; a role de escrita não tem UPDATE nesta coluna.';

COMMENT ON COLUMN catalogo.campo.data_hora_atualizacao IS
  'Instante da última alteração. O banco só preenche no INSERT; a aplicação deve renová-la em todo UPDATE.';
