-- v1.0.05.-triggers-imutabilidade-e-publicacao.sql
-- Triggers de imutabilidade de modelo publicado e exigência de indexador na publicação

-- ============================================================================
-- TRIGGER: trg_modelo_imutavel (BEFORE UPDATE)
-- Impõe imutabilidade de modelo publicado
-- ============================================================================

CREATE OR REPLACE FUNCTION catalogo.fn_modelo_imutavel()
RETURNS TRIGGER AS $$
DECLARE
  v_has_indexador_1 BOOLEAN;
BEGIN
  -- Se o modelo NÃO está em RASCUNHO (ou seja, está ATIVO ou INATIVO),
  -- bloqueia alteração de composição
  IF OLD.situacao <> 'RASCUNHO' THEN
    -- Permitir apenas alterações de situacao, version e data_hora_atualizacao
    IF NEW.id_template_estrutural <> OLD.id_template_estrutural
       OR NEW.id_template_variavel <> OLD.id_template_variavel
       OR NEW.descricao <> OLD.descricao THEN
      RAISE EXCEPTION 'Modelo publicado é imutável: só situacao pode ser alterada'
        USING ERRCODE = 'check_violation';
    END IF;

    -- Bloqueia tentativa de voltar a RASCUNHO
    IF NEW.situacao = 'RASCUNHO' THEN
      RAISE EXCEPTION 'Modelo publicado não pode voltar a RASCUNHO'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  -- Se transitando de RASCUNHO para ATIVO, validar indexador na posição 1
  IF OLD.situacao = 'RASCUNHO' AND NEW.situacao = 'ATIVO' THEN
    -- Verificar se existe indexador na posição 1 no template estrutural
    SELECT EXISTS(
      SELECT 1 FROM catalogo.template_estrutural_campo
      WHERE id_template_estrutural = NEW.id_template_estrutural
        AND posicao_indexador = 1
    ) INTO v_has_indexador_1;

    IF NOT v_has_indexador_1 THEN
      RAISE EXCEPTION 'Publicação exige indexador na posição 1 (template: %)',
        NEW.id_template_estrutural
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_modelo_imutavel
  BEFORE UPDATE ON catalogo.modelo
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_modelo_imutavel();

-- ============================================================================
-- TRIGGER: trg_modelo_apenas_rascunho_pode_ser_excluido (BEFORE DELETE)
-- ============================================================================

CREATE OR REPLACE FUNCTION catalogo.fn_modelo_apenas_rascunho_pode_ser_excluido()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.situacao <> 'RASCUNHO' THEN
    RAISE EXCEPTION 'Modelo publicado não pode ser excluído'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_modelo_apenas_rascunho_pode_ser_excluido
  BEFORE DELETE ON catalogo.modelo
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_modelo_apenas_rascunho_pode_ser_excluido();

-- ============================================================================
-- TRIGGER: trg_template_estrutural_campo_imutavel (BEFORE INSERT/UPDATE/DELETE)
-- Bloqueia alterações em templates referenciados por modelos publicados
-- ============================================================================

CREATE OR REPLACE FUNCTION catalogo.fn_template_estrutural_campo_imutavel()
RETURNS TRIGGER AS $$
DECLARE
  v_modelo_publicado BOOLEAN;
BEGIN
  -- Verificar se o template é referenciado por algum modelo ATIVO ou INATIVO
  SELECT EXISTS(
    SELECT 1 FROM catalogo.modelo
    WHERE id_template_estrutural = COALESCE(NEW.id_template_estrutural, OLD.id_template_estrutural)
      AND situacao <> 'RASCUNHO'
  ) INTO v_modelo_publicado;

  IF v_modelo_publicado THEN
    RAISE EXCEPTION 'Template referenciado por modelo publicado não pode ser alterado'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_template_estrutural_campo_insert
  BEFORE INSERT ON catalogo.template_estrutural_campo
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_template_estrutural_campo_imutavel();

CREATE TRIGGER trg_template_estrutural_campo_update
  BEFORE UPDATE ON catalogo.template_estrutural_campo
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_template_estrutural_campo_imutavel();

CREATE TRIGGER trg_template_estrutural_campo_delete
  BEFORE DELETE ON catalogo.template_estrutural_campo
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_template_estrutural_campo_imutavel();

-- ============================================================================
-- TRIGGER: trg_template_variavel_campo_imutavel (BEFORE INSERT/UPDATE/DELETE)
-- Bloqueia alterações em templates referenciados por modelos publicados
-- ============================================================================

CREATE OR REPLACE FUNCTION catalogo.fn_template_variavel_campo_imutavel()
RETURNS TRIGGER AS $$
DECLARE
  v_modelo_publicado BOOLEAN;
BEGIN
  -- Verificar se o template é referenciado por algum modelo ATIVO ou INATIVO
  SELECT EXISTS(
    SELECT 1 FROM catalogo.modelo
    WHERE id_template_variavel = COALESCE(NEW.id_template_variavel, OLD.id_template_variavel)
      AND situacao <> 'RASCUNHO'
  ) INTO v_modelo_publicado;

  IF v_modelo_publicado THEN
    RAISE EXCEPTION 'Template referenciado por modelo publicado não pode ser alterado'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_template_variavel_campo_insert
  BEFORE INSERT ON catalogo.template_variavel_campo
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_template_variavel_campo_imutavel();

CREATE TRIGGER trg_template_variavel_campo_update
  BEFORE UPDATE ON catalogo.template_variavel_campo
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_template_variavel_campo_imutavel();

CREATE TRIGGER trg_template_variavel_campo_delete
  BEFORE DELETE ON catalogo.template_variavel_campo
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_template_variavel_campo_imutavel();

-- ============================================================================
-- TRIGGER: trg_template_estrutural_imutavel (BEFORE UPDATE/DELETE)
-- Bloqueia exclusão ou alteração de templates referenciados por modelos publicados
-- ============================================================================

CREATE OR REPLACE FUNCTION catalogo.fn_template_estrutural_imutavel()
RETURNS TRIGGER AS $$
DECLARE
  v_modelo_publicado BOOLEAN;
BEGIN
  -- Verificar se o template é referenciado por algum modelo ATIVO ou INATIVO
  SELECT EXISTS(
    SELECT 1 FROM catalogo.modelo
    WHERE id_template_estrutural = COALESCE(NEW.id_template_estrutural, OLD.id_template_estrutural)
      AND situacao <> 'RASCUNHO'
  ) INTO v_modelo_publicado;

  IF v_modelo_publicado THEN
    RAISE EXCEPTION 'Template referenciado por modelo publicado não pode ser alterado'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_template_estrutural_update
  BEFORE UPDATE ON catalogo.template_estrutural
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_template_estrutural_imutavel();

CREATE TRIGGER trg_template_estrutural_delete
  BEFORE DELETE ON catalogo.template_estrutural
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_template_estrutural_imutavel();

-- ============================================================================
-- TRIGGER: trg_template_variavel_imutavel (BEFORE UPDATE/DELETE)
-- Bloqueia exclusão ou alteração de templates referenciados por modelos publicados
-- ============================================================================

CREATE OR REPLACE FUNCTION catalogo.fn_template_variavel_imutavel()
RETURNS TRIGGER AS $$
DECLARE
  v_modelo_publicado BOOLEAN;
BEGIN
  -- Verificar se o template é referenciado por algum modelo ATIVO ou INATIVO
  SELECT EXISTS(
    SELECT 1 FROM catalogo.modelo
    WHERE id_template_variavel = COALESCE(NEW.id_template_variavel, OLD.id_template_variavel)
      AND situacao <> 'RASCUNHO'
  ) INTO v_modelo_publicado;

  IF v_modelo_publicado THEN
    RAISE EXCEPTION 'Template referenciado por modelo publicado não pode ser alterado'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_template_variavel_update
  BEFORE UPDATE ON catalogo.template_variavel
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_template_variavel_imutavel();

CREATE TRIGGER trg_template_variavel_delete
  BEFORE DELETE ON catalogo.template_variavel
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_template_variavel_imutavel();
