package br.com.srportto.gestaocomprovantesquery.domain.model;

/** Campo do template variável (complementar, sem indexador). */
public record CampoVariavel(long idCampo, String nomeCampo, String tipoDado, int ordem, boolean aceitaNuloVazio,
        String descricaoCampoTemplate, String descricaoBase, String descricaoEfetiva) {
}
