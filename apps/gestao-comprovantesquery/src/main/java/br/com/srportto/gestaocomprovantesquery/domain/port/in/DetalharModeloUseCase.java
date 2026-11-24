package br.com.srportto.gestaocomprovantesquery.domain.port.in;

import br.com.srportto.gestaocomprovantesquery.domain.model.ChaveModelo;
import br.com.srportto.gestaocomprovantesquery.domain.model.ModeloDetalhe;

/** Porta de entrada: detalhe de um modelo com seus campos. */
public interface DetalharModeloUseCase {

    /** Lança ModeloNaoEncontradoException se a chave não existir. */
    ModeloDetalhe detalhar(ChaveModelo chave);
}
