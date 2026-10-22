raiz_preparacao <- normalizePath(
  if (file.exists("R/limpeza.R")) "." else "../.."
)
ambiente_preparacao <- new.env(parent = globalenv())
sys.source(file.path(raiz_preparacao, "R/limpeza.R"), envir = ambiente_preparacao)

criar_zika_sintetica <- function() {
  data.frame(
    DT_NOTIFIC = as.Date(c("2015-01-10", "2015-02-02", NA)),
    DT_SIN_PRI = as.Date(c("2014-12-30", "2015-01-30", NA)),
    DT_OBITO = as.Date(c(NA, NA, NA)),
    IDADEanos = c(4, 5, NA),
    ID_MN_RESI = c("355030", "355030", NA),
    CLASSI_FIN = c("Confirmado", "Descartado", NA)
  )
}

criar_populacao_sintetica <- function(anos = 2015:2016) {
  dados <- data.frame(
    codigo = factor(rep("3550308", length(anos))),
    Ano = factor(as.character(anos)),
    Valor = factor(rep("12000000", length(anos)))
  )
  names(dados)[1] <- "Munic\u00edpio (C\u00f3digo)"
  dados
}

testthat::test_that("preparacao ZIKA preserva transformacoes e registros originais", {
  diretorio <- withr::local_tempdir()
  dados <- criar_zika_sintetica()
  saveRDS(dados, file.path(diretorio, "ZIKA15.rds"))
  obtido <- ambiente_preparacao$preparar_zika(2015, diretorio)

  esperado <- dplyr::mutate(
    dados,
    DT_NOTIFIC = as.Date(DT_NOTIFIC),
    DT_SIN_PRI = as.Date(DT_SIN_PRI),
    DT_OBITO = as.Date(DT_OBITO),
    ANO = lubridate::year(DT_NOTIFIC),
    MES = lubridate::month(DT_NOTIFIC),
    IDADE = as.numeric(IDADEanos),
    FAIXA_ETARIA = cut(
      IDADE, c(-Inf, 4, 11, 17, 29, 39, 49, 59, 69, Inf),
      labels = c(
        "0\u20134", "5\u201311", "12\u201317", "18\u201329", "30\u201339",
        "40\u201349", "50\u201359", "60\u201369", "70+"
      )
    )
  )
  testthat::expect_equal(obtido[names(esperado)], esperado)
  testthat::expect_equal(obtido$ANO[1], 2015)
  testthat::expect_equal(nrow(obtido), nrow(dados))
  testthat::expect_identical(readRDS(file.path(diretorio, "ZIKA15.rds")), dados)

  idades <- c(0, 4, 4.5, 5, 11, 12, 17, 18, 29, 30, 39, 40,
              49, 50, 59, 60, 69, 70, NA)
  dados <- dados[rep(1, length(idades)), ]
  dados$IDADEanos <- factor(as.character(idades))
  saveRDS(dados, file.path(diretorio, "ZIKA16.rds"))
  resultado <- ambiente_preparacao$preparar_zika(2016, diretorio)
  testthat::expect_equal(resultado$IDADE, idades)
  testthat::expect_equal(
    as.integer(resultado$FAIXA_ETARIA),
    c(1L, 1L, 2L, 2L, 2L, 3L, 3L, 4L, 4L, 5L, 5L,
      6L, 6L, 7L, 7L, 8L, 8L, 9L, NA_integer_)
  )
})

testthat::test_that("arquivos ausentes e esquemas invalidos interrompem a leitura", {
  diretorio <- withr::local_tempdir()
  saveRDS(criar_zika_sintetica(), file.path(diretorio, "ZIKA15.rds"))
  testthat::expect_error(
    ambiente_preparacao$preparar_zika(2015:2016, diretorio), "ZIKA16"
  )
  dados <- criar_zika_sintetica()
  dados$IDADEanos <- NULL
  saveRDS(dados, file.path(diretorio, "ZIKA16.rds"))
  testthat::expect_error(
    ambiente_preparacao$preparar_zika(2015:2016, diretorio), "IDADEanos"
  )
  dados <- criar_zika_sintetica()
  dados$DT_NOTIFIC <- c("invalida", NA, NA)
  saveRDS(dados, file.path(diretorio, "ZIKA16.rds"))
  testthat::expect_error(
    ambiente_preparacao$preparar_zika(2016, diretorio), "Data invalida"
  )
})

testthat::test_that("populacao conserva padronizacao original e detecta conflitos", {
  diretorio <- withr::local_tempdir()
  arquivo <- file.path(diretorio, "pop.rds")
  dados <- criar_populacao_sintetica()
  saveRDS(rbind(dados, dados[1, ]), arquivo)
  obtido <- ambiente_preparacao$preparar_populacao(arquivo, 2015:2016)
  testthat::expect_equal(
    obtido,
    data.frame(ID_MN_RESI = c("355030", "355030"), ANO = 2015:2016,
               populacao = c(12000000, 12000000))
  )
  testthat::expect_error(
    ambiente_preparacao$preparar_populacao(arquivo, 2015:2017), "2017"
  )

  dados$Valor <- c(12000000, 0)
  saveRDS(dados, arquivo)
  testthat::expect_error(
    ambiente_preparacao$preparar_populacao(arquivo, 2015:2016), "denominador invalido"
  )
  dados$Valor <- c(12000000, 13000000)
  dados$Ano <- c(2015, 2015)
  saveRDS(dados, arquivo)
  testthat::expect_error(
    ambiente_preparacao$preparar_populacao(arquivo, 2015), "conflitantes"
  )
})

testthat::test_that("script prepara e persiste as bases sem sobrescrever saidas", {
  diretorio <- withr::local_tempdir()
  withr::local_dir(diretorio)
  dir.create("R")
  dir.create("zika")
  dir.create("dados")
  file.copy(file.path(raiz_preparacao, "R/limpeza.R"), "R/limpeza.R")
  for (ano in 2015:2025) {
    saveRDS(criar_zika_sintetica(), sprintf("zika/ZIKA%02d.rds", ano %% 100))
  }
  saveRDS(
    criar_populacao_sintetica(2015:2025),
    "dados/populacao_municipios_2015_2025.rds"
  )
  script <- file.path(raiz_preparacao, "scripts/02_preparar_dados.R")
  ambiente <- new.env(parent = globalenv())
  invisible(capture.output(sys.source(script, envir = ambiente)))
  saida <- "dados/processados/ZIKA_2015_2025.rds"
  testthat::expect_equal(nrow(readRDS(saida)), 33L)
  testthat::expect_equal(
    nrow(readRDS("dados/processados/populacao_municipios_2015_2025.rds")), 11L
  )
  antes <- tools::md5sum(saida)
  testthat::expect_error(sys.source(script, envir = ambiente), "ja existentes")
  testthat::expect_identical(tools::md5sum(saida), antes)
})

testthat::test_that("falha na populacao impede a gravacao de ambas as bases", {
  diretorio <- withr::local_tempdir()
  withr::local_dir(diretorio)
  dir.create("R")
  dir.create("zika")
  file.copy(file.path(raiz_preparacao, "R/limpeza.R"), "R/limpeza.R")
  for (ano in 2015:2025) {
    saveRDS(criar_zika_sintetica(), sprintf("zika/ZIKA%02d.rds", ano %% 100))
  }
  testthat::expect_error(
    sys.source(
      file.path(raiz_preparacao, "scripts/02_preparar_dados.R"),
      envir = new.env(parent = globalenv())
    ),
    "Arquivo de populacao ausente"
  )
  testthat::expect_false(dir.exists("dados/processados"))
})
