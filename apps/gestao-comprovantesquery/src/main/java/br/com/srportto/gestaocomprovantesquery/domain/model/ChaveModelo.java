package br.com.srportto.gestaocomprovantesquery.domain.model;

import br.com.srportto.gestaocomprovantesquery.domain.exception.ParametrosInvalidosException;

/** Chave de negócio do modelo: {@code (idModelo, versao)}. Ambos obrigatórios. */
public record ChaveModelo(String idModelo, int versao) {

    public static ChaveModelo de(String idModelo, String versao) {
        var validacao = new Validacao();
        var idValido = validacao.idModelo(idModelo, true);
        var versaoValida = validacao.versao(versao, true);
        if (!validacao.erros().isEmpty()) {
            throw new ParametrosInvalidosException(validacao.erros());
        }
        return new ChaveModelo(idValido, versaoValida);
    }
}
