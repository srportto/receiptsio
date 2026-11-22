-- v1.0.05.-triggers-imutabilidade-e-publicacao.sql
-- Triggers de regra de negócio que protegem a versão publicada de um modelo.
--
-- Por que no banco: os comprovantes no NoSQL referenciam (id_modelo, versao) e o cache usa essa
-- chave sem invalidação. Se a composição de uma versão publicada mudasse, os dois ficariam errados.
-- A garantia precisa valer contra qualquer cliente (aplicação, psql, outra ferramenta).
--
-- "Publicado" = situacao ATIVO ou INATIVO.
--
-- Concorrência (publicar x editar): quem publica trava (FOR UPDATE) a linha dos templates e
-- (FOR SHARE) a dos campos, ANTES de validar; quem edita associação trava (FOR SHARE) a linha do
-- template, ANTES de checar se há modelo publicado. Os dois lados se enfileiram e o segundo enxerga
-- o que o primeiro confirmou (cada comando de uma função plpgsql tira um snapshot novo em READ COMMITTED).
-- Se duas sessões se cruzarem em ordem inversa, o PostgreSQL aborta uma com 40P01 e a aplicação repete.
--
-- Todos os erros usam SQLSTATE 23514 (check_violation) e mensagem que nomeia o objeto.

-- ============================================================================
-- Modelo: INSERT e UPDATE (transições, chave imutável, publicação com indexador 1)
-- ============================================================================

CREATE OR REPLACE FUNCTION catalogo.fn_modelo_imutavel()
RETURNS TRIGGER AS $$
DECLARE
  v_publicando BOOLEAN;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF OLD.situacao <> 'RASCUNHO' THEN
      -- Versão publicada: a chave não muda
      IF NEW.id_modelo <> OLD.id_modelo OR NEW.versao <> OLD.versao THEN
        RAISE EXCEPTION 'Modelo publicado é imutável: a chave (id_modelo, versao) não pode mudar (modelo %, versão %)',
          OLD.id_modelo, OLD.versao
          USING ERRCODE = 'check_violation';
      END IF;

      -- Versão publicada: só situacao (e colunas de controle) pode mudar
      IF NEW.id_template_estrutural <> OLD.id_template_estrutural
         OR NEW.id_template_variavel <> OLD.id_template_variavel
         OR NEW.descricao <> OLD.descricao THEN
        RAISE EXCEPTION 'Modelo publicado é imutável: só situacao pode ser alterada (modelo %, versão %)',
          OLD.id_modelo, OLD.versao
          USING ERRCODE = 'check_violation';
      END IF;

      -- Publicado não volta a RASCUNHO
      IF NEW.situacao = 'RASCUNHO' THEN
        RAISE EXCEPTION 'Modelo publicado não pode voltar a RASCUNHO (modelo %, versão %)',
          OLD.id_modelo, OLD.versao
          USING ERRCODE = 'check_violation';
      END IF;
    ELSIF NEW.situacao = 'INATIVO' THEN
      -- RASCUNHO só pode ir a ATIVO; ir direto a INATIVO congelaria a versão sem validar a publicação
      RAISE EXCEPTION 'Modelo em RASCUNHO não pode ir direto a INATIVO: publique (ATIVO) antes (modelo %, versão %)',
        OLD.id_modelo, OLD.versao
        USING ERRCODE = 'check_violation';
    END IF;

    v_publicando := OLD.situacao = 'RASCUNHO' AND NEW.situacao = 'ATIVO';
  ELSE
    -- INSERT já com situação publicada também é uma publicação
    v_publicando := NEW.situacao <> 'RASCUNHO';
  END IF;

  IF v_publicando THEN
    -- 1) Trava os templates contra edição concorrente (espera quem estiver editando)
    PERFORM 1 FROM catalogo.template_estrutural
      WHERE id_template_estrutural = NEW.id_template_estrutural FOR UPDATE;
    PERFORM 1 FROM catalogo.template_variavel
      WHERE id_template_variavel = NEW.id_template_variavel FOR UPDATE;

    -- 2) Trava os campos usados (em ordem de id, para reduzir deadlock) contra mudança de nome/tipo
    PERFORM 1 FROM catalogo.campo
      WHERE id_campo IN (
        SELECT id_campo FROM catalogo.template_estrutural_campo
         WHERE id_template_estrutural = NEW.id_template_estrutural
        UNION
        SELECT id_campo FROM catalogo.template_variavel_campo
         WHERE id_template_variavel = NEW.id_template_variavel)
      ORDER BY id_campo FOR SHARE;

    -- 3) Só agora valida: a consulta já enxerga tudo o que foi confirmado
    IF NOT EXISTS (
      SELECT 1 FROM catalogo.template_estrutural_campo
       WHERE id_template_estrutural = NEW.id_template_estrutural
         AND posicao_indexador = 1
    ) THEN
      RAISE EXCEPTION 'Publicação exige indexador na posição 1 (modelo %, versão %, template: %)',
        NEW.id_modelo, NEW.versao, NEW.id_template_estrutural
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_modelo_imutavel
  BEFORE INSERT OR UPDATE ON catalogo.modelo
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_modelo_imutavel();

-- ============================================================================
-- Modelo: DELETE (só RASCUNHO pode ser excluído)
-- ============================================================================

CREATE OR REPLACE FUNCTION catalogo.fn_modelo_apenas_rascunho_pode_ser_excluido()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.situacao <> 'RASCUNHO' THEN
    RAISE EXCEPTION 'Modelo publicado não pode ser excluído (modelo %, versão %)',
      OLD.id_modelo, OLD.versao
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
-- Associações template_*_campo: INSERT, UPDATE e DELETE
-- Checa o template de OLD e o de NEW (um UPDATE pode mover a associação para outro template).
-- Trava (FOR SHARE) a linha do template antes de checar, para se enfileirar com a publicação.
-- ============================================================================

CREATE OR REPLACE FUNCTION catalogo.fn_template_estrutural_campo_imutavel()
RETURNS TRIGGER AS $$
DECLARE
  v_id UUID;
BEGIN
  FOR v_id IN
    SELECT DISTINCT x FROM unnest(ARRAY[
      CASE WHEN TG_OP <> 'INSERT' THEN OLD.id_template_estrutural END,
      CASE WHEN TG_OP <> 'DELETE' THEN NEW.id_template_estrutural END
    ]) AS x WHERE x IS NOT NULL ORDER BY x
  LOOP
    PERFORM 1 FROM catalogo.template_estrutural WHERE id_template_estrutural = v_id FOR SHARE;

    IF EXISTS (
      SELECT 1 FROM catalogo.modelo
       WHERE id_template_estrutural = v_id AND situacao <> 'RASCUNHO'
    ) THEN
      RAISE EXCEPTION 'Template estrutural % referenciado por modelo publicado não pode ter campos alterados', v_id
        USING ERRCODE = 'check_violation';
    END IF;
  END LOOP;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_template_estrutural_campo_imutavel
  BEFORE INSERT OR UPDATE OR DELETE ON catalogo.template_estrutural_campo
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_template_estrutural_campo_imutavel();

CREATE OR REPLACE FUNCTION catalogo.fn_template_variavel_campo_imutavel()
RETURNS TRIGGER AS $$
DECLARE
  v_id UUID;
BEGIN
  FOR v_id IN
    SELECT DISTINCT x FROM unnest(ARRAY[
      CASE WHEN TG_OP <> 'INSERT' THEN OLD.id_template_variavel END,
      CASE WHEN TG_OP <> 'DELETE' THEN NEW.id_template_variavel END
    ]) AS x WHERE x IS NOT NULL ORDER BY x
  LOOP
    PERFORM 1 FROM catalogo.template_variavel WHERE id_template_variavel = v_id FOR SHARE;

    IF EXISTS (
      SELECT 1 FROM catalogo.modelo
       WHERE id_template_variavel = v_id AND situacao <> 'RASCUNHO'
    ) THEN
      RAISE EXCEPTION 'Template variável % referenciado por modelo publicado não pode ter campos alterados', v_id
        USING ERRCODE = 'check_violation';
    END IF;
  END LOOP;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_template_variavel_campo_imutavel
  BEFORE INSERT OR UPDATE OR DELETE ON catalogo.template_variavel_campo
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_template_variavel_campo_imutavel();

-- ============================================================================
-- Templates: UPDATE e DELETE do próprio template (a linha já fica travada pelo comando)
-- ============================================================================

CREATE OR REPLACE FUNCTION catalogo.fn_template_estrutural_imutavel()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM catalogo.modelo
     WHERE id_template_estrutural = OLD.id_template_estrutural AND situacao <> 'RASCUNHO'
  ) THEN
    RAISE EXCEPTION 'Template estrutural % referenciado por modelo publicado não pode ser alterado nem excluído',
      OLD.id_template_estrutural
      USING ERRCODE = 'check_violation';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_template_estrutural_imutavel
  BEFORE UPDATE OR DELETE ON catalogo.template_estrutural
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_template_estrutural_imutavel();

CREATE OR REPLACE FUNCTION catalogo.fn_template_variavel_imutavel()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM catalogo.modelo
     WHERE id_template_variavel = OLD.id_template_variavel AND situacao <> 'RASCUNHO'
  ) THEN
    RAISE EXCEPTION 'Template variável % referenciado por modelo publicado não pode ser alterado nem excluído',
      OLD.id_template_variavel
      USING ERRCODE = 'check_violation';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_template_variavel_imutavel
  BEFORE UPDATE OR DELETE ON catalogo.template_variavel
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_template_variavel_imutavel();

-- ============================================================================
-- Campo: nome_campo e tipo_dado não mudam enquanto o campo está em modelo publicado.
-- descricao_base e as colunas de controle continuam editáveis (não alteram o significado
-- dos comprovantes já gravados). O UPDATE já trava a linha do campo antes deste trigger,
-- o que o enfileira com a publicação (que pega FOR SHARE no campo).
-- ============================================================================

CREATE OR REPLACE FUNCTION catalogo.fn_campo_imutavel()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.nome_campo IS NOT DISTINCT FROM OLD.nome_campo
     AND NEW.tipo_dado IS NOT DISTINCT FROM OLD.tipo_dado THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1
      FROM catalogo.template_estrutural_campo tec
      JOIN catalogo.modelo m ON m.id_template_estrutural = tec.id_template_estrutural
     WHERE tec.id_campo = OLD.id_campo AND m.situacao <> 'RASCUNHO'
    UNION ALL
    SELECT 1
      FROM catalogo.template_variavel_campo tvc
      JOIN catalogo.modelo m ON m.id_template_variavel = tvc.id_template_variavel
     WHERE tvc.id_campo = OLD.id_campo AND m.situacao <> 'RASCUNHO'
  ) THEN
    RAISE EXCEPTION 'Campo % (id %) em uso por modelo publicado não pode mudar de nome nem de tipo',
      OLD.nome_campo, OLD.id_campo
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_campo_imutavel
  BEFORE UPDATE ON catalogo.campo
  FOR EACH ROW
  EXECUTE FUNCTION catalogo.fn_campo_imutavel();
