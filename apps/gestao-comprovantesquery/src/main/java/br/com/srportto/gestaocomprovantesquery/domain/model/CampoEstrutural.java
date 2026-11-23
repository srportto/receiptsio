package br.com.srportto.gestaocomprovantesquery.domain.model;

/** Campo do template estrutural; {@code posicaoIndexador} é nulo quando o campo não é indexador. */
public record CampoEstrutural(long idCampo, String nomeCampo, String tipoDado, int ordem, boolean aceitaNuloVazio,
        Integer posicaoIndexador, String descricaoCampoTemplate, String descricaoBase, String descricaoEfetiva) {
}
