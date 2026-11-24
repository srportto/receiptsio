package br.com.srportto.gestaocomprovantesquery.infrastructure.web;

import br.com.srportto.gestaocomprovantesquery.domain.model.ChaveModelo;
import br.com.srportto.gestaocomprovantesquery.domain.model.ConsultaModelos;
import br.com.srportto.gestaocomprovantesquery.domain.model.ModeloDetalhe;
import br.com.srportto.gestaocomprovantesquery.domain.model.ModeloResumo;
import br.com.srportto.gestaocomprovantesquery.domain.model.Pagina;
import br.com.srportto.gestaocomprovantesquery.domain.port.in.DetalharModeloUseCase;
import br.com.srportto.gestaocomprovantesquery.domain.port.in.ListarModelosUseCase;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Adaptador de entrada REST, somente leitura. O contrato está em
 * {@code docs/contratos-rest/gestao-comprovantesquery/openapi.yaml}; aqui não há anotação de contrato.
 *
 * <p>Os parâmetros chegam como texto para que a validação (e o 400 com todos os erros juntos) seja do domínio, e
 * não da conversão de tipos do Spring. Os registros de domínio têm os mesmos nomes do contrato e são serializados
 * diretamente; o teste de contrato impede que uma renomeação os separe.
 */
@RestController
public class ModelosController {

    private final ListarModelosUseCase listar;
    private final DetalharModeloUseCase detalhar;

    public ModelosController(ListarModelosUseCase listar, DetalharModeloUseCase detalhar) {
        this.listar = listar;
        this.detalhar = detalhar;
    }

    @GetMapping("/modelos")
    public Pagina<ModeloResumo> listar(
            @RequestParam(name = "situacao", required = false) String situacao,
            @RequestParam(name = "idModelo", required = false) String idModelo,
            @RequestParam(name = "versao", required = false) String versao,
            @RequestParam(name = "page", required = false) String page,
            @RequestParam(name = "size", required = false) String size) {
        return listar.listar(ConsultaModelos.de(situacao, idModelo, versao, page, size));
    }

    @GetMapping("/modelos/{idModelo}/versoes/{versao}")
    public ModeloDetalhe detalhar(@PathVariable("idModelo") String idModelo, @PathVariable("versao") String versao) {
        return detalhar.detalhar(ChaveModelo.de(idModelo, versao));
    }
}
