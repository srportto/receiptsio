package br.com.srportto.gestaocomprovantesquery.application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;

import br.com.srportto.gestaocomprovantesquery.application.usecase.DetalharModeloService;
import br.com.srportto.gestaocomprovantesquery.application.usecase.ListarModelosService;
import br.com.srportto.gestaocomprovantesquery.domain.exception.ModeloNaoEncontradoException;
import br.com.srportto.gestaocomprovantesquery.domain.model.ChaveModelo;
import br.com.srportto.gestaocomprovantesquery.domain.model.ConsultaModelos;
import br.com.srportto.gestaocomprovantesquery.domain.model.ModeloDetalhe;
import br.com.srportto.gestaocomprovantesquery.domain.model.ModeloResumo;
import br.com.srportto.gestaocomprovantesquery.domain.model.PageRequest;
import br.com.srportto.gestaocomprovantesquery.domain.model.Pagina;
import br.com.srportto.gestaocomprovantesquery.domain.model.Situacao;
import br.com.srportto.gestaocomprovantesquery.domain.port.out.CatalogoModelos;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** Casos de uso com a porta de saída simulada: o filtro é repassado e a ausência vira exceção de domínio. */
class CasosDeUsoTest {

    /** Porta simulada: registra o que recebeu e devolve o que foi preparado. */
    static class CatalogoFalso implements CatalogoModelos {
        final List<ConsultaModelos> consultas = new ArrayList<>();
        final List<ChaveModelo> chaves = new ArrayList<>();
        Pagina<ModeloResumo> paginaPronta;
        Optional<ModeloDetalhe> detalhePronto = Optional.empty();

        @Override
        public Pagina<ModeloResumo> listar(ConsultaModelos consulta) {
            consultas.add(consulta);
            return paginaPronta;
        }

        @Override
        public Optional<ModeloDetalhe> buscar(ChaveModelo chave) {
            chaves.add(chave);
            return detalhePronto;
        }
    }

    @Test
    @DisplayName("Listar repassa a consulta à porta e devolve a página dela")
    void listar() {
        var catalogo = new CatalogoFalso();
        var resumo = new ModeloResumo("COMPPIX", 2, "PIX", Situacao.ATIVO, OffsetDateTime.now());
        catalogo.paginaPronta = Pagina.de(List.of(resumo), new PageRequest(1, 20), 1);
        var consulta = ConsultaModelos.de("ATIVO", "COMPPIX", null, null, null);

        var pagina = new ListarModelosService(catalogo).listar(consulta);

        assertSame(catalogo.paginaPronta, pagina);
        assertEquals(List.of(consulta), catalogo.consultas);
    }

    @Test
    @DisplayName("Detalhar devolve o modelo encontrado")
    void detalhar() {
        var catalogo = new CatalogoFalso();
        var detalhe = ModeloDetalheFabrica.simples();
        catalogo.detalhePronto = Optional.of(detalhe);
        var chave = ChaveModelo.de("COMPPIX", "2");

        assertSame(detalhe, new DetalharModeloService(catalogo).detalhar(chave));
        assertEquals(List.of(chave), catalogo.chaves);
    }

    @Test
    @DisplayName("Detalhar modelo inexistente lança ModeloNaoEncontradoException com a chave")
    void naoEncontrado() {
        var servico = new DetalharModeloService(new CatalogoFalso());
        var erro = assertThrows(ModeloNaoEncontradoException.class,
                () -> servico.detalhar(ChaveModelo.de("COMPPIX", "999")));
        assertEquals("Não existe o modelo COMPPIX versão 999.", erro.getMessage());
    }
}
