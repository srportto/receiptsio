-- exemplos-queries.sql
-- Exemplos de consultas no catálogo de modelos de comprovante

-- ============================================================================
-- EXEMPLO 1: Carregar modelo completo para cache
-- Dado (id_modelo, versao), retorna o modelo com todos os campos dos dois
-- templates, ordenados, com tipo, obrigatoriedade e posição de indexador.
-- Esta é a consulta que o carregador de cache executa.
-- ============================================================================

-- Sintaxe: modifique os valores de 'COMPPIX' e 1 conforme necessário
SELECT
  m.id_modelo,
  m.versao,
  m.descricao,
  m.situacao,
  m.id_template_estrutural,
  m.id_template_variavel,

  -- Campos do template estrutural
  jsonb_agg(
    jsonb_build_object(
      'tipo_template', 'ESTRUTURAL',
      'id_campo', c.id_campo,
      'nome_campo', c.nome_campo,
      'tipo_dado', c.tipo_dado,
      'descricao_base', c.descricao_base,
      'ordem', tec.ordem,
      'aceita_nulo_vazio', tec.aceita_nulo_vazio,
      'posicao_indexador', tec.posicao_indexador
    )
    ORDER BY tec.ordem
  ) FILTER (WHERE tec.id_template_estrutural IS NOT NULL) AS campos_estruturais,

  -- Campos do template variável
  jsonb_agg(
    jsonb_build_object(
      'tipo_template', 'VARIAVEL',
      'id_campo', c2.id_campo,
      'nome_campo', c2.nome_campo,
      'tipo_dado', c2.tipo_dado,
      'descricao_base', c2.descricao_base,
      'ordem', tvc.ordem,
      'aceita_nulo_vazio', tvc.aceita_nulo_vazio
    )
    ORDER BY tvc.ordem
  ) FILTER (WHERE tvc.id_template_variavel IS NOT NULL) AS campos_variaveis

FROM catalogo.modelo m
LEFT JOIN catalogo.template_estrutural te ON m.id_template_estrutural = te.id_template_estrutural
LEFT JOIN catalogo.template_estrutural_campo tec ON te.id_template_estrutural = tec.id_template_estrutural
LEFT JOIN catalogo.campo c ON tec.id_campo = c.id_campo
LEFT JOIN catalogo.template_variavel tv ON m.id_template_variavel = tv.id_template_variavel
LEFT JOIN catalogo.template_variavel_campo tvc ON tv.id_template_variavel = tvc.id_template_variavel
LEFT JOIN catalogo.campo c2 ON tvc.id_campo = c2.id_campo
WHERE m.id_modelo = 'COMPPIX'
  AND m.versao = 1
GROUP BY
  m.id_modelo, m.versao, m.descricao, m.situacao,
  m.id_template_estrutural, m.id_template_variavel;

-- ============================================================================
-- EXEMPLO 2: Resolver versão vigente (ATIVO) de um modelo
-- Dado id_modelo, retorna a versão que está ATIVO (ou vazio se nenhuma estiver).
-- Usada pelo carregador de cache para descobrir qual versão é a "vigente".
-- ============================================================================

-- Sintaxe: modifique 'COMPPIX' conforme necessário
SELECT
  id_modelo,
  versao,
  descricao,
  situacao,
  data_hora_criacao,
  data_hora_atualizacao
FROM catalogo.modelo
WHERE id_modelo = 'COMPPIX'
  AND situacao = 'ATIVO'
LIMIT 1;

-- ============================================================================
-- EXEMPLO 3: Listar todos os modelos com situação
-- ============================================================================

SELECT
  id_modelo,
  versao,
  descricao,
  situacao,
  data_hora_criacao,
  data_hora_atualizacao
FROM catalogo.modelo
ORDER BY id_modelo, versao DESC;

-- ============================================================================
-- EXEMPLO 4: Verificar campos de um template
-- Dado id_template_estrutural, listar todos os campos associados
-- ============================================================================

SELECT
  c.id_campo,
  c.nome_campo,
  c.tipo_dado,
  c.descricao_base,
  tec.ordem,
  tec.posicao_indexador,
  tec.aceita_nulo_vazio
FROM catalogo.template_estrutural_campo tec
JOIN catalogo.campo c ON tec.id_campo = c.id_campo
WHERE tec.id_template_estrutural = '...'  -- substitua por UUID real
ORDER BY tec.ordem;

-- ============================================================================
-- EXEMPLO 5: Verificar quais modelos usam um template
-- ============================================================================

SELECT DISTINCT
  m.id_modelo,
  m.versao,
  m.situacao
FROM catalogo.modelo m
WHERE m.id_template_estrutural = '...'  -- substitua por UUID real
   OR m.id_template_variavel = '...'     -- substitua por UUID real
ORDER BY m.id_modelo, m.versao;

-- ============================================================================
-- RECEITA DE EXTENSÕES (cf. design.md)
-- As três extensões são carregadas na migração v1.0.00:
-- - pg_cron: agendador de tarefas
-- - pg_partman: gerenciador de partições
-- - vector: similaridade vetorial (pgvector)
-- ============================================================================

-- Verificar extensões instaladas
SELECT
  extname,
  extversion,
  extnamespace::regnamespace AS schema
FROM pg_extension
WHERE extname IN ('pg_cron', 'pg_partman', 'vector')
ORDER BY extname;

-- Verificar bibliotecas pré-carregadas
SHOW shared_preload_libraries;