# Le os arquivos anuais processados pelo microdatasus e preserva suas colunas.
# ANO e MES seguem a data de notificacao, conforme o script original.
preparar_zika <- function(anos, dir_zika = "zika") {
  if (!is.numeric(anos) || !length(anos) || anyNA(anos) ||
      any(!is.finite(anos) | anos != trunc(anos) | anos < 1900 | anos > 2099) ||
      anyDuplicated(anos)) {
    stop("anos deve conter anos inteiros, distintos, entre 1900 e 2099.")
  }

  arquivos <- file.path(dir_zika, sprintf("ZIKA%02d.rds", anos %% 100))
  faltantes <- arquivos[!file.exists(arquivos)]
  if (length(faltantes)) {
    stop("Arquivos SINAN ausentes: ", paste(faltantes, collapse = ", "))
  }

  # Valida por arquivo para que colunas ausentes nao sejam preenchidas pela uniao.
  ZIKA <- purrr::map_dfr(arquivos, function(arquivo) {
    dados <- readRDS(arquivo)
    obrigatorias <- c("DT_NOTIFIC", "DT_SIN_PRI", "DT_OBITO", "IDADEanos")
    if (!is.data.frame(dados) || nrow(dados) == 0L) {
      stop("Arquivo SINAN sem registros tabulares: ", arquivo)
    }
    ausentes <- setdiff(obrigatorias, names(dados))
    if (length(ausentes)) {
      stop("Colunas ausentes em ", arquivo, ": ", paste(ausentes, collapse = ", "))
    }

    # Converte fatores pelos rotulos, nao pelos indices internos.
    for (coluna in c("DT_NOTIFIC", "DT_SIN_PRI", "DT_OBITO")) {
      original <- dados[[coluna]]
      convertido <- as.Date(as.character(original), format = "%Y-%m-%d")
      if (any(!is.na(original) & is.na(convertido))) {
        stop("Data invalida em ", arquivo, ", coluna ", coluna, ".")
      }
      dados[[coluna]] <- convertido
    }
    idade <- as.numeric(as.character(dados$IDADEanos))
    if (any(!is.na(dados$IDADEanos) & (is.na(idade) | !is.finite(idade)))) {
      stop("IDADEanos invalida em ", arquivo, ".")
    }
    dados$IDADE <- idade
    dados
  })

  ZIKA <- ZIKA |>
    dplyr::mutate(
      ANO = lubridate::year(DT_NOTIFIC),
      MES = lubridate::month(DT_NOTIFIC),
      FAIXA_ETARIA = cut(
        IDADE,
        breaks = c(-Inf, 4, 11, 17, 29, 39, 49, 59, 69, Inf),
        labels = c(
          "0\u20134", "5\u201311", "12\u201317", "18\u201329", "30\u201339",
          "40\u201349", "50\u201359", "60\u201369", "70+"
        )
      )
    )

  # Nao filtra registros, remove duplicidades ou altera os limites etarios originais.
  # Idades fracionarias seguem os intervalos de cut(), sem arredondamento.
  ZIKA
}

# Padroniza a populacao SIDRA para as juncoes por municipio e ano.
# Nao interpola valores nem substitui denominadores ausentes por zero.
preparar_populacao <- function(arquivo_pop, anos) {
  if (!is.numeric(anos) || !length(anos) || anyNA(anos) ||
      any(!is.finite(anos) | anos != trunc(anos) | anos < 1900 | anos > 2099) ||
      anyDuplicated(anos)) {
    stop("anos deve conter anos inteiros, distintos, entre 1900 e 2099.")
  }
  if (!file.exists(arquivo_pop)) {
    stop("Arquivo de populacao ausente: ", arquivo_pop)
  }
  pop_municipios <- readRDS(arquivo_pop)
  colunas <- c("Munic\u00edpio (C\u00f3digo)", "Ano", "Valor")
  if (!is.data.frame(pop_municipios) || nrow(pop_municipios) == 0L ||
      !all(colunas %in% names(pop_municipios))) {
    stop("Arquivo de populacao vazio ou sem as colunas SIDRA obrigatorias.")
  }

  pop_municipios <- pop_municipios |>
    dplyr::mutate(
      ID_MN_RESI = substr(as.character(.data[[colunas[1]]]), 1, 6),
      ANO = as.numeric(as.character(Ano)),
      populacao = as.numeric(as.character(Valor))
    ) |>
    dplyr::select(ID_MN_RESI, ANO, populacao) |>
    dplyr::distinct()

  # Valida antes do filtro para nao ocultar falhas de conversao.
  if (anyNA(pop_municipios) ||
      any(!grepl("^[0-9]{6}$", pop_municipios$ID_MN_RESI)) ||
      any(!is.finite(pop_municipios$ANO) |
          pop_municipios$ANO != trunc(pop_municipios$ANO)) ||
      any(!is.finite(pop_municipios$populacao) | pop_municipios$populacao <= 0)) {
    stop("Populacao com municipio, ano ou denominador invalido.")
  }
  pop_municipios <- pop_municipios |>
    dplyr::mutate(ANO = as.integer(ANO)) |>
    dplyr::filter(ANO %in% anos)

  faltantes <- setdiff(anos, pop_municipios$ANO)
  if (length(faltantes)) {
    stop("Anos ausentes na populacao: ", paste(faltantes, collapse = ", "))
  }
  # distinct() remove copias exatas; valores conflitantes nao podem multiplicar casos.
  if (anyDuplicated(pop_municipios[c("ID_MN_RESI", "ANO")])) {
    stop("Populacoes conflitantes para a mesma chave municipio-ano.")
  }

  pop_municipios
}
