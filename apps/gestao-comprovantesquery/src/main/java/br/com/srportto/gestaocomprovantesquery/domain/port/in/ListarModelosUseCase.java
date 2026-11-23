package br.com.srportto.gestaocomprovantesquery.domain.port.in;

import br.com.srportto.gestaocomprovantesquery.domain.model.ConsultaModelos;
import br.com.srportto.gestaocomprovantesquery.domain.model.ModeloResumo;
import br.com.srportto.gestaocomprovantesquery.domain.model.Pagina;

/** Porta de entrada: listagem simples, paginada e filtrável. */
public interface ListarModelosUseCase {

    Pagina<ModeloResumo> listar(ConsultaModelos consulta);
}
