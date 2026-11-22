-- v1.0.07.-seed-modelo-exemplo.sql
-- Seed de inspeção: dados para conferir manualmente o catálogo.
--
--   COMPPIX  v1 INATIVO | v2 ATIVO | v3 RASCUNHO   cada versão com templates PRÓPRIOS
--                                                   (evoluir uma versão publicada exige novos templates)
--   COMPTED  v1 ATIVO                               estrutural com os 5 indexadores (posições 1 a 5)
--   COMPBOL  v1 ATIVO                               estrutural só com o indexador 1
--   COMPBOL  v2 RASCUNHO                            SEM indexador 1: publicar (ATIVO) deve ser rejeitado
--
-- Campos como valor, data_hora_transacao e status_liquidacao são compartilhados entre modelos, e
-- data_hora_transacao aparece nos dois templates do COMPPIX v2 (com descrições diferentes).
-- Algumas associações têm descricao_campo_template e outras não (cai em campo.descricao_base).
--
-- Os templates são montados ANTES dos modelos publicados: a publicação exige indexador 1.

-- ============================================================================
-- Campos
-- ============================================================================

INSERT INTO catalogo.campo (nome_campo, tipo_dado, descricao_base) VALUES
  -- compartilhados
  ('id_transacao',          'UUID',      'Identificador único da transação'),
  ('data_hora_transacao',   'DATA_HORA', 'Data e hora da transação (fuso de São Paulo)'),
  ('valor',                 'DECIMAL',   'Valor da transação em R$ (formato 10.2)'),
  ('cpf_pagador',           'TEXTO',     'CPF do pagador (sem máscara)'),
  ('status_liquidacao',     'TEXTO',     'LIQUIDADO, FALHA ou PENDENTE'),
  ('instituicao_pagador',   'TEXTO',     'Nome da instituição do pagador'),
  ('instituicao_recebedor', 'TEXTO',     'Nome da instituição do recebedor'),
  ('motivo_pagamento',      'TEXTO',     'Motivo ou descrição do pagamento'),
  ('desconto_aplicado',     'DECIMAL',   'Desconto em R$'),
  ('juros_cobrados',        'DECIMAL',   'Juros em R$'),
  ('numero_lote',           'INTEIRO',   'Número sequencial do lote de processamento'),
  ('canal_pagamento',       'TEXTO',     'Canal por onde o pagamento foi feito (APP, WEB, AGENCIA)'),
  -- PIX
  ('chave_pix_recebedor',   'TEXTO',     'Chave PIX do recebedor'),
  -- TED
  ('banco_origem',          'TEXTO',     'Código do banco de origem'),
  ('agencia_origem',        'TEXTO',     'Agência de origem'),
  ('conta_origem',          'TEXTO',     'Conta de origem'),
  ('banco_destino',         'TEXTO',     'Código do banco de destino'),
  ('agencia_destino',       'TEXTO',     'Agência de destino'),
  ('conta_destino',         'TEXTO',     'Conta de destino'),
  ('data_efetivacao',       'DATA',      'Data de efetivação da TED'),
  ('finalidade_ted',        'TEXTO',     'Código de finalidade da TED'),
  -- Boleto
  ('codigo_barras',         'TEXTO',     'Código de barras do boleto (44 dígitos)'),
  ('linha_digitavel',       'TEXTO',     'Linha digitável do boleto (47 dígitos)'),
  ('data_vencimento',       'DATA',      'Data de vencimento do boleto'),
  ('data_pagamento',        'DATA',      'Data em que o boleto foi pago'),
  ('valor_nominal',         'DECIMAL',   'Valor nominal do boleto em R$'),
  ('valor_pago',            'DECIMAL',   'Valor efetivamente pago em R$'),
  ('beneficiario',          'TEXTO',     'Nome do beneficiário do boleto'),
  ('nome_pagador',          'TEXTO',     'Nome do pagador do boleto');

-- ============================================================================
-- Funções auxiliares (só desta sessão): montam as associações pelo nome do campo
-- ============================================================================

CREATE FUNCTION pg_temp.campo_id(p_nome TEXT) RETURNS BIGINT LANGUAGE sql AS $$
  SELECT id_campo FROM catalogo.campo WHERE nome_campo = p_nome
$$;

-- Associa campo ao template estrutural: (template, campo, ordem, posição de indexador, aceita nulo, descrição no template)
CREATE FUNCTION pg_temp.ae(p_te UUID, p_campo TEXT, p_ordem INT, p_idx INT DEFAULT NULL,
                           p_nulo BOOLEAN DEFAULT false, p_desc TEXT DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO catalogo.template_estrutural_campo
    (id_template_estrutural, id_campo, ordem, posicao_indexador, aceita_nulo_vazio, descricao_campo_template)
  VALUES (p_te, pg_temp.campo_id(p_campo), p_ordem, p_idx, p_nulo, p_desc)
$$;

-- Associa campo ao template variável: (template, campo, ordem, aceita nulo, descrição no template)
CREATE FUNCTION pg_temp.av(p_tv UUID, p_campo TEXT, p_ordem INT,
                           p_nulo BOOLEAN DEFAULT false, p_desc TEXT DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO catalogo.template_variavel_campo
    (id_template_variavel, id_campo, ordem, aceita_nulo_vazio, descricao_campo_template)
  VALUES (p_tv, pg_temp.campo_id(p_campo), p_ordem, p_nulo, p_desc)
$$;

CREATE FUNCTION pg_temp.md(p_id TEXT, p_versao INT, p_desc TEXT, p_sit TEXT, p_te UUID, p_tv UUID)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, id_template_estrutural, id_template_variavel)
  VALUES (p_id, p_versao, p_desc, p_sit, p_te, p_tv)
$$;

-- ============================================================================
-- Templates e modelos
-- ============================================================================

DO $$
DECLARE
  te UUID;
  tv UUID;
BEGIN
  -- --------------------------------------------------------------------------
  -- COMPPIX v1 (INATIVO): versão antiga, retirada; continua imutável
  -- --------------------------------------------------------------------------
  INSERT INTO catalogo.template_estrutural (nome_template, descricao)
    VALUES ('Estrutura PIX v1', 'Campos obrigatórios do comprovante PIX (primeira versão)') RETURNING id_template_estrutural INTO te;
  PERFORM pg_temp.ae(te, 'id_transacao',          1, 1);
  PERFORM pg_temp.ae(te, 'chave_pix_recebedor',   2, 2);
  PERFORM pg_temp.ae(te, 'data_hora_transacao',   3);
  PERFORM pg_temp.ae(te, 'cpf_pagador',           4);
  PERFORM pg_temp.ae(te, 'valor',                 5, NULL, false, 'Valor pago');
  PERFORM pg_temp.ae(te, 'status_liquidacao',     6);
  PERFORM pg_temp.ae(te, 'instituicao_pagador',   7);
  PERFORM pg_temp.ae(te, 'instituicao_recebedor', 8);

  INSERT INTO catalogo.template_variavel (nome_template, descricao)
    VALUES ('Variáveis PIX v1', 'Campos opcionais do comprovante PIX (primeira versão)') RETURNING id_template_variavel INTO tv;
  PERFORM pg_temp.av(tv, 'motivo_pagamento',  1, true);
  PERFORM pg_temp.av(tv, 'desconto_aplicado', 2, true);
  PERFORM pg_temp.av(tv, 'juros_cobrados',    3, true);

  PERFORM pg_temp.md('COMPPIX', 1, 'Comprovante de Pagamento PIX (v1, retirada)', 'INATIVO', te, tv);

  -- --------------------------------------------------------------------------
  -- COMPPIX v2 (ATIVO): versão vigente. Templates próprios (cópia da v1 + canal_pagamento).
  -- data_hora_transacao aparece no estrutural e no variável, com descrições diferentes.
  -- --------------------------------------------------------------------------
  INSERT INTO catalogo.template_estrutural (nome_template, descricao)
    VALUES ('Estrutura PIX v2', 'Campos obrigatórios do comprovante PIX (versão vigente)') RETURNING id_template_estrutural INTO te;
  PERFORM pg_temp.ae(te, 'id_transacao',          1, 1);
  PERFORM pg_temp.ae(te, 'chave_pix_recebedor',   2, 2);
  PERFORM pg_temp.ae(te, 'data_hora_transacao',   3, NULL, false, 'Data e hora em que o PIX foi efetivado');
  PERFORM pg_temp.ae(te, 'cpf_pagador',           4);
  PERFORM pg_temp.ae(te, 'valor',                 5, NULL, false, 'Valor pago');
  PERFORM pg_temp.ae(te, 'status_liquidacao',     6);
  PERFORM pg_temp.ae(te, 'instituicao_pagador',   7);
  PERFORM pg_temp.ae(te, 'instituicao_recebedor', 8);
  PERFORM pg_temp.ae(te, 'canal_pagamento',       9);

  INSERT INTO catalogo.template_variavel (nome_template, descricao)
    VALUES ('Variáveis PIX v2', 'Campos opcionais do comprovante PIX (versão vigente)') RETURNING id_template_variavel INTO tv;
  PERFORM pg_temp.av(tv, 'motivo_pagamento',    1, true);
  PERFORM pg_temp.av(tv, 'desconto_aplicado',   2, true);
  PERFORM pg_temp.av(tv, 'juros_cobrados',      3, true);
  PERFORM pg_temp.av(tv, 'numero_lote',         4, true);
  PERFORM pg_temp.av(tv, 'data_hora_transacao', 5, true, 'Data e hora do agendamento (quando houver)');

  PERFORM pg_temp.md('COMPPIX', 2, 'Comprovante de Pagamento PIX (v2, vigente)', 'ATIVO', te, tv);

  -- --------------------------------------------------------------------------
  -- COMPPIX v3 (RASCUNHO): em construção. Tem indexador 1, então já pode ser publicada;
  -- os templates ainda são editáveis (só rascunho os referencia).
  -- --------------------------------------------------------------------------
  INSERT INTO catalogo.template_estrutural (nome_template, descricao)
    VALUES ('Estrutura PIX v3 (rascunho)', 'Rascunho da próxima versão do PIX') RETURNING id_template_estrutural INTO te;
  PERFORM pg_temp.ae(te, 'id_transacao',        1, 1);
  PERFORM pg_temp.ae(te, 'chave_pix_recebedor', 2, 2);
  PERFORM pg_temp.ae(te, 'data_hora_transacao', 3);
  PERFORM pg_temp.ae(te, 'valor',               4);

  INSERT INTO catalogo.template_variavel (nome_template)
    VALUES ('Variáveis PIX v3 (rascunho)') RETURNING id_template_variavel INTO tv;
  PERFORM pg_temp.av(tv, 'motivo_pagamento', 1, true);

  PERFORM pg_temp.md('COMPPIX', 3, 'Comprovante de Pagamento PIX (v3, em construção)', 'RASCUNHO', te, tv);

  -- --------------------------------------------------------------------------
  -- COMPTED v1 (ATIVO): estrutural com os 5 indexadores (posições 1 a 5)
  -- --------------------------------------------------------------------------
  INSERT INTO catalogo.template_estrutural (nome_template, descricao)
    VALUES ('Estrutura TED v1', 'Comprovante de TED com os cinco indexadores') RETURNING id_template_estrutural INTO te;
  PERFORM pg_temp.ae(te, 'id_transacao',        1, 1);
  PERFORM pg_temp.ae(te, 'conta_origem',        2, 2);
  PERFORM pg_temp.ae(te, 'conta_destino',       3, 3);
  PERFORM pg_temp.ae(te, 'data_efetivacao',     4, 4);
  PERFORM pg_temp.ae(te, 'valor',               5, 5, false, 'Valor transferido');
  PERFORM pg_temp.ae(te, 'banco_origem',        6);
  PERFORM pg_temp.ae(te, 'agencia_origem',      7);
  PERFORM pg_temp.ae(te, 'banco_destino',       8);
  PERFORM pg_temp.ae(te, 'agencia_destino',     9);
  PERFORM pg_temp.ae(te, 'cpf_pagador',        10);
  PERFORM pg_temp.ae(te, 'status_liquidacao',  11);

  INSERT INTO catalogo.template_variavel (nome_template)
    VALUES ('Variáveis TED v1') RETURNING id_template_variavel INTO tv;
  PERFORM pg_temp.av(tv, 'finalidade_ted',   1, true);
  PERFORM pg_temp.av(tv, 'motivo_pagamento', 2, true);
  PERFORM pg_temp.av(tv, 'numero_lote',      3, true);

  PERFORM pg_temp.md('COMPTED', 1, 'Comprovante de TED (v1)', 'ATIVO', te, tv);

  -- --------------------------------------------------------------------------
  -- COMPBOL v1 (ATIVO): mínimo publicável, só o indexador 1
  -- --------------------------------------------------------------------------
  INSERT INTO catalogo.template_estrutural (nome_template, descricao)
    VALUES ('Estrutura Boleto v1', 'Comprovante de pagamento de boleto, só com o indexador 1') RETURNING id_template_estrutural INTO te;
  PERFORM pg_temp.ae(te, 'codigo_barras',      1, 1);
  PERFORM pg_temp.ae(te, 'data_vencimento',    2);
  PERFORM pg_temp.ae(te, 'data_pagamento',     3);
  PERFORM pg_temp.ae(te, 'valor_nominal',      4);
  PERFORM pg_temp.ae(te, 'valor_pago',         5, NULL, false, 'Valor efetivamente pago');
  PERFORM pg_temp.ae(te, 'beneficiario',       6);
  PERFORM pg_temp.ae(te, 'nome_pagador',       7);
  PERFORM pg_temp.ae(te, 'status_liquidacao',  8);

  INSERT INTO catalogo.template_variavel (nome_template)
    VALUES ('Variáveis Boleto v1') RETURNING id_template_variavel INTO tv;
  PERFORM pg_temp.av(tv, 'juros_cobrados',    1, true);
  PERFORM pg_temp.av(tv, 'desconto_aplicado', 2, true);
  PERFORM pg_temp.av(tv, 'canal_pagamento',   3, true);

  PERFORM pg_temp.md('COMPBOL', 1, 'Comprovante de Pagamento de Boleto (v1)', 'ATIVO', te, tv);

  -- --------------------------------------------------------------------------
  -- COMPBOL v2 (RASCUNHO) SEM indexador 1: só a linha digitável como indexador 2.
  -- Para testar o bloqueio na mão:
  --   UPDATE catalogo.modelo SET situacao = 'ATIVO' WHERE id_modelo = 'COMPBOL' AND versao = 2;
  -- -> erro "Publicação exige indexador na posição 1". Depois de dar o indexador 1 a um campo do
  -- template estrutural (INSERT em template_estrutural_campo), a publicação passa.
  -- --------------------------------------------------------------------------
  INSERT INTO catalogo.template_estrutural (nome_template, descricao)
    VALUES ('Estrutura Boleto v2 (rascunho)', 'Rascunho sem indexador 1: ainda não pode ser publicado') RETURNING id_template_estrutural INTO te;
  PERFORM pg_temp.ae(te, 'linha_digitavel',  1, 2);
  PERFORM pg_temp.ae(te, 'data_vencimento',  2);
  PERFORM pg_temp.ae(te, 'valor_nominal',    3);
  PERFORM pg_temp.ae(te, 'beneficiario',     4);

  INSERT INTO catalogo.template_variavel (nome_template)
    VALUES ('Variáveis Boleto v2 (rascunho)') RETURNING id_template_variavel INTO tv;
  PERFORM pg_temp.av(tv, 'canal_pagamento', 1, true);

  PERFORM pg_temp.md('COMPBOL', 2, 'Comprovante de Pagamento de Boleto (v2, em construção, sem indexador 1)', 'RASCUNHO', te, tv);
END
$$;

-- ============================================================================
-- Confirmação
-- ============================================================================

SELECT 'Seed de inspeção carregado com sucesso' AS mensagem;

SELECT id_modelo, versao, situacao, descricao
  FROM catalogo.modelo
 ORDER BY id_modelo, versao;
