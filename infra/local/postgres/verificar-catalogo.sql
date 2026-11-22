-- verificar-catalogo.sql
-- Verificação automatizada das regras do catálogo de modelos de comprovante.
--
-- Como funciona:
--   * tudo roda numa única transação que termina em ROLLBACK (nenhum dado fica);
--   * cada cenário roda numa subtransação isolada (um não afeta o outro);
--   * cenário de rejeição confere o SQLSTATE EXATO esperado; outro erro (ou nenhum erro) é FALHA;
--   * os dados de teste usam prefixo VER_/ver_ e não colidem com o seed;
--   * termina com código de saída diferente de zero (3) se algum cenário falhar.
--
-- Uso (a partir de infra/local/postgres, com DB_NAME e DB_USER_NAME do .env):
--   docker exec -i postgres18-receiptsio psql -v ON_ERROR_STOP=1 -U "$DB_USER_NAME" -d "$DB_NAME" < verificar-catalogo.sql
--   echo "saida=$?"

BEGIN;

SET search_path = catalogo, public;

CREATE TEMP TABLE resultado (
  numero    SERIAL,
  descricao TEXT,
  status    TEXT,
  detalhe   TEXT
);

-- ============================================================================
-- Funções auxiliares de execução de cenário
-- ============================================================================

-- Executa o corpo (bloco plpgsql completo) e exige o SQLSTATE exato esperado.
-- Se p_msg for informado, a mensagem do erro precisa casar com o padrão LIKE.
CREATE FUNCTION pg_temp.esperar_erro(p_desc TEXT, p_corpo TEXT, p_sqlstate TEXT, p_msg TEXT DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  BEGIN
    EXECUTE 'DO $c$ ' || p_corpo || ' $c$';
    -- sentinela: se nada falhou, desfaz o cenário e reporta falha
    RAISE EXCEPTION 'sem erro' USING ERRCODE = 'ZZ001';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = 'ZZ001' THEN
      INSERT INTO resultado (descricao, status, detalhe)
      VALUES (p_desc, 'FALHA', 'esperava SQLSTATE ' || p_sqlstate || ' mas nenhum erro ocorreu');
    ELSIF SQLSTATE <> p_sqlstate THEN
      INSERT INTO resultado (descricao, status, detalhe)
      VALUES (p_desc, 'FALHA', 'esperava SQLSTATE ' || p_sqlstate || ' e veio ' || SQLSTATE || ': ' || SQLERRM);
    ELSIF p_msg IS NOT NULL AND SQLERRM NOT LIKE p_msg THEN
      INSERT INTO resultado (descricao, status, detalhe)
      VALUES (p_desc, 'FALHA', 'SQLSTATE certo, mas a mensagem "' || SQLERRM || '" não casa com ' || p_msg);
    ELSE
      INSERT INTO resultado (descricao, status, detalhe) VALUES (p_desc, 'OK', NULL);
    END IF;
  END;
END $f$;

-- Executa o corpo e exige que termine sem erro; desfaz tudo ao final do cenário.
CREATE FUNCTION pg_temp.esperar_sucesso(p_desc TEXT, p_corpo TEXT)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  BEGIN
    EXECUTE 'DO $c$ ' || p_corpo || ' $c$';
    RAISE EXCEPTION 'ok' USING ERRCODE = 'ZZ002';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = 'ZZ002' THEN
      INSERT INTO resultado (descricao, status, detalhe) VALUES (p_desc, 'OK', NULL);
    ELSE
      INSERT INTO resultado (descricao, status, detalhe)
      VALUES (p_desc, 'FALHA', 'erro inesperado ' || SQLSTATE || ': ' || SQLERRM);
    END IF;
  END;
END $f$;

-- ============================================================================
-- Funções auxiliares de montagem de dados
-- ============================================================================

CREATE FUNCTION pg_temp.campo(p_nome TEXT, p_tipo TEXT DEFAULT 'TEXTO') RETURNS BIGINT LANGUAGE sql AS $f$
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES (p_nome, p_tipo) RETURNING id_campo
$f$;

CREATE FUNCTION pg_temp.te(p_nome TEXT) RETURNS UUID LANGUAGE sql AS $f$
  INSERT INTO catalogo.template_estrutural (nome_template) VALUES (p_nome) RETURNING id_template_estrutural
$f$;

CREATE FUNCTION pg_temp.tv(p_nome TEXT) RETURNS UUID LANGUAGE sql AS $f$
  INSERT INTO catalogo.template_variavel (nome_template) VALUES (p_nome) RETURNING id_template_variavel
$f$;

CREATE FUNCTION pg_temp.ae(p_te UUID, p_campo BIGINT, p_ordem INT, p_idx INT DEFAULT NULL, p_nulo BOOLEAN DEFAULT false)
RETURNS void LANGUAGE sql AS $f$
  INSERT INTO catalogo.template_estrutural_campo
    (id_template_estrutural, id_campo, ordem, posicao_indexador, aceita_nulo_vazio)
  VALUES (p_te, p_campo, p_ordem, p_idx, p_nulo)
$f$;

CREATE FUNCTION pg_temp.av(p_tv UUID, p_campo BIGINT, p_ordem INT, p_nulo BOOLEAN DEFAULT false)
RETURNS void LANGUAGE sql AS $f$
  INSERT INTO catalogo.template_variavel_campo (id_template_variavel, id_campo, ordem, aceita_nulo_vazio)
  VALUES (p_tv, p_campo, p_ordem, p_nulo)
$f$;

CREATE FUNCTION pg_temp.md(p_id TEXT, p_versao INT, p_sit TEXT, p_te UUID, p_tv UUID) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, id_template_estrutural, id_template_variavel)
  VALUES (p_id, p_versao, 'verificacao', p_sit, p_te, p_tv)
$f$;

-- Template estrutural já com indexador na posição 1 (pronto para publicar).
CREATE FUNCTION pg_temp.te_com_idx(p_nome TEXT) RETURNS UUID LANGUAGE plpgsql AS $f$
DECLARE v_te UUID;
BEGIN
  v_te := pg_temp.te(p_nome);
  PERFORM pg_temp.ae(v_te, pg_temp.campo(p_nome || '_i1'), 1, 1);
  RETURN v_te;
END $f$;

-- ============================================================================
-- GRUPO 1: CAMPO
-- ============================================================================

SELECT pg_temp.esperar_erro('Campo: nome e tipo repetidos (sem distinguir maiúsculas)',
$s$ BEGIN PERFORM pg_temp.campo('ver_cpf'); PERFORM pg_temp.campo('VER_CPF'); END; $s$, '23505');

SELECT pg_temp.esperar_sucesso('Campo: mesmo nome com tipo diferente é aceito',
$s$ BEGIN PERFORM pg_temp.campo('ver_valor', 'DECIMAL'); PERFORM pg_temp.campo('ver_valor', 'TEXTO'); END; $s$);

SELECT pg_temp.esperar_erro('Campo: tipo fora do domínio',
$s$ BEGIN PERFORM pg_temp.campo('ver_x', 'tipo_invalido'); END; $s$, '23514');

SELECT pg_temp.esperar_erro('Campo: nome vazio',
$s$ BEGIN PERFORM pg_temp.campo('   '); END; $s$, '23514');

SELECT pg_temp.esperar_erro('Campo: excluir campo associado a template',
$s$ DECLARE c BIGINT; t UUID;
BEGIN
  c := pg_temp.campo('ver_del'); t := pg_temp.te('VER te del');
  PERFORM pg_temp.ae(t, c, 1);
  DELETE FROM catalogo.campo WHERE id_campo = c;
END; $s$, '23001');

SELECT pg_temp.esperar_erro('Template: campo repetido no mesmo template',
$s$ DECLARE c BIGINT; t UUID;
BEGIN
  c := pg_temp.campo('ver_rep'); t := pg_temp.te('VER te rep');
  PERFORM pg_temp.ae(t, c, 1); PERFORM pg_temp.ae(t, c, 2);
END; $s$, '23505');

SELECT pg_temp.esperar_erro('Template: ordem repetida no mesmo template',
$s$ DECLARE t UUID;
BEGIN
  t := pg_temp.te('VER te ord');
  PERFORM pg_temp.ae(t, pg_temp.campo('ver_o1'), 1); PERFORM pg_temp.ae(t, pg_temp.campo('ver_o2'), 1);
END; $s$, '23505');

SELECT pg_temp.esperar_erro('Template: ordem menor que 1',
$s$ DECLARE t UUID;
BEGIN
  t := pg_temp.te('VER te ord0'); PERFORM pg_temp.ae(t, pg_temp.campo('ver_o0'), 0);
END; $s$, '23514');

SELECT pg_temp.esperar_sucesso('Template: mesmo campo nos templates estrutural e variável',
$s$ DECLARE c BIGINT;
BEGIN
  c := pg_temp.campo('ver_comp', 'DATA');
  PERFORM pg_temp.ae(pg_temp.te('VER te comp'), c, 1);
  PERFORM pg_temp.av(pg_temp.tv('VER tv comp'), c, 1);
END; $s$);

-- ============================================================================
-- GRUPO 2: INDEXADORES
-- ============================================================================

SELECT pg_temp.esperar_erro('Indexador: posição fora da faixa (6)',
$s$ DECLARE t UUID;
BEGIN
  t := pg_temp.te('VER te idx6'); PERFORM pg_temp.ae(t, pg_temp.campo('ver_i6'), 1, 6);
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Indexador: posição repetida no template',
$s$ DECLARE t UUID;
BEGIN
  t := pg_temp.te('VER te idxrep');
  PERFORM pg_temp.ae(t, pg_temp.campo('ver_ir1'), 1, 2); PERFORM pg_temp.ae(t, pg_temp.campo('ver_ir2'), 2, 2);
END; $s$, '23505');

SELECT pg_temp.esperar_erro('Indexador: campo indexador não aceita nulo/vazio',
$s$ DECLARE t UUID;
BEGIN
  t := pg_temp.te('VER te idxnulo'); PERFORM pg_temp.ae(t, pg_temp.campo('ver_in'), 1, 1, true);
END; $s$, '23514');

SELECT pg_temp.esperar_sucesso('Indexador: posições 1 a 5 aceitas num mesmo template',
$s$ DECLARE t UUID; i INT;
BEGIN
  t := pg_temp.te('VER te idx15');
  FOR i IN 1..5 LOOP PERFORM pg_temp.ae(t, pg_temp.campo('ver_p' || i), i, i); END LOOP;
END; $s$);

-- ============================================================================
-- GRUPO 3: TEMPLATES (nome e descrição)
-- ============================================================================

SELECT pg_temp.esperar_erro('Template estrutural: nome vazio',
$s$ BEGIN PERFORM pg_temp.te('  '); END; $s$, '23514');

SELECT pg_temp.esperar_erro('Template variável: nome vazio',
$s$ BEGIN PERFORM pg_temp.tv(''); END; $s$, '23514');

SELECT pg_temp.esperar_sucesso('Template: descrição é opcional',
$s$ DECLARE t UUID; d TEXT;
BEGIN
  t := pg_temp.te('VER te semdesc');
  SELECT descricao INTO d FROM catalogo.template_estrutural WHERE id_template_estrutural = t;
  IF d IS NOT NULL THEN RAISE EXCEPTION 'descricao deveria ser nula'; END IF;
END; $s$);

SELECT pg_temp.esperar_sucesso('Template: descrição efetiva do campo (própria ou herdada do campo)',
$s$ DECLARE c1 BIGINT; c2 BIGINT; t UUID; v UUID; j JSONB;
BEGIN
  c1 := pg_temp.campo('ver_d1'); c2 := pg_temp.campo('ver_d2');
  UPDATE catalogo.campo SET descricao_base = 'Base do campo' WHERE id_campo IN (c1, c2);
  t := pg_temp.te('VER te desc'); v := pg_temp.tv('VER tv desc');
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem, descricao_campo_template)
    VALUES (t, c1, 1, 'Valor da parcela');
  PERFORM pg_temp.ae(t, c2, 2);
  PERFORM pg_temp.md('VER_DESC', 1, 'RASCUNHO', t, v);
  SELECT campos_estruturais INTO j FROM catalogo.vw_modelo_completo WHERE id_modelo = 'VER_DESC' AND versao = 1;
  IF j -> 0 ->> 'descricao_efetiva' <> 'Valor da parcela' THEN RAISE EXCEPTION 'efetiva 1 = %', j -> 0 ->> 'descricao_efetiva'; END IF;
  IF j -> 1 ->> 'descricao_efetiva' <> 'Base do campo' THEN RAISE EXCEPTION 'efetiva 2 = %', j -> 1 ->> 'descricao_efetiva'; END IF;
END; $s$);

-- ============================================================================
-- GRUPO 4: MODELO (identificação e composição)
-- ============================================================================

SELECT pg_temp.esperar_sucesso('Modelo: duas versões do mesmo código',
$s$ DECLARE t UUID; v UUID;
BEGIN
  t := pg_temp.te('VER te m2'); v := pg_temp.tv('VER tv m2');
  PERFORM pg_temp.md('VER_A', 1, 'RASCUNHO', t, v); PERFORM pg_temp.md('VER_A', 2, 'RASCUNHO', t, v);
END; $s$);

SELECT pg_temp.esperar_erro('Modelo: código com caracteres inválidos',
$s$ BEGIN PERFORM pg_temp.md('VER-A', 1, 'RASCUNHO', pg_temp.te('VER te ci'), pg_temp.tv('VER tv ci')); END; $s$, '23514');

SELECT pg_temp.esperar_erro('Modelo: código com mais de 10 caracteres',
$s$ BEGIN PERFORM pg_temp.md('VER_ABCDEFGH', 1, 'RASCUNHO', pg_temp.te('VER te c11'), pg_temp.tv('VER tv c11')); END; $s$, '22001');

SELECT pg_temp.esperar_erro('Modelo: versão fora da faixa (1000)',
$s$ BEGIN PERFORM pg_temp.md('VER_A', 1000, 'RASCUNHO', pg_temp.te('VER te v1000'), pg_temp.tv('VER tv v1000')); END; $s$, '23514');

SELECT pg_temp.esperar_erro('Modelo: sem template variável',
$s$ BEGIN
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, id_template_estrutural, id_template_variavel)
  VALUES ('VER_NULO', 1, 'x', pg_temp.te('VER te nulo'), NULL);
END; $s$, '23502');

SELECT pg_temp.esperar_erro('Modelo: template inexistente',
$s$ BEGIN
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, id_template_estrutural, id_template_variavel)
  VALUES ('VER_INEX', 1, 'x', uuidv7(), pg_temp.tv('VER tv inex'));
END; $s$, '23503');

SELECT pg_temp.esperar_sucesso('Modelo: template reutilizado por dois modelos',
$s$ DECLARE t UUID; v UUID;
BEGIN
  t := pg_temp.te('VER te reuso'); v := pg_temp.tv('VER tv reuso');
  PERFORM pg_temp.md('VER_R1', 1, 'RASCUNHO', t, v); PERFORM pg_temp.md('VER_R2', 1, 'RASCUNHO', t, v);
END; $s$);

SELECT pg_temp.esperar_erro('Modelo: situação fora do domínio',
$s$ BEGIN PERFORM pg_temp.md('VER_S', 1, 'FOO', pg_temp.te('VER te sfoo'), pg_temp.tv('VER tv sfoo')); END; $s$, '23514');

SELECT pg_temp.esperar_sucesso('Modelo: situação padrão é RASCUNHO e data_version começa em 0',
$s$ DECLARE s TEXT; dv BIGINT;
BEGIN
  INSERT INTO catalogo.modelo (id_modelo, versao, descricao, id_template_estrutural, id_template_variavel)
  VALUES ('VER_PAD', 1, 'x', pg_temp.te('VER te pad'), pg_temp.tv('VER tv pad'));
  SELECT situacao, data_version INTO s, dv FROM catalogo.modelo WHERE id_modelo = 'VER_PAD';
  IF s <> 'RASCUNHO' OR dv <> 0 THEN RAISE EXCEPTION 'situacao=% data_version=%', s, dv; END IF;
END; $s$);

-- ============================================================================
-- GRUPO 5: SITUAÇÃO E VERSÃO VIGENTE
-- ============================================================================

SELECT pg_temp.esperar_erro('Situação: duas versões ativas (INSERT)',
$s$ DECLARE v UUID;
BEGIN
  v := pg_temp.tv('VER tv a2');
  PERFORM pg_temp.md('VER_AT', 1, 'ATIVO', pg_temp.te_com_idx('VER te a2a'), v);
  PERFORM pg_temp.md('VER_AT', 2, 'ATIVO', pg_temp.te_com_idx('VER te a2b'), v);
END; $s$, '23505');

SELECT pg_temp.esperar_erro('Situação: ativar versão 2 sem inativar a 1 (UPDATE)',
$s$ DECLARE v UUID;
BEGIN
  v := pg_temp.tv('VER tv a3');
  PERFORM pg_temp.md('VER_AU', 1, 'ATIVO', pg_temp.te_com_idx('VER te a3a'), v);
  PERFORM pg_temp.md('VER_AU', 2, 'RASCUNHO', pg_temp.te_com_idx('VER te a3b'), v);
  UPDATE catalogo.modelo SET situacao = 'ATIVO' WHERE id_modelo = 'VER_AU' AND versao = 2;
END; $s$, '23505');

SELECT pg_temp.esperar_sucesso('Situação: troca de versão vigente na mesma transação',
$s$ DECLARE v UUID; n INT;
BEGIN
  v := pg_temp.tv('VER tv troca');
  PERFORM pg_temp.md('VER_TR', 1, 'ATIVO', pg_temp.te_com_idx('VER te tra'), v);
  PERFORM pg_temp.md('VER_TR', 2, 'RASCUNHO', pg_temp.te_com_idx('VER te trb'), v);
  UPDATE catalogo.modelo SET situacao = 'INATIVO' WHERE id_modelo = 'VER_TR' AND versao = 1;
  UPDATE catalogo.modelo SET situacao = 'ATIVO' WHERE id_modelo = 'VER_TR' AND versao = 2;
  SELECT versao INTO n FROM catalogo.modelo WHERE id_modelo = 'VER_TR' AND situacao = 'ATIVO';
  IF n <> 2 THEN RAISE EXCEPTION 'vigente = %', n; END IF;
END; $s$);

SELECT pg_temp.esperar_sucesso('Situação: INATIVO volta a ATIVO',
$s$ BEGIN
  PERFORM pg_temp.md('VER_IA', 1, 'ATIVO', pg_temp.te_com_idx('VER te ia'), pg_temp.tv('VER tv ia'));
  UPDATE catalogo.modelo SET situacao = 'INATIVO' WHERE id_modelo = 'VER_IA';
  UPDATE catalogo.modelo SET situacao = 'ATIVO' WHERE id_modelo = 'VER_IA';
END; $s$);

SELECT pg_temp.esperar_erro('Situação: ATIVO não volta a RASCUNHO',
$s$ BEGIN
  PERFORM pg_temp.md('VER_VR', 1, 'ATIVO', pg_temp.te_com_idx('VER te vr'), pg_temp.tv('VER tv vr'));
  UPDATE catalogo.modelo SET situacao = 'RASCUNHO' WHERE id_modelo = 'VER_VR';
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Situação: INATIVO não volta a RASCUNHO',
$s$ BEGIN
  PERFORM pg_temp.md('VER_IR', 1, 'ATIVO', pg_temp.te_com_idx('VER te ir'), pg_temp.tv('VER tv ir'));
  UPDATE catalogo.modelo SET situacao = 'INATIVO' WHERE id_modelo = 'VER_IR';
  UPDATE catalogo.modelo SET situacao = 'RASCUNHO' WHERE id_modelo = 'VER_IR';
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Situação: RASCUNHO não vai direto a INATIVO',
$s$ BEGIN
  PERFORM pg_temp.md('VER_RI', 1, 'RASCUNHO', pg_temp.te_com_idx('VER te ri'), pg_temp.tv('VER tv ri'));
  UPDATE catalogo.modelo SET situacao = 'INATIVO' WHERE id_modelo = 'VER_RI';
END; $s$, '23514');

-- ============================================================================
-- GRUPO 6: PUBLICAÇÃO (indexador na posição 1)
-- ============================================================================

SELECT pg_temp.esperar_erro('Publicação: UPDATE para ATIVO sem indexador 1',
$s$ BEGIN
  PERFORM pg_temp.md('VER_PS', 1, 'RASCUNHO', pg_temp.te('VER te ps'), pg_temp.tv('VER tv ps'));
  UPDATE catalogo.modelo SET situacao = 'ATIVO' WHERE id_modelo = 'VER_PS';
END; $s$, '23514', '%indexador%posição 1%');

SELECT pg_temp.esperar_sucesso('Publicação: UPDATE para ATIVO com indexador 1',
$s$ BEGIN
  PERFORM pg_temp.md('VER_PC', 1, 'RASCUNHO', pg_temp.te_com_idx('VER te pc'), pg_temp.tv('VER tv pc'));
  UPDATE catalogo.modelo SET situacao = 'ATIVO' WHERE id_modelo = 'VER_PC';
END; $s$);

SELECT pg_temp.esperar_erro('Publicação: INSERT direto como ATIVO sem indexador 1',
$s$ BEGIN PERFORM pg_temp.md('VER_IS', 1, 'ATIVO', pg_temp.te('VER te is'), pg_temp.tv('VER tv is')); END; $s$,
'23514', '%indexador%posição 1%');

SELECT pg_temp.esperar_erro('Publicação: INSERT direto como INATIVO sem indexador 1',
$s$ BEGIN PERFORM pg_temp.md('VER_II', 1, 'INATIVO', pg_temp.te('VER te ii'), pg_temp.tv('VER tv ii')); END; $s$, '23514');

SELECT pg_temp.esperar_sucesso('Publicação: INSERT direto como ATIVO com indexador 1',
$s$ BEGIN PERFORM pg_temp.md('VER_IC', 1, 'ATIVO', pg_temp.te_com_idx('VER te ic'), pg_temp.tv('VER tv ic')); END; $s$);

-- ============================================================================
-- GRUPO 7: IMUTABILIDADE DA VERSÃO PUBLICADA
-- ============================================================================

SELECT pg_temp.esperar_erro('Imutável: trocar template estrutural de modelo ATIVO',
$s$ BEGIN
  PERFORM pg_temp.md('VER_M1', 1, 'ATIVO', pg_temp.te_com_idx('VER te m1'), pg_temp.tv('VER tv m1'));
  UPDATE catalogo.modelo SET id_template_estrutural = pg_temp.te_com_idx('VER te m1n') WHERE id_modelo = 'VER_M1';
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Imutável: trocar template variável de modelo ATIVO',
$s$ BEGIN
  PERFORM pg_temp.md('VER_M2', 1, 'ATIVO', pg_temp.te_com_idx('VER te m2'), pg_temp.tv('VER tv m2'));
  UPDATE catalogo.modelo SET id_template_variavel = pg_temp.tv('VER tv m2n') WHERE id_modelo = 'VER_M2';
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Imutável: alterar a versão (chave) de modelo ATIVO',
$s$ BEGIN
  PERFORM pg_temp.md('VER_M3', 1, 'ATIVO', pg_temp.te_com_idx('VER te m3'), pg_temp.tv('VER tv m3'));
  UPDATE catalogo.modelo SET versao = 50 WHERE id_modelo = 'VER_M3';
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Imutável: alterar o código (chave) de modelo ATIVO',
$s$ BEGIN
  PERFORM pg_temp.md('VER_M4', 1, 'ATIVO', pg_temp.te_com_idx('VER te m4'), pg_temp.tv('VER tv m4'));
  UPDATE catalogo.modelo SET id_modelo = 'VER_M4X' WHERE id_modelo = 'VER_M4';
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Imutável: alterar descrição de modelo ATIVO',
$s$ BEGIN
  PERFORM pg_temp.md('VER_M5', 1, 'ATIVO', pg_temp.te_com_idx('VER te m5'), pg_temp.tv('VER tv m5'));
  UPDATE catalogo.modelo SET descricao = 'outra' WHERE id_modelo = 'VER_M5';
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Imutável: excluir modelo publicado',
$s$ BEGIN
  PERFORM pg_temp.md('VER_M6', 1, 'ATIVO', pg_temp.te_com_idx('VER te m6'), pg_temp.tv('VER tv m6'));
  DELETE FROM catalogo.modelo WHERE id_modelo = 'VER_M6';
END; $s$, '23514');

SELECT pg_temp.esperar_sucesso('Rascunho: modelo em rascunho pode ser excluído',
$s$ BEGIN
  PERFORM pg_temp.md('VER_M7', 1, 'RASCUNHO', pg_temp.te('VER te m7'), pg_temp.tv('VER tv m7'));
  DELETE FROM catalogo.modelo WHERE id_modelo = 'VER_M7';
END; $s$);

SELECT pg_temp.esperar_erro('Imutável: incluir campo em template estrutural publicado',
$s$ DECLARE t UUID;
BEGIN
  t := pg_temp.te_com_idx('VER te t1');
  PERFORM pg_temp.md('VER_T1', 1, 'ATIVO', t, pg_temp.tv('VER tv t1'));
  PERFORM pg_temp.ae(t, pg_temp.campo('ver_novo1'), 2);
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Imutável: incluir campo em template variável publicado',
$s$ DECLARE v UUID;
BEGIN
  v := pg_temp.tv('VER tv t2');
  PERFORM pg_temp.md('VER_T2', 1, 'ATIVO', pg_temp.te_com_idx('VER te t2'), v);
  PERFORM pg_temp.av(v, pg_temp.campo('ver_novo2'), 1);
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Imutável: alterar associação de template publicado',
$s$ DECLARE t UUID;
BEGIN
  t := pg_temp.te_com_idx('VER te t3');
  PERFORM pg_temp.md('VER_T3', 1, 'ATIVO', t, pg_temp.tv('VER tv t3'));
  UPDATE catalogo.template_estrutural_campo SET ordem = 9 WHERE id_template_estrutural = t;
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Imutável: excluir associação de template publicado',
$s$ DECLARE t UUID;
BEGIN
  t := pg_temp.te_com_idx('VER te t4');
  PERFORM pg_temp.md('VER_T4', 1, 'ATIVO', t, pg_temp.tv('VER tv t4'));
  DELETE FROM catalogo.template_estrutural_campo WHERE id_template_estrutural = t;
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Imutável: mover associação de um rascunho para template publicado',
$s$ DECLARE t_pub UUID; t_rasc UUID;
BEGIN
  t_pub := pg_temp.te_com_idx('VER te t5p');
  PERFORM pg_temp.md('VER_T5', 1, 'ATIVO', t_pub, pg_temp.tv('VER tv t5'));
  t_rasc := pg_temp.te('VER te t5r');
  PERFORM pg_temp.ae(t_rasc, pg_temp.campo('ver_mover'), 1);
  UPDATE catalogo.template_estrutural_campo SET id_template_estrutural = t_pub, ordem = 99
   WHERE id_template_estrutural = t_rasc;
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Imutável: alterar nome de template publicado',
$s$ DECLARE t UUID;
BEGIN
  t := pg_temp.te_com_idx('VER te t6');
  PERFORM pg_temp.md('VER_T6', 1, 'ATIVO', t, pg_temp.tv('VER tv t6'));
  UPDATE catalogo.template_estrutural SET nome_template = 'outro' WHERE id_template_estrutural = t;
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Imutável: excluir template publicado',
$s$ DECLARE t UUID;
BEGIN
  t := pg_temp.te_com_idx('VER te t7');
  PERFORM pg_temp.md('VER_T7', 1, 'ATIVO', t, pg_temp.tv('VER tv t7'));
  DELETE FROM catalogo.template_estrutural WHERE id_template_estrutural = t;
END; $s$, '23514');

SELECT pg_temp.esperar_sucesso('Rascunho: template só de rascunho pode ser editado',
$s$ DECLARE t UUID;
BEGIN
  t := pg_temp.te_com_idx('VER te t8');
  PERFORM pg_temp.md('VER_T8', 1, 'RASCUNHO', t, pg_temp.tv('VER tv t8'));
  PERFORM pg_temp.ae(t, pg_temp.campo('ver_novo8'), 2);
  UPDATE catalogo.template_estrutural SET nome_template = 'editado' WHERE id_template_estrutural = t;
END; $s$);

SELECT pg_temp.esperar_erro('Campo em uso: alterar tipo_dado de campo de modelo ATIVO',
$s$ DECLARE c BIGINT; t UUID;
BEGIN
  c := pg_temp.campo('ver_cu1'); t := pg_temp.te('VER te cu1');
  PERFORM pg_temp.ae(t, c, 1, 1);
  PERFORM pg_temp.md('VER_CU1', 1, 'ATIVO', t, pg_temp.tv('VER tv cu1'));
  UPDATE catalogo.campo SET tipo_dado = 'INTEIRO' WHERE id_campo = c;
END; $s$, '23514');

SELECT pg_temp.esperar_erro('Campo em uso: alterar nome_campo de campo de modelo ATIVO',
$s$ DECLARE c BIGINT; t UUID;
BEGIN
  c := pg_temp.campo('ver_cu2'); t := pg_temp.te('VER te cu2');
  PERFORM pg_temp.ae(t, c, 1, 1);
  PERFORM pg_temp.md('VER_CU2', 1, 'ATIVO', t, pg_temp.tv('VER tv cu2'));
  UPDATE catalogo.campo SET nome_campo = 'ver_cu2_novo' WHERE id_campo = c;
END; $s$, '23514', '%ver_cu2%');

SELECT pg_temp.esperar_erro('Campo em uso: campo só do template variável de modelo ATIVO',
$s$ DECLARE c BIGINT; v UUID;
BEGIN
  c := pg_temp.campo('ver_cu3'); v := pg_temp.tv('VER tv cu3');
  PERFORM pg_temp.av(v, c, 1);
  PERFORM pg_temp.md('VER_CU3', 1, 'ATIVO', pg_temp.te_com_idx('VER te cu3'), v);
  UPDATE catalogo.campo SET tipo_dado = 'INTEIRO' WHERE id_campo = c;
END; $s$, '23514');

SELECT pg_temp.esperar_sucesso('Campo em uso: descricao_base de campo publicado pode mudar',
$s$ DECLARE c BIGINT; t UUID;
BEGIN
  c := pg_temp.campo('ver_cu4'); t := pg_temp.te('VER te cu4');
  PERFORM pg_temp.ae(t, c, 1, 1);
  PERFORM pg_temp.md('VER_CU4', 1, 'ATIVO', t, pg_temp.tv('VER tv cu4'));
  UPDATE catalogo.campo SET descricao_base = 'nova descricao' WHERE id_campo = c;
END; $s$);

SELECT pg_temp.esperar_sucesso('Campo em uso: campo usado só por rascunho pode mudar de tipo',
$s$ DECLARE c BIGINT; t UUID;
BEGIN
  c := pg_temp.campo('ver_cu5'); t := pg_temp.te('VER te cu5');
  PERFORM pg_temp.ae(t, c, 1, 1);
  PERFORM pg_temp.md('VER_CU5', 1, 'RASCUNHO', t, pg_temp.tv('VER tv cu5'));
  UPDATE catalogo.campo SET tipo_dado = 'INTEIRO' WHERE id_campo = c;
END; $s$);

-- ============================================================================
-- GRUPO 8: DATAS DE AUDITORIA E data_version
-- ============================================================================

SELECT pg_temp.esperar_sucesso('Datas: inclusão sem informar datas preenche as duas',
$s$ DECLARE c BIGINT; a TIMESTAMPTZ; b TIMESTAMPTZ;
BEGIN
  c := pg_temp.campo('ver_dt');
  SELECT data_hora_criacao, data_hora_atualizacao INTO a, b FROM catalogo.campo WHERE id_campo = c;
  IF a IS NULL OR b IS NULL THEN RAISE EXCEPTION 'datas nulas'; END IF;
END; $s$);

SELECT pg_temp.esperar_sucesso('Datas: associações também têm as duas datas preenchidas',
$s$ DECLARE t UUID; a TIMESTAMPTZ; b TIMESTAMPTZ;
BEGIN
  t := pg_temp.te('VER te dta'); PERFORM pg_temp.ae(t, pg_temp.campo('ver_dta'), 1);
  SELECT data_hora_criacao, data_hora_atualizacao INTO a, b
    FROM catalogo.template_estrutural_campo WHERE id_template_estrutural = t;
  IF a IS NULL OR b IS NULL THEN RAISE EXCEPTION 'datas nulas'; END IF;
END; $s$);

SELECT pg_temp.esperar_sucesso('Datas: o banco NÃO renova data_hora_atualizacao no UPDATE',
$s$ DECLARE c BIGINT; b TIMESTAMPTZ;
BEGIN
  c := pg_temp.campo('ver_sem_trg');
  UPDATE catalogo.campo SET data_hora_atualizacao = '2000-01-01 00:00:00+00' WHERE id_campo = c;
  UPDATE catalogo.campo SET descricao_base = 'mudou' WHERE id_campo = c;
  SELECT data_hora_atualizacao INTO b FROM catalogo.campo WHERE id_campo = c;
  IF b <> '2000-01-01 00:00:00+00'::timestamptz THEN RAISE EXCEPTION 'data foi renovada pelo banco: %', b; END IF;
END; $s$);

SELECT pg_temp.esperar_sucesso('Datas: a aplicação (role de escrita) renova data_hora_atualizacao e data_version',
$s$ DECLARE c BIGINT; n INT;
BEGIN
  c := pg_temp.campo('ver_app');
  SET LOCAL ROLE catalogo_escrita;
  UPDATE catalogo.campo
     SET descricao_base = 'pela app', data_hora_atualizacao = now(), data_version = data_version + 1
   WHERE id_campo = c AND data_version = 0;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'linhas atualizadas = %', n; END IF;
END; $s$);

SELECT pg_temp.esperar_sucesso('Datas: role de escrita não consegue alterar data_hora_criacao em nenhuma tabela',
$s$ DECLARE t TEXT;
BEGIN
  SET LOCAL ROLE catalogo_escrita;
  FOREACH t IN ARRAY ARRAY['campo','template_estrutural','template_estrutural_campo',
                           'template_variavel','template_variavel_campo','modelo'] LOOP
    BEGIN
      EXECUTE format('UPDATE catalogo.%I SET data_hora_criacao = data_hora_criacao', t);
      RAISE EXCEPTION 'UPDATE de data_hora_criacao foi aceito em %', t;
    EXCEPTION WHEN insufficient_privilege THEN
      NULL; -- esperado
    END;
  END LOOP;
END; $s$);

SELECT pg_temp.esperar_sucesso('Datas: privilégio de coluna (data_hora_atualizacao sim, data_hora_criacao não)',
$s$ DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['campo','template_estrutural','template_estrutural_campo',
                           'template_variavel','template_variavel_campo','modelo'] LOOP
    IF has_column_privilege('catalogo_escrita', 'catalogo.' || t, 'data_hora_criacao', 'UPDATE') THEN
      RAISE EXCEPTION 'catalogo_escrita pode alterar data_hora_criacao em %', t;
    END IF;
    IF NOT has_column_privilege('catalogo_escrita', 'catalogo.' || t, 'data_hora_atualizacao', 'UPDATE') THEN
      RAISE EXCEPTION 'catalogo_escrita não pode alterar data_hora_atualizacao em %', t;
    END IF;
  END LOOP;
END; $s$);

SELECT pg_temp.esperar_sucesso('Esquema: nenhum trigger de auditoria e função fn_atualiza_data_hora inexistente',
$s$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'catalogo' AND p.proname = 'fn_atualiza_data_hora') THEN
    RAISE EXCEPTION 'fn_atualiza_data_hora ainda existe';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger tg JOIN pg_class c ON c.oid = tg.tgrelid
               JOIN pg_namespace n ON n.oid = c.relnamespace
              WHERE n.nspname = 'catalogo' AND NOT tg.tgisinternal AND tg.tgname LIKE '%atualiza_data_hora%') THEN
    RAISE EXCEPTION 'ainda existe trigger de auditoria';
  END IF;
END; $s$);

SELECT pg_temp.esperar_sucesso('Esquema: nenhuma coluna "version"; data_version só nas 4 tabelas principais',
$s$ DECLARE t TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'catalogo' AND column_name = 'version') THEN
    RAISE EXCEPTION 'ainda existe coluna version';
  END IF;
  FOREACH t IN ARRAY ARRAY['campo','template_estrutural','template_variavel','modelo'] LOOP
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'catalogo' AND table_name = t AND column_name = 'data_version') THEN
      RAISE EXCEPTION 'faltou data_version em %', t;
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'catalogo'
                AND table_name IN ('template_estrutural_campo','template_variavel_campo')
                AND column_name = 'data_version') THEN
    RAISE EXCEPTION 'associação não deveria ter data_version';
  END IF;
END; $s$);

SELECT pg_temp.esperar_sucesso('Esquema: template variável não tem coluna de indexador',
$s$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'catalogo'
              AND table_name = 'template_variavel_campo' AND column_name = 'posicao_indexador') THEN
    RAISE EXCEPTION 'template_variavel_campo tem posicao_indexador';
  END IF;
END; $s$);

-- ============================================================================
-- GRUPO 9: ROLES
-- ============================================================================

SELECT pg_temp.esperar_erro('Roles: leitura tenta INSERT',
$s$ BEGIN
  SET LOCAL ROLE catalogo_leitura;
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('ver_role', 'TEXTO');
END; $s$, '42501');

SELECT pg_temp.esperar_erro('Roles: leitura tenta UPDATE',
$s$ BEGIN
  SET LOCAL ROLE catalogo_leitura;
  UPDATE catalogo.campo SET descricao_base = 'x';
END; $s$, '42501');

SELECT pg_temp.esperar_erro('Roles: escrita tenta DDL (DROP TABLE)',
$s$ BEGIN
  SET LOCAL ROLE catalogo_escrita;
  DROP TABLE catalogo.campo;
END; $s$, '42501');

SELECT pg_temp.esperar_sucesso('Roles: escrita insere e exclui',
$s$ BEGIN
  SET LOCAL ROLE catalogo_escrita;
  INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('ver_role_ok', 'TEXTO');
  DELETE FROM catalogo.campo WHERE nome_campo = 'ver_role_ok';
END; $s$);

SELECT pg_temp.esperar_sucesso('Roles: leitura consulta a view de modelo completo',
$s$ BEGIN
  SET LOCAL ROLE catalogo_leitura;
  PERFORM 1 FROM catalogo.vw_modelo_completo LIMIT 1;
END; $s$);

-- ============================================================================
-- GRUPO 10: CONSULTAS DE CARGA DO CACHE
-- ============================================================================

SELECT pg_temp.esperar_sucesso('Cache: a view não duplica campos (3 estruturais e 2 variáveis)',
$s$ DECLARE t UUID; v UUID; ne INT; nv INT;
BEGIN
  t := pg_temp.te_com_idx('VER te cache'); v := pg_temp.tv('VER tv cache');
  PERFORM pg_temp.ae(t, pg_temp.campo('ver_ca2'), 2);
  PERFORM pg_temp.ae(t, pg_temp.campo('ver_ca3'), 3);
  PERFORM pg_temp.av(v, pg_temp.campo('ver_cb1'), 1);
  PERFORM pg_temp.av(v, pg_temp.campo('ver_cb2'), 2);
  PERFORM pg_temp.md('VER_CACHE', 1, 'RASCUNHO', t, v);
  SELECT jsonb_array_length(campos_estruturais), jsonb_array_length(campos_variaveis) INTO ne, nv
    FROM catalogo.vw_modelo_completo WHERE id_modelo = 'VER_CACHE' AND versao = 1;
  IF ne <> 3 OR nv <> 2 THEN RAISE EXCEPTION 'estruturais=% variaveis=%', ne, nv; END IF;
END; $s$);

SELECT pg_temp.esperar_sucesso('Cache: campos vêm ordenados e o indexador aparece por posição',
$s$ DECLARE t UUID; j JSONB;
BEGIN
  t := pg_temp.te('VER te ordv');
  PERFORM pg_temp.ae(t, pg_temp.campo('ver_ov3'), 3);
  PERFORM pg_temp.ae(t, pg_temp.campo('ver_ov1'), 1, 1);
  PERFORM pg_temp.ae(t, pg_temp.campo('ver_ov2'), 2);
  PERFORM pg_temp.md('VER_ORDV', 1, 'RASCUNHO', t, pg_temp.tv('VER tv ordv'));
  SELECT campos_estruturais INTO j FROM catalogo.vw_modelo_completo WHERE id_modelo = 'VER_ORDV';
  IF (j -> 0 ->> 'ordem')::int <> 1 OR (j -> 1 ->> 'ordem')::int <> 2 OR (j -> 2 ->> 'ordem')::int <> 3 THEN
    RAISE EXCEPTION 'fora de ordem: %', j;
  END IF;
  IF (j -> 0 ->> 'posicao_indexador')::int <> 1 THEN RAISE EXCEPTION 'indexador ausente: %', j; END IF;
END; $s$);

SELECT pg_temp.esperar_sucesso('Cache: resolver a versão vigente (ATIVO) devolve uma só, ou nenhuma',
$s$ DECLARE v UUID; n INT;
BEGIN
  v := pg_temp.tv('VER tv vig');
  PERFORM pg_temp.md('VER_VIG', 1, 'ATIVO', pg_temp.te_com_idx('VER te viga'), v);
  PERFORM pg_temp.md('VER_VIG', 2, 'RASCUNHO', pg_temp.te_com_idx('VER te vigb'), v);
  SELECT count(*) INTO n FROM catalogo.modelo WHERE id_modelo = 'VER_VIG' AND situacao = 'ATIVO';
  IF n <> 1 THEN RAISE EXCEPTION 'vigentes = %', n; END IF;
  UPDATE catalogo.modelo SET situacao = 'INATIVO' WHERE id_modelo = 'VER_VIG' AND versao = 1;
  SELECT count(*) INTO n FROM catalogo.modelo WHERE id_modelo = 'VER_VIG' AND situacao = 'ATIVO';
  IF n <> 0 THEN RAISE EXCEPTION 'vigentes após inativar = %', n; END IF;
END; $s$);

-- ============================================================================
-- RESULTADO FINAL
-- ============================================================================

\echo '===== RESULTADO DA VERIFICAÇÃO ====='
SELECT numero, status, descricao, COALESCE(detalhe, '') AS detalhe
  FROM resultado ORDER BY numero;

SELECT count(*) AS total,
       count(*) FILTER (WHERE status = 'OK') AS ok,
       count(*) FILTER (WHERE status = 'FALHA') AS falhas,
       (count(*) FILTER (WHERE status = 'FALHA')) > 0 AS tem_falha
  FROM resultado \gset

ROLLBACK;

\echo 'Cenários:' :total ' OK:' :ok ' FALHA:' :falhas

-- Saída: o psql não aceita código em "\q", então a falha é sinalizada por um erro SQL
-- deliberado com ON_ERROR_STOP ligado, que encerra o psql com código 3 (só chega aqui depois do ROLLBACK).
\if :tem_falha
  \echo 'VERIFICAÇÃO FALHOU'
  \set ON_ERROR_STOP on
  DO $$ BEGIN RAISE EXCEPTION 'VERIFICACAO FALHOU: existem cenarios com status FALHA'; END $$;
\else
  \echo 'VERIFICAÇÃO OK'
\endif
