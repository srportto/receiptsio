package br.com.srportto.gestaocomprovantesquery.domain.model;

import java.time.OffsetDateTime;

/** Linha da listagem simples. */
public record ModeloResumo(String idModelo, int versao, String descricao, Situacao situacao,
        OffsetDateTime dataHoraAtualizacao) {
}
