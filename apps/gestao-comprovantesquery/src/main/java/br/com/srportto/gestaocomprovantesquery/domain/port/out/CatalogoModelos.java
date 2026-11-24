package br.com.srportto.gestaocomprovantesquery.domain.port.out;

import br.com.srportto.gestaocomprovantesquery.domain.model.ChaveModelo;
import br.com.srportto.gestaocomprovantesquery.domain.model.ConsultaModelos;
import br.com.srportto.gestaocomprovantesquery.domain.model.ModeloDetalhe;
import br.com.srportto.gestaocomprovantesquery.domain.model.ModeloResumo;
import br.com.srportto.gestaocomprovantesquery.domain.model.Pagina;
import java.util.Optional;

/** Porta de saída: leitura do catálogo. Só consulta; não há operação de escrita. */
public interface CatalogoModelos {

    Pagina<ModeloResumo> listar(ConsultaModelos consulta);

    Optional<ModeloDetalhe> buscar(ChaveModelo chave);
}
