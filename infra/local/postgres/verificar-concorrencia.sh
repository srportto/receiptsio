#!/usr/bin/env bash
# verificar-concorrencia.sh
# Prova, com duas sessões psql reais, que publicar um modelo e editar o template dele
# não podem se sobrepor (corrida/write skew). Cobre os dois sentidos:
#   1) edita o template (sem confirmar) e, no meio, publica o modelo
#   2) publica o modelo (sem confirmar) e, no meio, edita o template
#
# Uso (a partir de infra/local/postgres, com o ambiente de pé):
#   ./verificar-concorrencia.sh
# Variáveis opcionais: CONTAINER, DB_NAME, DB_USER_NAME (senão lidas do .env da raiz).
# Código de saída: 0 = ambos os sentidos OK; 1 = alguma corrida passou; 2 = erro de ambiente.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENV_FILE="$RAIZ/.env"

# Lê só variáveis não secretas do .env (sem fazer source do arquivo inteiro)
ler_env() { [ -f "$ENV_FILE" ] && grep -E "^$1=" "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '\r"' || true; }

CONTAINER="${CONTAINER:-postgres18-receiptsio}"
DB_NAME="${DB_NAME:-$(ler_env DB_NAME)}"
DB_USER="${DB_USER_NAME:-$(ler_env DB_USER_NAME)}"
DB_NAME="${DB_NAME:-db-receiptsio}"
DB_USER="${DB_USER:-docker}"

# Tempo que a sessão "lenta" segura a transação aberta (segundos) e limite para considerar bloqueio
SEGURA=4
LIMITE_BLOQUEIO_MS=2000

psql_() { docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -qAtX -U "$DB_USER" -d "$DB_NAME" "$@"; }
agora_ms() { echo $(( $(date +%s%N) / 1000000 )); }

FALHAS=0
ok()    { echo "OK     - $1"; }
falha() { echo "FALHA  - $1"; FALHAS=$((FALHAS + 1)); }

if ! docker exec "$CONTAINER" pg_isready -q -U "$DB_USER" -d "$DB_NAME"; then
  echo "Erro: container $CONTAINER indisponível (banco $DB_NAME, usuário $DB_USER)" >&2
  exit 2
fi

# Limpeza (como superusuário, só dados CONC_): triggers desligados só nesta sessão
limpar() {
  psql_ <<'SQL' >/dev/null
SET session_replication_role = replica;
DELETE FROM catalogo.modelo WHERE id_modelo LIKE 'CONC\_%';
DELETE FROM catalogo.template_estrutural_campo WHERE id_template_estrutural IN
  (SELECT id_template_estrutural FROM catalogo.template_estrutural WHERE nome_template LIKE 'CONC %');
DELETE FROM catalogo.template_variavel_campo WHERE id_template_variavel IN
  (SELECT id_template_variavel FROM catalogo.template_variavel WHERE nome_template LIKE 'CONC %');
DELETE FROM catalogo.template_estrutural WHERE nome_template LIKE 'CONC %';
DELETE FROM catalogo.template_variavel WHERE nome_template LIKE 'CONC %';
DELETE FROM catalogo.campo WHERE nome_campo LIKE 'conc\_%';
SQL
}
trap limpar EXIT
limpar

# Cria um modelo RASCUNHO publicável (indexador 1) com campo extra pronto para ser incluído
preparar() { # $1 = sufixo (1 ou 2)
  psql_ <<SQL >/dev/null
INSERT INTO catalogo.campo (nome_campo, tipo_dado) VALUES ('conc_idx_$1','TEXTO'), ('conc_extra_$1','TEXTO');
INSERT INTO catalogo.template_estrutural (nome_template) VALUES ('CONC te $1');
INSERT INTO catalogo.template_variavel (nome_template) VALUES ('CONC tv $1');
INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem, posicao_indexador)
  SELECT te.id_template_estrutural, c.id_campo, 1, 1
    FROM catalogo.template_estrutural te, catalogo.campo c
   WHERE te.nome_template = 'CONC te $1' AND c.nome_campo = 'conc_idx_$1';
INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, id_template_estrutural, id_template_variavel)
  SELECT 'CONC_$1', 1, 'concorrencia', 'RASCUNHO', te.id_template_estrutural, tv.id_template_variavel
    FROM catalogo.template_estrutural te, catalogo.template_variavel tv
   WHERE te.nome_template = 'CONC te $1' AND tv.nome_template = 'CONC tv $1';
SQL
}

# SQL que inclui o campo extra no template estrutural do modelo CONC_<n>
sql_inclui_campo() {
  cat <<SQL
INSERT INTO catalogo.template_estrutural_campo (id_template_estrutural, id_campo, ordem)
  SELECT m.id_template_estrutural, c.id_campo, 2
    FROM catalogo.modelo m, catalogo.campo c
   WHERE m.id_modelo = 'CONC_$1' AND c.nome_campo = 'conc_extra_$1';
SQL
}

sql_publica() { echo "UPDATE catalogo.modelo SET situacao = 'ATIVO' WHERE id_modelo = 'CONC_$1';"; }

qtd_campos() { psql_ -c "SELECT count(*) FROM catalogo.template_estrutural_campo tec JOIN catalogo.modelo m USING (id_template_estrutural) WHERE m.id_modelo = 'CONC_$1'"; }
situacao()   { psql_ -c "SELECT situacao FROM catalogo.modelo WHERE id_modelo = 'CONC_$1'"; }

TMP="$(mktemp -d)"
trap 'limpar; rm -rf "$TMP"' EXIT

# ----------------------------------------------------------------------------
# Sentido 1: A edita o template e segura a transação; B publica no meio.
# Esperado: a publicação ESPERA A terminar e valida o template já editado.
# ----------------------------------------------------------------------------
echo "--- Sentido 1: edita o template e, no meio, publica o modelo"
preparar 1
{ echo "BEGIN;"; sql_inclui_campo 1; echo "SELECT pg_sleep($SEGURA);"; echo "COMMIT;"; } \
  | psql_ >"$TMP/a1.out" 2>&1 &
PID_A=$!
sleep 1
T0=$(agora_ms)
sql_publica 1 | psql_ >"$TMP/b1.out" 2>&1; RC_B=$?
T1=$(agora_ms); DUR_B=$((T1 - T0))
wait $PID_A; RC_A=$?
SIT=$(situacao 1); QTD=$(qtd_campos 1)
echo "    publicação durou ${DUR_B} ms (rc=$RC_B); situação final=$SIT; campos no template=$QTD (rc edição=$RC_A)"
if [ "$RC_A" -eq 0 ] && [ "$RC_B" -eq 0 ] && [ "$SIT" = "ATIVO" ] && [ "$QTD" = "2" ] && [ "$DUR_B" -ge "$LIMITE_BLOQUEIO_MS" ]; then
  ok "a publicação esperou a edição confirmar e validou o template já com o campo novo"
else
  falha "publicou sem esperar a edição em andamento (duração ${DUR_B} ms < ${LIMITE_BLOQUEIO_MS} ms) ou terminou em estado inesperado"
  sed 's/^/    /' "$TMP/a1.out" "$TMP/b1.out"
fi

# ----------------------------------------------------------------------------
# Sentido 2: B publica e segura a transação; A tenta editar o template no meio.
# Esperado: a edição ESPERA a publicação terminar e é REJEITADA (template publicado).
# ----------------------------------------------------------------------------
echo "--- Sentido 2: publica o modelo e, no meio, edita o template"
preparar 2
{ echo "BEGIN;"; sql_publica 2; echo "SELECT pg_sleep($SEGURA);"; echo "COMMIT;"; } \
  | psql_ >"$TMP/b2.out" 2>&1 &
PID_B=$!
sleep 1
T0=$(agora_ms)
sql_inclui_campo 2 | psql_ >"$TMP/a2.out" 2>&1; RC_A=$?
T1=$(agora_ms); DUR_A=$((T1 - T0))
wait $PID_B; RC_B=$?
SIT=$(situacao 2); QTD=$(qtd_campos 2)
echo "    edição durou ${DUR_A} ms (rc=$RC_A); situação final=$SIT; campos no template=$QTD (rc publicação=$RC_B)"
if [ "$RC_B" -eq 0 ] && [ "$RC_A" -ne 0 ] && grep -q "publicado" "$TMP/a2.out" \
   && [ "$SIT" = "ATIVO" ] && [ "$QTD" = "1" ] && [ "$DUR_A" -ge "$LIMITE_BLOQUEIO_MS" ]; then
  ok "a edição esperou a publicação confirmar e foi rejeitada (template publicado)"
else
  falha "o template foi alterado durante a publicação (edição durou ${DUR_A} ms; campos=$QTD) ou o erro não foi o esperado"
  sed 's/^/    /' "$TMP/a2.out" "$TMP/b2.out"
fi

# ----------------------------------------------------------------------------
echo "--- Resultado"
if [ "$FALHAS" -eq 0 ]; then
  echo "VERIFICAÇÃO DE CONCORRÊNCIA OK"
  exit 0
fi
echo "VERIFICAÇÃO DE CONCORRÊNCIA FALHOU ($FALHAS sentido(s))"
exit 1
