package br.com.srportto.gestaocomprovantesquery.application.usecase;

import br.com.srportto.gestaocomprovantesquery.domain.exception.ModeloNaoEncontradoException;
import br.com.srportto.gestaocomprovantesquery.domain.model.ChaveModelo;
import br.com.srportto.gestaocomprovantesquery.domain.model.ModeloDetalhe;
import br.com.srportto.gestaocomprovantesquery.domain.port.in.DetalharModeloUseCase;
import br.com.srportto.gestaocomprovantesquery.domain.port.out.CatalogoModelos;

/** Caso de uso sem anotação de framework; o bean é declarado em {@code infrastructure/config}. */
public class DetalharModeloService implements DetalharModeloUseCase {

    private final CatalogoModelos catalogo;

    public DetalharModeloService(CatalogoModelos catalogo) {
        this.catalogo = catalogo;
    }

    @Override
    public ModeloDetalhe detalhar(ChaveModelo chave) {
        return catalogo.buscar(chave).orElseThrow(() -> new ModeloNaoEncontradoException(chave));
    }
}
