package br.com.srportto.gestaocomprovantesquery.domain.model;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/** Converte parâmetros em texto para tipos válidos, acumulando todos os erros em vez de parar no primeiro. */
final class Validacao {

    private static final Pattern ID_MODELO = Pattern.compile("[A-Z0-9_]{1,10}");

    private final List<ErroParametro> erros = new ArrayList<>();

    private static boolean ausente(String valor) {
        return valor == null || valor.isBlank();
    }

    /** Opcional: ausente ou em branco vale null. */
    Situacao situacao(String valor) {
        if (ausente(valor)) {
            return null;
        }
        try {
            return Situacao.valueOf(valor.strip());
        } catch (IllegalArgumentException e) {
            erros.add(new ErroParametro("situacao", "deve ser RASCUNHO, ATIVO ou INATIVO"));
            return null;
        }
    }

    String idModelo(String valor, boolean obrigatorio) {
        if (ausente(valor)) {
            if (obrigatorio) {
                erros.add(new ErroParametro("idModelo", "é obrigatório"));
            }
            return null;
        }
        if (!ID_MODELO.matcher(valor.strip()).matches()) {
            erros.add(new ErroParametro("idModelo", "deve ter de 1 a 10 caracteres entre A-Z, 0-9 e _"));
            return null;
        }
        return valor.strip();
    }

    Integer versao(String valor, boolean obrigatorio) {
        if (ausente(valor)) {
            if (obrigatorio) {
                erros.add(new ErroParametro("versao", "é obrigatória"));
            }
            return null;
        }
        return inteiro("versao", valor, 1, 999, null, "deve ser um inteiro de 1 a 999");
    }

    int page(String valor) {
        return inteiro("page", valor, 1, Integer.MAX_VALUE, 1, "deve ser um inteiro maior ou igual a 1");
    }

    int size(String valor) {
        return inteiro("size", valor, 1, PageRequest.TAMANHO_MAXIMO, PageRequest.TAMANHO_PADRAO,
                "deve ser um inteiro de 1 a " + PageRequest.TAMANHO_MAXIMO);
    }

    private Integer inteiro(String parametro, String valor, int minimo, int maximo, Integer padrao,
            String mensagem) {
        if (ausente(valor)) {
            return padrao;
        }
        try {
            int numero = Integer.parseInt(valor.strip());
            if (numero >= minimo && numero <= maximo) {
                return numero;
            }
        } catch (NumberFormatException e) {
            // não é inteiro (ou estoura int): cai no registro do erro logo abaixo
        }
        erros.add(new ErroParametro(parametro, mensagem));
        return padrao;
    }

    List<ErroParametro> erros() {
        return erros;
    }
}
