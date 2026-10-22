# Executar na raiz do projeto: Rscript scripts/01_baixar_dados.R
# Requer acesso a internet; nao instala pacotes nem sobrescreve arquivos.
pacotes <- c("microdatasus", "sidrar", "purrr", "readr")
ausentes <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(ausentes)) {
  stop("Instale os pacotes antes de executar: ", paste(ausentes, collapse = ", "))
}
if (!file.exists("R/download.R")) {
  stop("Execute este script a partir da raiz do projeto.")
}

source("R/download.R")

# Mantem o periodo e os formatos de saida utilizados no codigo original.
anos <- 2015:2025
baixar_sinan("zika", anos, formato = c("csv", "rds"))

# Anos indisponiveis na tabela 6579 causam erro; nao sao imputados nesta etapa.
baixar_populacao(anos)
