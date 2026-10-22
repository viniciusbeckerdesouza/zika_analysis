# Executar na raiz: Rscript scripts/02_preparar_dados.R
# Consome os arquivos da etapa de download; nao realiza consultas externas.
pacotes <- c("dplyr", "purrr", "lubridate")
ausentes <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(ausentes)) {
  stop("Instale os pacotes antes de executar: ", paste(ausentes, collapse = ", "))
}
if (!file.exists("R/limpeza.R")) {
  stop("Execute este script a partir da raiz do projeto.")
}

source("R/limpeza.R")

# Ajustar o periodo em conjunto com a etapa de download.
anos <- 2015:2025
arquivo_pop <- file.path(
  "dados", paste0("populacao_municipios_", min(anos), "_", max(anos), ".rds")
)
dir_saida <- file.path("dados", "processados")
arquivos_saida <- file.path(
  dir_saida,
  c(
    paste0("ZIKA_", min(anos), "_", max(anos), ".rds"),
    paste0("populacao_municipios_", min(anos), "_", max(anos), ".rds")
  )
)

# Confere ambas as saidas antes da leitura; bases existentes nao sao sobrescritas.
existentes <- arquivos_saida[file.exists(arquivos_saida)]
if (length(existentes)) {
  stop("Arquivos ja existentes; nenhum sera sobrescrito: ",
       paste(existentes, collapse = ", "))
}

ZIKA <- preparar_zika(anos, dir_zika = "zika")
pop_municipios <- preparar_populacao(arquivo_pop, anos)

# Conserva a verificacao de estrutura e cobertura temporal do script original.
dplyr::glimpse(ZIKA)
print(
  ZIKA |>
    dplyr::summarise(
      registros = dplyr::n(),
      primeiro_ano = if (all(is.na(ANO))) NA_integer_ else min(ANO, na.rm = TRUE),
      ultimo_ano = if (all(is.na(ANO))) NA_integer_ else max(ANO, na.rm = TRUE),
      datas_ausentes = sum(is.na(DT_NOTIFIC))
    )
)
dplyr::glimpse(pop_municipios)

# Grava somente apos preparar as duas bases; os arquivos de entrada permanecem intactos.
if (!dir.exists(dir_saida) &&
    !dir.create(dir_saida, recursive = TRUE, showWarnings = FALSE)) {
  stop("Nao foi possivel criar o diretorio: ", dir_saida)
}
saveRDS(ZIKA, arquivos_saida[1])
saveRDS(pop_municipios, arquivos_saida[2])
message("OK: bases preparadas em ", dir_saida)
