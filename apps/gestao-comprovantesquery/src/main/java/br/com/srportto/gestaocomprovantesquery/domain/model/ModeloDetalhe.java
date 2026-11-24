package br.com.srportto.gestaocomprovantesquery.domain.model;

import java.time.OffsetDateTime;

/** Modelo completo: dados do modelo e campos dos dois templates. */
public record ModeloDetalhe(String idModelo, int versao, String descricao, Situacao situacao,
        OffsetDateTime dataHoraCriacao, OffsetDateTime dataHoraAtualizacao, TemplateEstrutural templateEstrutural,
        TemplateVariavel templateVariavel) {
}
