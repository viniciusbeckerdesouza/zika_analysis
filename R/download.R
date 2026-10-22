# Baixa e processa cada ano separadamente para limitar o uso de memoria.
# Mantem os nomes anuais do script original: ZIKA15.rds, ZIKA16.rds etc.
baixar_sinan <- function(agravo, anos, formato = c("csv", "rds")) {
  formato <- match.arg(formato, choices = c("csv", "rds"), several.ok = TRUE)

  if (length(agravo) != 1L || is.na(agravo) ||
      !grepl("^[A-Za-z]+$", agravo)) {
    stop("agravo deve conter apenas letras e identificar um unico agravo.")
  }
  if (!is.numeric(anos) || !length(anos) || anyNA(anos) ||
      any(!is.finite(anos) | anos != trunc(anos) | anos < 1900 | anos > 2099) ||
      anyDuplicated(anos)) {
    stop("anos deve conter anos inteiros, distintos, entre 1900 e 2099.")
  }

  agravo <- tolower(agravo)
  nomes_base <- file.path(
    agravo, paste0(toupper(agravo), sprintf("%02d", anos %% 100))
  )
  arquivos <- unlist(lapply(formato, function(ext) paste0(nomes_base, ".", ext)))

  # Verifica todas as saidas antes de iniciar a transferencia.
  existentes <- arquivos[file.exists(arquivos)]
  if (length(existentes)) {
    stop("Arquivos ja existentes; nenhum sera sobrescrito: ",
         paste(existentes, collapse = ", "))
  }

  # Resolve a funcao no namespace para nao depender de library() ou do ambiente global.
  nome_funcao_processar <- paste0("process_sinan_", agravo)
  processar <- getExportedValue("microdatasus", nome_funcao_processar)

  if (!dir.exists(agravo) &&
      !dir.create(agravo, recursive = TRUE, showWarnings = FALSE)) {
    stop("Nao foi possivel criar o diretorio: ", agravo)
  }

  for (i in seq_along(anos)) {
    ano <- anos[i]
    message("Baixando SINAN-", toupper(agravo), ": ", ano)

    dados <- microdatasus::fetch_datasus(
      year_start = ano,
      year_end = ano,
      information_system = paste0("SINAN-", toupper(agravo))
    )
    if (!is.data.frame(dados) || nrow(dados) == 0L) {
      stop("SINAN sem registros para ", agravo, " em ", ano, ".")
    }

    # Preserva a conversao utilizada antes do processamento no script original.
    if ("NU_IDADE_N" %in% names(dados)) {
      dados$NU_IDADE_N <- as.numeric(as.character(dados$NU_IDADE_N))
    }

    # Falhas interrompem a etapa; dados brutos nao substituem dados processados.
    dados <- processar(dados)
    if (!is.data.frame(dados) || nrow(dados) == 0L) {
      stop("Processamento SINAN sem registros para ", agravo, " em ", ano, ".")
    }

    if ("csv" %in% formato) {
      write.csv(
        dados, paste0(nomes_base[i], ".csv"),
        row.names = FALSE, fileEncoding = "UTF-8"
      )
    }
    if ("rds" %in% formato) {
      saveRDS(dados, paste0(nomes_base[i], ".rds"))
    }

    message("OK: ", agravo, " ", ano, " (", nrow(dados), " registros)")
  }

  invisible(arquivos)
}

# Consulta a mesma tabela, variavel e abrangencia municipal do script original.
# Mantem os campos retornados pelo SIDRA, sem interpolar populacoes ausentes.
baixar_populacao <- function(anos) {
  if (!is.numeric(anos) || !length(anos) || anyNA(anos) ||
      any(!is.finite(anos) | anos != trunc(anos) | anos < 1900 | anos > 2099) ||
      anyDuplicated(anos)) {
    stop("anos deve conter anos inteiros, distintos, entre 1900 e 2099.")
  }

  nome_base <- file.path(
    "dados", paste0("populacao_municipios_", min(anos), "_", max(anos))
  )
  arquivos <- paste0(nome_base, c(".rds", ".csv"))
  existentes <- arquivos[file.exists(arquivos)]
  if (length(existentes)) {
    stop("Arquivos ja existentes; nenhum sera sobrescrito: ",
         paste(existentes, collapse = ", "))
  }

  if (!dir.exists("dados") &&
      !dir.create("dados", recursive = TRUE, showWarnings = FALSE)) {
    stop("Nao foi possivel criar o diretorio dados.")
  }

  pop_municipios <- purrr::map_dfr(anos, function(ano) {
    message("Baixando populacao de ", ano)
    dados <- sidrar::get_sidra(
      api = paste0("/t/6579/n6/all/v/9324/p/", ano)
    )

    # Evita salvar uma extracao incompleta ou uma resposta com esquema inesperado.
    colunas <- c("Munic\u00edpio (C\u00f3digo)", "Ano", "Valor")
    if (!is.data.frame(dados) || nrow(dados) == 0L ||
        !all(colunas %in% names(dados))) {
      stop("Resposta SIDRA vazia ou invalida para ", ano, ".")
    }
    if (anyNA(dados$Ano) || any(as.character(dados$Ano) != as.character(ano))) {
      stop("A resposta SIDRA nao corresponde ao ano solicitado: ", ano, ".")
    }
    dados
  })

  # Grava o consolidado somente depois de receber todos os anos solicitados.
  saveRDS(pop_municipios, paste0(nome_base, ".rds"))
  readr::write_csv(pop_municipios, paste0(nome_base, ".csv"))
  message("OK: populacao ", min(anos), "-", max(anos))

  invisible(arquivos)
}
