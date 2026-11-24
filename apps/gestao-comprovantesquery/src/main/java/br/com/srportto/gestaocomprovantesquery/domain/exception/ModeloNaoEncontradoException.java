package br.com.srportto.gestaocomprovantesquery.domain.exception;

import br.com.srportto.gestaocomprovantesquery.domain.model.ChaveModelo;

/** Não existe modelo com a chave pedida (vira 404 na borda). */
public class ModeloNaoEncontradoException extends RuntimeException {

    public ModeloNaoEncontradoException(ChaveModelo chave) {
        super("Não existe o modelo " + chave.idModelo() + " versão " + chave.versao() + ".");
    }
}
