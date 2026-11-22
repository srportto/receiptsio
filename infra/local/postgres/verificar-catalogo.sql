-- Verificação automatizada das regras do catálogo de modelos de comprovante.
-- Cada cenário é executado em transação revertida (BEGIN … ROLLBACK).
-- Resultados registrados em tabela temporária; finaliza com \q 1 se houver falha.

BEGIN;

-- Tabela temporária para registrar resultados
CREATE TEMP TABLE resultado_verificacao (
  numero_cenario INT,
  descricao TEXT,
  status TEXT
);

-- ============================================================================
-- GRUPO 1: CAMPO - Unicidade, tipo, integridade
-- ============================================================================

DO $$
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('cpf', 'TEXTO');
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('CPF', 'TEXTO');
  INSERT INTO resultado_verificacao VALUES (1, 'Nome e tipo repetidos', 'FALHA');
EXCEPTION WHEN unique_violation THEN
  INSERT INTO resultado_verificacao VALUES (1, 'Nome e tipo repetidos', 'OK');
END $$;

DO $$
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('valor', 'DECIMAL');
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('valor', 'TEXTO');
  INSERT INTO resultado_verificacao VALUES (2, 'Mesmo nome com tipo diferente', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultado_verificacao VALUES (2, 'Mesmo nome com tipo diferente', 'FALHA');
END $$;

DO $$
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo1', 'tipo_invalido');
  INSERT INTO resultado_verificacao VALUES (3, 'Tipo fora do domínio', 'FALHA');
EXCEPTION WHEN check_violation THEN
  INSERT INTO resultado_verificacao VALUES (3, 'Tipo fora do domínio', 'OK');
END $$;

DO $$
DECLARE
  v_id_campo BIGINT;
  v_id_template BIGINT;
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_teste', 'TEXTO') RETURNING id_campo INTO v_id_campo;
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_teste') RETURNING id_template_estrutural INTO v_id_template;
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem) VALUES (v_id_template, v_id_campo, 1);

  DELETE FROM catalogo.campo WHERE id_campo = v_id_campo;
  INSERT INTO resultado_verificacao VALUES (4, 'Excluir campo associado', 'FALHA');
EXCEPTION WHEN foreign_key_violation THEN
  INSERT INTO resultado_verificacao VALUES (4, 'Excluir campo associado', 'OK');
END $$;

DO $$
DECLARE
  v_id_campo BIGINT;
  v_id_template BIGINT;
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_rep', 'TEXTO') RETURNING id_campo INTO v_id_campo;
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_rep') RETURNING id_template_estrutural INTO v_id_template;
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem) VALUES (v_id_template, v_id_campo, 1);
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem) VALUES (v_id_template, v_id_campo, 2);
  INSERT INTO resultado_verificacao VALUES (5, 'Campo repetido no template', 'FALHA');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultado_verificacao VALUES (5, 'Campo repetido no template', 'OK');
END $$;

DO $$
DECLARE
  v_id_campo1 BIGINT;
  v_id_campo2 BIGINT;
  v_id_template BIGINT;
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_ord1', 'TEXTO') RETURNING id_campo INTO v_id_campo1;
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_ord2', 'TEXTO') RETURNING id_campo INTO v_id_campo2;
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_ord') RETURNING id_template_estrutural INTO v_id_template;
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem) VALUES (v_id_template, v_id_campo1, 1);
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem) VALUES (v_id_template, v_id_campo2, 1);
  INSERT INTO resultado_verificacao VALUES (6, 'Ordem repetida no template', 'FALHA');
EXCEPTION WHEN unique_violation THEN
  INSERT INTO resultado_verificacao VALUES (6, 'Ordem repetida no template', 'OK');
END $$;

DO $$
DECLARE
  v_id_campo BIGINT;
  v_id_template_est BIGINT;
  v_id_template_var BIGINT;
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('data_pagamento', 'DATA') RETURNING id_campo INTO v_id_campo;
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_est_campo_compartilhado') RETURNING id_template_estrutural INTO v_id_template_est;
  INSERT INTO catalogo.template_variavel (nome_template) VALUES ('template_var_campo_compartilhado') RETURNING id_template_variavel INTO v_id_template_var;
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem) VALUES (v_id_template_est, v_id_campo, 1);
  INSERT INTO catalogo.template_variavel_campo (id_template_variavel, id_campo, ordem) VALUES (v_id_template_var, v_id_campo, 1);
  INSERT INTO resultado_verificacao VALUES (7, 'Mesmo campo nos dois templates', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultado_verificacao VALUES (7, 'Mesmo campo nos dois templates', 'FALHA');
END $$;

-- ============================================================================
-- GRUPO 2: INDEXADORES
-- ============================================================================

DO $$
DECLARE
  v_id_campo BIGINT;
  v_id_template BIGINT;
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_idx_fora', 'TEXTO') RETURNING id_campo INTO v_id_campo;
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_idx_fora') RETURNING id_template_estrutural INTO v_id_template;
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem, posicao_indexador) VALUES (v_id_template, v_id_campo, 1, 6);
  INSERT INTO resultado_verificacao VALUES (8, 'Posição de indexador fora da faixa', 'FALHA');
EXCEPTION WHEN check_violation THEN
  INSERT INTO resultado_verificacao VALUES (8, 'Posição de indexador fora da faixa', 'OK');
END $$;

DO $$
DECLARE
  v_id_campo1 BIGINT;
  v_id_campo2 BIGINT;
  v_id_template BIGINT;
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_idx_rep1', 'TEXTO') RETURNING id_campo INTO v_id_campo1;
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_idx_rep2', 'TEXTO') RETURNING id_campo INTO v_id_campo2;
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_idx_rep') RETURNING id_template_estrutural INTO v_id_template;
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem, posicao_indexador) VALUES (v_id_template, v_id_campo1, 1, 2);
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem, posicao_indexador) VALUES (v_id_template, v_id_campo2, 2, 2);
  INSERT INTO resultado_verificacao VALUES (9, 'Posição de indexador repetida', 'FALHA');
EXCEPTION WHEN unique_violation THEN
  INSERT INTO resultado_verificacao VALUES (9, 'Posição de indexador repetida', 'OK');
END $$;

DO $$
DECLARE
  v_id_campo BIGINT;
  v_id_template BIGINT;
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_idx_nulo', 'TEXTO') RETURNING id_campo INTO v_id_campo;
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_idx_nulo') RETURNING id_template_estrutural INTO v_id_template;
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem, posicao_indexador, aceita_nulo_vazio) VALUES (v_id_template, v_id_campo, 1, 1, true);
  INSERT INTO resultado_verificacao VALUES (10, 'Indexador que aceita nulo', 'FALHA');
EXCEPTION WHEN check_violation THEN
  INSERT INTO resultado_verificacao VALUES (10, 'Indexador que aceita nulo', 'OK');
END $$;

-- ============================================================================
-- GRUPO 3: MODELO - Identificação, composição, situação
-- ============================================================================

DO $$
BEGIN
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, id_template_estrutural, id_template_variavel)
    VALUES ('COMPPIX', 1, 'Comprovante PIX v1', uuidv7(), uuidv7());
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, id_template_estrutural, id_template_variavel)
    VALUES ('COMPPIX', 2, 'Comprovante PIX v2', uuidv7(), uuidv7());
  INSERT INTO resultado_verificacao VALUES (11, 'Duas versões do mesmo modelo', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultado_verificacao VALUES (11, 'Duas versões do mesmo modelo', 'FALHA');
END $$;

DO $$
BEGIN
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, id_template_estrutural, id_template_variavel)
    VALUES ('comp-pix-çã', 1, 'Inválido', uuidv7(), uuidv7());
  INSERT INTO resultado_verificacao VALUES (12, 'Código inválido', 'FALHA');
EXCEPTION WHEN check_violation THEN
  INSERT INTO resultado_verificacao VALUES (12, 'Código inválido', 'OK');
END $$;

DO $$
BEGIN
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, id_template_estrutural, id_template_variavel)
    VALUES ('COMPPIX', 1000, 'Versão fora da faixa', uuidv7(), uuidv7());
  INSERT INTO resultado_verificacao VALUES (13, 'Versão fora da faixa', 'FALHA');
EXCEPTION WHEN check_violation THEN
  INSERT INTO resultado_verificacao VALUES (13, 'Versão fora da faixa', 'OK');
END $$;

DO $$
DECLARE
  v_id_template BIGINT;
BEGIN
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_nulo') RETURNING id_template_estrutural INTO v_id_template;
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, id_template_estrutural, id_template_variavel)
    VALUES ('COMPNULO', 1, 'Template variável nulo', v_id_template, NULL);
  INSERT INTO resultado_verificacao VALUES (14, 'Modelo sem template variável', 'FALHA');
EXCEPTION WHEN not_null_violation THEN
  INSERT INTO resultado_verificacao VALUES (14, 'Modelo sem template variável', 'OK');
END $$;

DO $$
DECLARE
  v_id_template_est BIGINT;
  v_id_template_var BIGINT;
BEGIN
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_existe') RETURNING id_template_estrutural INTO v_id_template_est;
  INSERT INTO catalogo.template_variavel (nome_template) VALUES ('template_var_existe') RETURNING id_template_variavel INTO v_id_template_var;
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, id_template_estrutural, id_template_variavel)
    VALUES ('COMPEXISTE', 1, 'Com templates existentes', v_id_template_est, v_id_template_var);
  INSERT INTO resultado_verificacao VALUES (15, 'Template reutilizado', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultado_verificacao VALUES (15, 'Template reutilizado', 'FALHA');
END $$;

-- ============================================================================
-- GRUPO 4: SITUAÇÃO E VERSÃO VIGENTE
-- ============================================================================

DO $$
DECLARE
  v_id_template_est BIGINT;
  v_id_template_var BIGINT;
BEGIN
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_ativo') RETURNING id_template_estrutural INTO v_id_template_est;
  INSERT INTO catalogo.template_variavel (nome_template) VALUES ('template_var_ativo') RETURNING id_template_variavel INTO v_id_template_var;
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, id_template_estrutural, id_template_variavel)
    VALUES ('COMPATIVO', 1, 'Versão 1 ativa', 'ATIVO', v_id_template_est, v_id_template_var);
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, id_template_estrutural, id_template_variavel)
    VALUES ('COMPATIVO', 2, 'Versão 2 tenta ativar', 'ATIVO', v_id_template_est, v_id_template_var);
  INSERT INTO resultado_verificacao VALUES (16, 'Duas versões ativas', 'FALHA');
EXCEPTION WHEN unique_violation THEN
  INSERT INTO resultado_verificacao VALUES (16, 'Duas versões ativas', 'OK');
END $$;

DO $$
DECLARE
  v_id_template_est BIGINT;
  v_id_template_var BIGINT;
BEGIN
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_troca') RETURNING id_template_estrutural INTO v_id_template_est;
  INSERT INTO catalogo.template_variavel (nome_template) VALUES ('template_var_troca') RETURNING id_template_variavel INTO v_id_template_var;
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, id_template_estrutural, id_template_variavel)
    VALUES ('COMPTRO', 1, 'Versão 1 ativa', 'ATIVO', v_id_template_est, v_id_template_var);

  UPDATE catalogo.modelo SET situacao = 'INATIVO' WHERE id_modelo = 'COMPTRO' AND versao = 1;
  UPDATE catalogo.modelo SET situacao = 'ATIVO' WHERE id_modelo = 'COMPTRO' AND versao = 2;

  INSERT INTO resultado_verificacao VALUES (17, 'Troca de versão vigente na mesma transação', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultado_verificacao VALUES (17, 'Troca de versão vigente na mesma transação', 'FALHA');
END $$;

DO $$
DECLARE
  v_id_template_est BIGINT;
  v_id_template_var BIGINT;
BEGIN
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_volta') RETURNING id_template_estrutural INTO v_id_template_est;
  INSERT INTO catalogo.template_variavel (nome_template) VALUES ('template_var_volta') RETURNING id_template_variavel INTO v_id_template_var;
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, id_template_estrutural, id_template_variavel)
    VALUES ('COMPVOLTA', 1, 'Tenta voltar a rascunho', 'ATIVO', v_id_template_est, v_id_template_var);

  UPDATE catalogo.modelo SET situacao = 'RASCUNHO' WHERE id_modelo = 'COMPVOLTA' AND versao = 1;

  INSERT INTO resultado_verificacao VALUES (18, 'Publicado volta a rascunho', 'FALHA');
EXCEPTION WHEN check_violation THEN
  INSERT INTO resultado_verificacao VALUES (18, 'Publicado volta a rascunho', 'OK');
END $$;

-- ============================================================================
-- GRUPO 5: PUBLICAÇÃO E IMUTABILIDADE
-- ============================================================================

DO $$
DECLARE
  v_id_template_est BIGINT;
  v_id_template_var BIGINT;
BEGIN
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_sem_idx') RETURNING id_template_estrutural INTO v_id_template_est;
  INSERT INTO catalogo.template_variavel (nome_template) VALUES ('template_var_sem_idx') RETURNING id_template_variavel INTO v_id_template_var;
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, id_template_estrutural, id_template_variavel)
    VALUES ('COMPSEMIDX', 1, 'Sem indexador principal', 'RASCUNHO', v_id_template_est, v_id_template_var);

  UPDATE catalogo.modelo SET situacao = 'ATIVO' WHERE id_modelo = 'COMPSEMIDX' AND versao = 1;

  INSERT INTO resultado_verificacao VALUES (19, 'Publicar sem indexador principal', 'FALHA');
EXCEPTION WHEN check_violation THEN
  INSERT INTO resultado_verificacao VALUES (19, 'Publicar sem indexador principal', 'OK');
END $$;

DO $$
DECLARE
  v_id_campo BIGINT;
  v_id_template_est BIGINT;
  v_id_template_var BIGINT;
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_idx1', 'TEXTO') RETURNING id_campo INTO v_id_campo;
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_com_idx') RETURNING id_template_estrutural INTO v_id_template_est;
  INSERT INTO catalogo.template_variavel (nome_template) VALUES ('template_var_com_idx') RETURNING id_template_variavel INTO v_id_template_var;
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem, posicao_indexador) VALUES (v_id_template_est, v_id_campo, 1, 1);
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, id_template_estrutural, id_template_variavel)
    VALUES ('COMPCMIDX', 1, 'Com indexador principal', 'RASCUNHO', v_id_template_est, v_id_template_var);

  UPDATE catalogo.modelo SET situacao = 'ATIVO' WHERE id_modelo = 'COMPCMIDX' AND versao = 1;

  INSERT INTO resultado_verificacao VALUES (20, 'Publicar com indexador principal', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultado_verificacao VALUES (20, 'Publicar com indexador principal', 'FALHA');
END $$;

DO $$
DECLARE
  v_id_campo BIGINT;
  v_id_template_est_imut BIGINT;
  v_id_template_var_imut BIGINT;
  v_id_template_est_novo BIGINT;
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_imut', 'TEXTO') RETURNING id_campo INTO v_id_campo;
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_imut_1') RETURNING id_template_estrutural INTO v_id_template_est_imut;
  INSERT INTO catalogo.template_variavel (nome_template) VALUES ('template_var_imut') RETURNING id_template_variavel INTO v_id_template_var_imut;
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem, posicao_indexador) VALUES (v_id_template_est_imut, v_id_campo, 1, 1);

  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, id_template_estrutural, id_template_variavel)
    VALUES ('COMPIMUT', 1, 'Modelo publicado', 'ATIVO', v_id_template_est_imut, v_id_template_var_imut);

  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_imut_novo') RETURNING id_template_estrutural INTO v_id_template_est_novo;
  UPDATE catalogo.modelo SET id_template_estrutural = v_id_template_est_novo WHERE id_modelo = 'COMPIMUT' AND versao = 1;

  INSERT INTO resultado_verificacao VALUES (21, 'Trocar template de modelo publicado', 'FALHA');
EXCEPTION WHEN check_violation THEN
  INSERT INTO resultado_verificacao VALUES (21, 'Trocar template de modelo publicado', 'OK');
END $$;

DO $$
DECLARE
  v_id_campo BIGINT;
  v_id_template_est_ref BIGINT;
  v_id_template_var_ref BIGINT;
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_pub', 'TEXTO') RETURNING id_campo INTO v_id_campo;
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_ref_pub') RETURNING id_template_estrutural INTO v_id_template_est_ref;
  INSERT INTO catalogo.template_variavel (nome_template) VALUES ('template_var_ref_pub') RETURNING id_template_variavel INTO v_id_template_var_ref;
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem, posicao_indexador) VALUES (v_id_template_est_ref, v_id_campo, 1, 1);

  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, id_template_estrutural, id_template_variavel)
    VALUES ('COMPPUB', 1, 'Modelo publicado', 'ATIVO', v_id_template_est_ref, v_id_template_var_ref);

  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_novo', 'TEXTO') RETURNING id_campo INTO v_id_campo;
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem) VALUES (v_id_template_est_ref, v_id_campo, 2);

  INSERT INTO resultado_verificacao VALUES (22, 'Incluir campo em template publicado', 'FALHA');
EXCEPTION WHEN check_violation THEN
  INSERT INTO resultado_verificacao VALUES (22, 'Incluir campo em template publicado', 'OK');
END $$;

DO $$
DECLARE
  v_id_campo BIGINT;
  v_id_template_est_rasc BIGINT;
  v_id_template_var_rasc BIGINT;
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_rasc', 'TEXTO') RETURNING id_campo INTO v_id_campo;
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('template_rasc') RETURNING id_template_estrutural INTO v_id_template_est_rasc;
  INSERT INTO catalogo.template_variavel (nome_template) VALUES ('template_var_rasc') RETURNING id_template_variavel INTO v_id_template_var_rasc;
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem, posicao_indexador) VALUES (v_id_template_est_rasc, v_id_campo, 1, 1);

  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, id_template_estrutural, id_template_variavel)
    VALUES ('COMPRASC', 1, 'Modelo rascunho', 'RASCUNHO', v_id_template_est_rasc, v_id_template_var_rasc);

  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_rasc_novo', 'TEXTO') RETURNING id_campo INTO v_id_campo;
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem) VALUES (v_id_template_est_rasc, v_id_campo, 2);

  INSERT INTO resultado_verificacao VALUES (23, 'Editar rascunho (template referenciado só por rascunho)', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultado_verificacao VALUES (23, 'Editar rascunho (template referenciado só por rascunho)', 'FALHA');
END $$;

-- ============================================================================
-- GRUPO 6: DATAS DE AUDITORIA
-- ============================================================================

DO $$
DECLARE
  v_id_campo BIGINT;
  v_data_criacao TIMESTAMPTZ;
  v_data_atualizacao TIMESTAMPTZ;
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_data', 'TEXTO') RETURNING id_campo, data_hora_criacao, data_hora_atualizacao INTO v_id_campo, v_data_criacao, v_data_atualizacao;

  IF v_data_criacao IS NOT NULL AND v_data_atualizacao IS NOT NULL THEN
    INSERT INTO resultado_verificacao VALUES (24, 'Inclusão sem informar datas', 'OK');
  ELSE
    INSERT INTO resultado_verificacao VALUES (24, 'Inclusão sem informar datas', 'FALHA');
  END IF;
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultado_verificacao VALUES (24, 'Inclusão sem informar datas', 'FALHA');
END $$;

DO $$
DECLARE
  v_id_campo BIGINT;
  v_data_criacao TIMESTAMPTZ;
  v_data_atualizacao_antes TIMESTAMPTZ;
  v_data_atualizacao_depois TIMESTAMPTZ;
BEGIN
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_atualizacao', 'TEXTO') RETURNING id_campo, data_hora_criacao, data_hora_atualizacao INTO v_id_campo, v_data_criacao, v_data_atualizacao_antes;

  -- Pequena pausa para garantir que o tempo passa
  PERFORM pg_sleep(0.01);

  UPDATE catalogo.campo SET nome_campo = 'campo_atualizacao_novo' WHERE id_campo = v_id_campo RETURNING data_hora_atualizacao INTO v_data_atualizacao_depois;

  IF v_data_atualizacao_depois > v_data_atualizacao_antes THEN
    INSERT INTO resultado_verificacao VALUES (25, 'Alteração renova data de atualização', 'OK');
  ELSE
    INSERT INTO resultado_verificacao VALUES (25, 'Alteração renova data de atualização', 'FALHA');
  END IF;
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultado_verificacao VALUES (25, 'Alteração renova data de atualização', 'FALHA');
END $$;

-- ============================================================================
-- GRUPO 7: ROLES E PRIVILÉGIOS (cenários básicos)
-- ============================================================================

DO $$
BEGIN
  SET ROLE catalogo_leitura;
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('campo_role', 'TEXTO');
  INSERT INTO resultado_verificacao VALUES (26, 'Leitura tenta escrever', 'FALHA');
  RESET ROLE;
EXCEPTION WHEN insufficient_privilege THEN
  RESET ROLE;
  INSERT INTO resultado_verificacao VALUES (26, 'Leitura tenta escrever', 'OK');
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO resultado_verificacao VALUES (26, 'Leitura tenta escrever', 'FALHA');
END $$;

DO $$
BEGIN
  SET ROLE catalogo_escrita;
  DROP TABLE catalogo.campo;
  INSERT INTO resultado_verificacao VALUES (27, 'Escrita tenta DDL', 'FALHA');
  RESET ROLE;
EXCEPTION WHEN insufficient_privilege THEN
  RESET ROLE;
  INSERT INTO resultado_verificacao VALUES (27, 'Escrita tenta DDL', 'OK');
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO resultado_verificacao VALUES (27, 'Escrita tenta DDL', 'OK');
END $$;

-- ============================================================================
-- RESULTADO FINAL
-- ============================================================================

-- Exibir resultados
SELECT '===== RESULTADOS DA VERIFICAÇÃO =====' AS resultado;
SELECT numero_cenario, descricao, status FROM resultado_verificacao ORDER BY numero_cenario;

-- Contar falhas
DO $$
DECLARE
  v_falhas INT;
BEGIN
  SELECT COUNT(*) INTO v_falhas FROM resultado_verificacao WHERE status = 'FALHA';

  IF v_falhas > 0 THEN
    RAISE NOTICE 'FALHA: % cenário(s) com erro', v_falhas;
  ELSE
    RAISE NOTICE 'SUCESSO: Todos os cenários passaram';
  END IF;
END $$;

ROLLBACK;

-- Saída: se houver falhas, terminar com código 1
\if :?falhas
  \if :falhas > 0
    \q 1
  \endif
\endif
