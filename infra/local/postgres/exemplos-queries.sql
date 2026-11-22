-- exemplos-queries.sql
-- Consultas e operações de exemplo do catálogo de modelos de comprovante (usam o seed de v1.0.07).
--
-- O arquivo inteiro roda numa transação revertida (BEGIN ... ROLLBACK): pode ser executado sem
-- deixar alteração no banco. Para rodar:
--   docker exec -i postgres18-receiptsio psql -v ON_ERROR_STOP=1 -U "$DB_USER_NAME" -d "$DB_NAME" < exemplos-queries.sql

BEGIN;

-- ============================================================================
-- 1. CARGA DO CACHE: modelo completo por (id_modelo, versao)
-- A view agrega cada template numa subconsulta própria: uma linha por modelo, um elemento
-- por associação, ordenados por "ordem", com a descrição efetiva
-- (descricao_campo_template, ou descricao_base do campo quando nula).
-- Use apenas versões publicadas (ATIVO ou INATIVO) no cache: rascunho ainda muda.
-- ============================================================================

SELECT id_modelo, versao, situacao, nome_template_estrutural, nome_template_variavel,
       jsonb_array_length(campos_estruturais) AS qtd_estruturais,
       jsonb_array_length(campos_variaveis)   AS qtd_variaveis
  FROM catalogo.vw_modelo_completo
 WHERE id_modelo = 'COMPPIX' AND versao = 2;

-- Os campos estruturais, um por linha (indexadores aparecem em posicao_indexador)
SELECT c ->> 'ordem'                    AS ordem,
       c ->> 'nome_campo'               AS campo,
       c ->> 'tipo_dado'                AS tipo,
       c ->> 'posicao_indexador'        AS indexador,
       c ->> 'aceita_nulo_vazio'        AS aceita_nulo,
       c ->> 'descricao_efetiva'        AS descricao
  FROM catalogo.vw_modelo_completo v, jsonb_array_elements(v.campos_estruturais) c
 WHERE v.id_modelo = 'COMPPIX' AND v.versao = 2
 ORDER BY (c ->> 'ordem')::int;

-- Os campos variáveis
SELECT c ->> 'ordem' AS ordem, c ->> 'nome_campo' AS campo, c ->> 'aceita_nulo_vazio' AS aceita_nulo,
       c ->> 'descricao_efetiva' AS descricao
  FROM catalogo.vw_modelo_completo v, jsonb_array_elements(v.campos_variaveis) c
 WHERE v.id_modelo = 'COMPPIX' AND v.versao = 2
 ORDER BY (c ->> 'ordem')::int;

-- ============================================================================
-- 2. RESOLVER A VERSÃO VIGENTE (ATIVO) de um modelo
-- Devolve uma linha, ou nenhuma se não houver versão ativa.
-- ============================================================================

SELECT id_modelo, versao, descricao, situacao
  FROM catalogo.modelo
 WHERE id_modelo = 'COMPPIX' AND situacao = 'ATIVO';

-- ============================================================================
-- 3. LISTAR MODELOS COM SITUAÇÃO
-- ============================================================================

SELECT id_modelo, versao, situacao, descricao, data_hora_criacao, data_hora_atualizacao
  FROM catalogo.modelo
 ORDER BY id_modelo, versao DESC;

-- ============================================================================
-- 4. CAMPOS DE UM TEMPLATE (pelo nome do template)
-- ============================================================================

SELECT tec.ordem, c.nome_campo, c.tipo_dado, tec.posicao_indexador, tec.aceita_nulo_vazio,
       COALESCE(tec.descricao_campo_template, c.descricao_base) AS descricao_efetiva
  FROM catalogo.template_estrutural te
  JOIN catalogo.template_estrutural_campo tec USING (id_template_estrutural)
  JOIN catalogo.campo c USING (id_campo)
 WHERE te.nome_template = 'Estrutura TED v1'
 ORDER BY tec.ordem;

-- ============================================================================
-- 5. QUAIS MODELOS USAM UM TEMPLATE (e em que situação)
-- ============================================================================

SELECT m.id_modelo, m.versao, m.situacao
  FROM catalogo.modelo m
  JOIN catalogo.template_estrutural te ON te.id_template_estrutural = m.id_template_estrutural
 WHERE te.nome_template = 'Estrutura PIX v2'
 ORDER BY m.id_modelo, m.versao;

-- ============================================================================
-- 6. ONDE UM CAMPO É USADO (campos de modelo publicado não mudam de nome nem de tipo)
-- ============================================================================

SELECT c.nome_campo, m.id_modelo, m.versao, m.situacao, 'estrutural' AS template
  FROM catalogo.campo c
  JOIN catalogo.template_estrutural_campo tec ON tec.id_campo = c.id_campo
  JOIN catalogo.modelo m ON m.id_template_estrutural = tec.id_template_estrutural
 WHERE c.nome_campo = 'valor'
UNION ALL
SELECT c.nome_campo, m.id_modelo, m.versao, m.situacao, 'variavel'
  FROM catalogo.campo c
  JOIN catalogo.template_variavel_campo tvc ON tvc.id_campo = c.id_campo
  JOIN catalogo.modelo m ON m.id_template_variavel = tvc.id_template_variavel
 WHERE c.nome_campo = 'valor'
 ORDER BY id_modelo, versao;

-- ============================================================================
-- 7. COMO A APLICAÇÃO ATUALIZA UMA LINHA (não há trigger de auditoria)
-- A aplicação renova data_hora_atualizacao e incrementa data_version (lock otimista).
-- "AND data_version = <lido>" faz o UPDATE não atingir linha se alguém mudou antes (0 linhas = conflito).
-- ============================================================================

UPDATE catalogo.campo
   SET descricao_base        = 'CPF do pagador, sem máscara (exemplo de atualização pela aplicação)',
       data_hora_atualizacao = now(),
       data_version          = data_version + 1
 WHERE nome_campo = 'cpf_pagador' AND data_version = 0
RETURNING nome_campo, data_version, data_hora_atualizacao;

-- ============================================================================
-- 8. REGRAS EM AÇÃO (cada bloco captura o erro esperado e imprime um aviso)
-- ============================================================================

-- 8.1 COMPBOL v2 é rascunho SEM indexador 1: a publicação é rejeitada
DO $$
BEGIN
  UPDATE catalogo.modelo SET situacao = 'ATIVO' WHERE id_modelo = 'COMPBOL' AND versao = 2;
  RAISE EXCEPTION 'não deveria ter publicado';
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE '8.1 rejeitado como esperado: %', SQLERRM;
END $$;

-- 8.2 Template de modelo publicado (COMPPIX v2 ATIVO) não aceita campo novo
DO $$
BEGIN
  INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem)
    SELECT m.id_template_estrutural, (SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'banco_origem'), 99
      FROM catalogo.modelo m WHERE m.id_modelo = 'COMPPIX' AND m.versao = 2;
  RAISE EXCEPTION 'não deveria ter incluído';
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE '8.2 rejeitado como esperado: %', SQLERRM;
END $$;

-- 8.3 Campo em uso por modelo publicado não muda de tipo
DO $$
BEGIN
  UPDATE catalogo.campo SET tipo_dado = 'TEXTO' WHERE nome_campo = 'valor';
  RAISE EXCEPTION 'não deveria ter alterado';
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE '8.3 rejeitado como esperado: %', SQLERRM;
END $$;

-- 8.4 Rascunho é editável: COMPPIX v3 aceita campo novo no template estrutural
INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem)
  SELECT m.id_template_estrutural, (SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'cpf_pagador'), 5
    FROM catalogo.modelo m WHERE m.id_modelo = 'COMPPIX' AND m.versao = 3
RETURNING ordem, id_campo;

-- 8.5 Para publicar COMPBOL v2: dar o indexador 1 a um campo do template e publicar.
-- O template já usa a posição 2 em 'linha_digitavel'; incluímos 'codigo_barras' na posição 1.
INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem, posicao_indexador)
  SELECT m.id_template_estrutural, (SELECT id_campo FROM catalogo.campo WHERE nome_campo = 'codigo_barras'), 5, 1
    FROM catalogo.modelo m WHERE m.id_modelo = 'COMPBOL' AND m.versao = 2;

-- Para ativar a v2, a v1 precisa ser inativada antes (no máximo uma versão ATIVO por modelo)
UPDATE catalogo.modelo SET situacao = 'INATIVO' WHERE id_modelo = 'COMPBOL' AND versao = 1;
UPDATE catalogo.modelo SET situacao = 'ATIVO'   WHERE id_modelo = 'COMPBOL' AND versao = 2
RETURNING id_modelo, versao, situacao;

-- ============================================================================
-- 9. EXTENSÕES (criadas na migration v1.0.00)
-- ============================================================================

SELECT extname, extversion, extnamespace::regnamespace AS schema
  FROM pg_extension
 WHERE extname IN ('pg_cron', 'pg_partman', 'vector')
 ORDER BY extname;

SHOW shared_preload_libraries;

-- Tudo acima foi revertido: o banco continua exatamente como o seed deixou.
ROLLBACK;
