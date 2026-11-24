package br.com.srportto.gestaocomprovantesquery.domain.model;

import br.com.srportto.gestaocomprovantesquery.domain.exception.ParametrosInvalidosException;

/**
 * Consulta da listagem: filtros opcionais (nulo = não filtra) e a página pedida.
 * Nasce validada: {@link #de} acumula todos os erros e os lança juntos.
 */
public record ConsultaModelos(Situacao situacao, String idModelo, Integer versao, PageRequest pagina) {

    public static ConsultaModelos de(String situacao, String idModelo, String versao, String page, String size) {
        var validacao = new Validacao();
        var situacaoValida = validacao.situacao(situacao);
        var idValido = validacao.idModelo(idModelo, false);
        var versaoValida = validacao.versao(versao, false);
        int pageValida = validacao.page(page);
        int sizeValido = validacao.size(size);
        if (!validacao.erros().isEmpty()) {
            throw new ParametrosInvalidosException(validacao.erros());
        }
        return new ConsultaModelos(situacaoValida, idValido, versaoValida, new PageRequest(pageValida, sizeValido));
    }
}
