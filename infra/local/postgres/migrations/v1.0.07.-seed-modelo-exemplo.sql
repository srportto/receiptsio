-- v1.0.07.-seed-modelo-exemplo.sql
-- Seed: campos de exemplo, templates estrutural e variável, modelo COMPPIX em duas versões

-- ============================================================================
-- Campos de exemplo
-- ============================================================================

INSERT INTO catalogo.campo (nome_campo, tipo_dado, descricao_base) VALUES
  ('id_transacao', 'UUID', 'Identificador único da transação PIX'),
  ('data_hora_transacao', 'DATA_HORA', 'Data e hora da transação em São Paulo'),
  ('cpf_pagador', 'TEXTO', 'CPF do pagador (sem máscara)'),
  ('chave_pix_recebedor', 'TEXTO', 'Chave PIX do recebedor'),
  ('valor', 'DECIMAL', 'Valor da transação em R$ (formato 10.2)'),
  ('motivo_pagamento', 'TEXTO', 'Motivo ou descrição do pagamento (opcional)'),
  ('status_liquidacao', 'TEXTO', 'LIQUIDADO, FALHA, PENDENTE'),
  ('instituicao_pagador', 'TEXTO', 'Nome da instituição do pagador'),
  ('instituicao_recebedor', 'TEXTO', 'Nome da instituição do recebedor'),
  ('desconto_aplicado', 'DECIMAL', 'Desconto em R$ (opcional, padrão 0)'),
  ('juros_cobrados', 'DECIMAL', 'Juros em R$ (opcional, padrão 0)'),
  ('numero_lote', 'INTEIRO', 'Número sequencial do lote de processamento');

-- ============================================================================
-- Template estrutural: estrutura obrigatória do comprovante PIX
-- ============================================================================

INSERT INTO catalogo.template_estrutural (nome_template) VALUES
  ('Estrutura Comprovante PIX v1')
RETURNING id_template_estrutural AS id_template_est \gset

-- Associar campos ao template estrutural com indexadores
INSERT INTO catalogo.template_estrutural_campo
  (id_template_estrutural, id_campo, ordem, posicao_indexador, aceita_nulo_vazio)
SELECT
  :'id_template_est'::UUID,
  id_campo,
  ordem,
  posicao_indexador,
  aceita_nulo_vazio
FROM (
  VALUES
    -- (id_campo_expr, ordem, posicao_indexador, aceita_nulo_vazio)
    -- Indexador 1: id_transacao (obrigatório para busca)
    ((SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'id_transacao'), 1, 1, FALSE),
    -- Indexador 2: chave_pix_recebedor (busca por recebedor)
    ((SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'chave_pix_recebedor'), 2, 2, FALSE),
    -- Campos estruturais sem indexador
    ((SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'data_hora_transacao'), 3, NULL, FALSE),
    ((SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'cpf_pagador'), 4, NULL, FALSE),
    ((SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'valor'), 5, NULL, FALSE),
    ((SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'status_liquidacao'), 6, NULL, FALSE),
    ((SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'instituicao_pagador'), 7, NULL, FALSE),
    ((SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'instituicao_recebedor'), 8, NULL, FALSE)
) AS t(id_campo, ordem, posicao_indexador, aceita_nulo_vazio)
WHERE t.id_campo IS NOT NULL;

-- ============================================================================
-- Template variável: campos opcionais do comprovante PIX
-- ============================================================================

INSERT INTO catalogo.template_variavel (nome_template) VALUES
  ('Campos Variáveis Comprovante PIX v1')
RETURNING id_template_variavel AS id_template_var \gset

-- Associar campos ao template variável
INSERT INTO catalogo.template_variavel_campo
  (id_template_variavel, id_campo, ordem, aceita_nulo_vazio)
SELECT
  :'id_template_var'::UUID,
  id_campo,
  ordem,
  aceita_nulo_vazio
FROM (
  VALUES
    ((SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'motivo_pagamento'), 1, TRUE),
    ((SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'desconto_aplicado'), 2, TRUE),
    ((SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'juros_cobrados'), 3, TRUE),
    ((SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'numero_lote'), 4, TRUE)
) AS t(id_campo, ordem, aceita_nulo_vazio)
WHERE t.id_campo IS NOT NULL;

-- ============================================================================
-- Modelo COMPPIX em duas versões
-- ============================================================================

-- Versão 1: ATIVO (versão vigente de produção)
INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, id_template_estrutural, id_template_variavel)
VALUES (
  'COMPPIX',
  1,
  'Comprovante de Pagamento PIX (versão 1 - em produção)',
  'ATIVO',
  :'id_template_est'::UUID,
  :'id_template_var'::UUID
);

-- Versão 2: RASCUNHO (em desenvolvimento, não publicada)
INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, id_template_estrutural, id_template_variavel)
VALUES (
  'COMPPIX',
  2,
  'Comprovante de Pagamento PIX (versão 2 - em desenvolvimento)',
  'RASCUNHO',
  :'id_template_est'::UUID,
  :'id_template_var'::UUID
);

-- ============================================================================
-- Confirmação
-- ============================================================================

SELECT 'Seed de exemplo carregada com sucesso' AS mensagem;
SELECT
  COUNT(*) as total_campos,
  (SELECT COUNT(*) FROM catalogo.template_estrutural) as total_templates_estruturais,
  (SELECT COUNT(*) FROM catalogo.template_variavel) as total_templates_variaveis,
  (SELECT COUNT(*) FROM catalogo.modelo) as total_modelos
FROM catalogo.campo;
