package br.com.srportto.gestaocomprovantesquery.application.usecase;

import br.com.srportto.gestaocomprovantesquery.domain.model.ConsultaModelos;
import br.com.srportto.gestaocomprovantesquery.domain.model.ModeloResumo;
import br.com.srportto.gestaocomprovantesquery.domain.model.Pagina;
import br.com.srportto.gestaocomprovantesquery.domain.port.in.ListarModelosUseCase;
import br.com.srportto.gestaocomprovantesquery.domain.port.out.CatalogoModelos;

/** Caso de uso sem anotação de framework; o bean é declarado em {@code infrastructure/config}. */
public class ListarModelosService implements ListarModelosUseCase {

    private final CatalogoModelos catalogo;

    public ListarModelosService(CatalogoModelos catalogo) {
        this.catalogo = catalogo;
    }

    @Override
    public Pagina<ModeloResumo> listar(ConsultaModelos consulta) {
        return catalogo.listar(consulta);
    }
}
