package br.com.srportto.gestaocomprovantesquery.domain.model;

/** Um parâmetro inválido da requisição e o motivo, em linguagem para o cliente. */
public record ErroParametro(String parametro, String mensagem) {
}
