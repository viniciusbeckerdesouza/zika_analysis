carregar_download <- function() {
  ambiente <- new.env(parent = globalenv())
  raiz <- if (file.exists("R/download.R")) "." else "../.."
  sys.source(file.path(raiz, "R/download.R"), envir = ambiente)

  # Substitui somente as consultas externas; gravacoes usam arquivos temporarios.
  ambiente$getExportedValue <- function(pkg, name) {
    stopifnot(pkg == "microdatasus", name == "process_sinan_zika")
    function(dados) {
      stopifnot(is.numeric(dados$NU_IDADE_N))
      dados$processado <- TRUE
      dados
    }
  }
  ambiente$`::` <- function(pkg, name) {
    pacote <- as.character(substitute(pkg))
    funcao <- as.character(substitute(name))
    if (pacote == "microdatasus" && funcao == "fetch_datasus") {
      return(function(year_start, year_end, information_system) {
        stopifnot(year_start == year_end, information_system == "SINAN-ZIKA")
        data.frame(NU_IDADE_N = factor("4025"), ano = year_start)
      })
    }
    if (pacote == "sidrar" && funcao == "get_sidra") {
      return(function(api) {
        ano <- as.integer(sub(".*/", "", api))
        dados <- data.frame(codigo = "3550308", Ano = ano, Valor = "12000000")
        names(dados)[1] <- "Munic\u00edpio (C\u00f3digo)"
        dados
      })
    }
    getExportedValue(pacote, funcao)
  }
  ambiente
}

testthat::test_that("SINAN preserva nomes, formatos e processamento anual", {
  ambiente <- carregar_download()
  diretorio <- withr::local_tempdir()
  withr::local_dir(diretorio)

  arquivos <- ambiente$baixar_sinan("ZIKA", 2015:2016)
  testthat::expect_setequal(
    arquivos,
    c("zika/ZIKA15.csv", "zika/ZIKA16.csv", "zika/ZIKA15.rds", "zika/ZIKA16.rds")
  )
  testthat::expect_true(all(file.exists(arquivos)))
  dados <- readRDS("zika/ZIKA15.rds")
  testthat::expect_equal(dados$NU_IDADE_N, 4025)
  testthat::expect_true(dados$processado)
  testthat::expect_equal(read.csv("zika/ZIKA16.csv")$ano, 2016)
  testthat::expect_error(ambiente$baixar_sinan("zika", 2015), "ja existentes")
  testthat::expect_identical(readRDS("zika/ZIKA15.rds"), dados)
})

testthat::test_that("SINAN interrompe falha de processamento sem salvar dados brutos", {
  ambiente <- carregar_download()
  diretorio <- withr::local_tempdir()
  withr::local_dir(diretorio)
  ambiente$getExportedValue <- function(pkg, name) {
    function(dados) stop("Falha de processamento simulada")
  }
  testthat::expect_error(
    ambiente$baixar_sinan("zika", 2015, "rds"), "Falha de processamento simulada"
  )
  testthat::expect_length(list.files("zika"), 0L)
})

testthat::test_that("entradas invalidas sao recusadas antes do download", {
  ambiente <- carregar_download()
  for (anos in list(numeric(), NA_real_, 2015.5, c(2015, 2015), Inf, "2015")) {
    testthat::expect_error(ambiente$baixar_sinan("zika", anos), "anos deve")
    testthat::expect_error(ambiente$baixar_populacao(anos), "anos deve")
  }
  testthat::expect_error(ambiente$baixar_sinan("../zika", 2015), "agravo deve")
  testthat::expect_error(ambiente$baixar_sinan("zika", 2015, "txt"))
})

testthat::test_that("populacao preserva esquema e grava apenas consolidado completo", {
  ambiente <- carregar_download()
  diretorio <- withr::local_tempdir()
  withr::local_dir(diretorio)

  arquivos <- ambiente$baixar_populacao(2015:2016)
  testthat::expect_true(all(file.exists(arquivos)))
  dados <- readRDS(arquivos[1])
  testthat::expect_equal(dados$Ano, 2015:2016)
  testthat::expect_named(dados, c("Munic\u00edpio (C\u00f3digo)", "Ano", "Valor"))
  testthat::expect_error(ambiente$baixar_populacao(2015:2016), "ja existentes")
  testthat::expect_identical(readRDS(arquivos[1]), dados)

  ambiente$`::` <- function(pkg, name) {
    pacote <- as.character(substitute(pkg))
    if (pacote == "sidrar") {
      return(function(api) stop("Ano indisponivel"))
    }
    if (pacote == "purrr") return(purrr::map_dfr)
    stop("Consulta inesperada")
  }
  testthat::expect_error(ambiente$baixar_populacao(2022:2023), "Ano indisponivel")
  testthat::expect_false(file.exists("dados/populacao_municipios_2022_2023.rds"))
  testthat::expect_false(file.exists("dados/populacao_municipios_2022_2023.csv"))
})
