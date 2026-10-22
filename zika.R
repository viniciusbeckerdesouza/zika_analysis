# ============================================================
# SINAN - DATASUS
# ============================================================
pacman::p_load(tidyverse,
               lubridate,
               janitor,
               scales,
               microdatasus,
               sidrar,
               dplyr,
               purrr
               )


baixar_sinan <- function(agravo, anos) {
  
  dir.create(agravo, showWarnings = FALSE)
  
  processar <- get(
    paste0("process_sinan_", tolower(agravo))
  )
  
  for (ano in anos) {
    
    dados <- fetch_datasus(
      year_start = ano,
      year_end = ano,
      information_system = paste0("SINAN-", toupper(agravo))
    )
    
    if ("NU_IDADE_N" %in% names(dados)) {
      dados$NU_IDADE_N <- as.numeric(dados$NU_IDADE_N)
    }
    
    dados <- processar(dados)
    
    arquivo <- file.path(
      agravo,
      paste0(toupper(agravo), substr(ano, 3, 4), ".csv")
    )
    
    write.csv(
      dados,
      arquivo,
      row.names = FALSE,
      fileEncoding = "UTF-8"
    )
    
    message("OK: ", agravo, " ", ano)
  }
}

baixar_sinan <- function(agravo, anos, formato = c("csv", "rds")) {
  
  # Validação do formato
  formato <- match.arg(formato, choices = c("csv", "rds"), several.ok = TRUE)
  
  dir.create(agravo, showWarnings = FALSE)
  
  # Tenta localizar a função de processamento
  nome_funcao_processar <- paste0("process_sinan_", tolower(agravo))
  
  processar <- if (exists(nome_funcao_processar, mode = "function")) {
    get(nome_funcao_processar, mode = "function")
  } else {
    NULL
  }
  
  for (ano in anos) {
    
    dados <- fetch_datasus(
      year_start = ano,
      year_end = ano,
      information_system = paste0("SINAN-", toupper(agravo))
    )
    
    if ("NU_IDADE_N" %in% names(dados)) {
      dados$NU_IDADE_N <- as.numeric(dados$NU_IDADE_N)
    }
    
    # Aplica o processar com tryCatch
    if (!is.null(processar)) {
      dados <- tryCatch(
        {
          processar(dados)
        },
        error = function(e) {
          warning(
            "Erro ao processar '", agravo, "' para o ano ", ano, 
            ": ", e$message, "\nOs dados originais serão mantidos."
          )
          dados
        }
      )
    } else {
      message("Função '", nome_funcao_processar, "' não encontrada. Mantendo dados originais.")
    }
    
    # Nome base do arquivo sem extensão
    nome_base <- file.path(agravo, paste0(toupper(agravo), substr(ano, 3, 4)))
    
    # Salvando em CSV
    if ("csv" %in% formato) {
      arquivo_csv <- paste0(nome_base, ".csv")
      write.csv(
        dados,
        arquivo_csv,
        row.names = FALSE,
        fileEncoding = "UTF-8"
      )
    }
    
    # Salvando em RDS
    if ("rds" %in% formato) {
      arquivo_rds <- paste0(nome_base, ".rds")
      saveRDS(dados, arquivo_rds)
    }
    
    message("OK: ", agravo, " ", ano)
  }
}

baixar_sinan("zika", 2015:2025)

ZIKA <- map_dfr(2015:2025, \(ano) {
  readRDS(paste0("zika/ZIKA", sprintf("%02d", ano %% 100), ".rds"))
})


# Conferir estrutura
glimpse(ZIKA)

# Converter datas e variáveis numéricas
ZIKA <- ZIKA %>%
  mutate(
    DT_NOTIFIC = as.Date(DT_NOTIFIC),
    DT_SIN_PRI = as.Date(DT_SIN_PRI),
    DT_OBITO   = as.Date(DT_OBITO),
    ANO        = year(DT_NOTIFIC),
    MES        = month(DT_NOTIFIC),
    IDADE      = as.numeric(IDADEanos)
  )

# Conferir o período e o número de registros
ZIKA %>%
  summarise(
    registros = n(),
    primeiro_ano = min(ANO, na.rm = TRUE),
    ultimo_ano = max(ANO, na.rm = TRUE),
    datas_ausentes = sum(is.na(DT_NOTIFIC))
  )

# Estatísticas gerais
ZIKA %>%
  summarise(
    notificacoes = n(),
    confirmados = sum(CLASSI_FIN == "Confirmado", na.rm = TRUE),
    descartados = sum(CLASSI_FIN == "Descartado", na.rm = TRUE),
    inconclusivos = sum(CLASSI_FIN == "Inconclusivo", na.rm = TRUE),
    municipios = n_distinct(ID_MN_RESI, na.rm = TRUE),
    estados = n_distinct(SG_UF, na.rm = TRUE),
    idade_mediana = median(IDADE, na.rm = TRUE),
    idade_media = mean(IDADE, na.rm = TRUE),
    idade_minima = min(IDADE, na.rm = TRUE),
    idade_maxima = max(IDADE, na.rm = TRUE)
  )

# Frequência das classificações
ZIKA %>%
  tabyl(CLASSI_FIN) %>%
  adorn_pct_formatting()

ZIKA %>% tabyl(EVOLUCAO) %>% adorn_pct_formatting()
ZIKA %>% tabyl(CS_SEXO) %>% adorn_pct_formatting()
ZIKA %>% tabyl(CS_RACA) %>% adorn_pct_formatting()
ZIKA %>% tabyl(CS_GESTANT) %>% adorn_pct_formatting()


anual <- ZIKA %>%
  count(ANO, name = "notificacoes") %>%
  complete(ANO = 2015:2025, fill = list(notificacoes = 0))

ggplot(anual, aes(x = ANO, y = notificacoes)) +
  geom_col(fill = "#2878B5") +
  geom_text(aes(label = comma(notificacoes)),
            vjust = -0.4, size = 3) +
  scale_x_continuous(breaks = 2015:2025) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Notificações de zika por ano",
    x = "Ano",
    y = "Número de notificações",
    caption = "Fonte: SINAN; elaboração própria."
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

anual_classificacao <- ZIKA %>%
  filter(!is.na(CLASSI_FIN)) %>%
  count(ANO, CLASSI_FIN)

ggplot(anual_classificacao,
       aes(x = ANO, y = n, color = CLASSI_FIN)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 2015:2025) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Evolução anual por classificação final",
    x = "Ano",
    y = "Notificações",
    color = "Classificação"
  ) +
  theme_minimal()

top_estados <- ZIKA %>%
  filter(!is.na(SG_UF)) %>%
  count(SG_UF, sort = TRUE) %>%
  slice_head(n = 10)

ggplot(top_estados,
       aes(x = reorder(SG_UF, n), y = n)) +
  geom_col(fill = "#269B80") +
  coord_flip() +
  scale_y_continuous(labels = comma) +
  labs(
    title = "10 estados com mais notificações",
    x = NULL,
    y = "Notificações"
  ) +
  theme_minimal()

ZIKA %>%
  filter(CLASSI_FIN == "Confirmado", !is.na(SG_UF)) %>%
  count(SG_UF, sort = TRUE) %>%
  print(n = 27)

sexo <- ZIKA %>%
  filter(!is.na(CS_SEXO)) %>%
  count(CS_SEXO) %>%
  mutate(percentual = n / sum(n) * 100)

ggplot(sexo, aes(x = CS_SEXO, y = n, fill = CS_SEXO)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = paste0(comma(n), " (",
                               round(percentual, 1), "%)")),
            vjust = -0.4) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Notificações por sexo",
    x = "Sexo",
    y = "Notificações"
  ) +
  theme_minimal()

ZIKA %>%
  summarise(
    n_validos = sum(!is.na(IDADE)),
    n_ausentes = sum(is.na(IDADE)),
    mediana = median(IDADE, na.rm = TRUE),
    media = mean(IDADE, na.rm = TRUE),
    desvio_padrao = sd(IDADE, na.rm = TRUE),
    Q1 = quantile(IDADE, 0.25, na.rm = TRUE),
    Q3 = quantile(IDADE, 0.75, na.rm = TRUE)
  )

ggplot(ZIKA %>% filter(between(IDADE, 0, 110)),
       aes(x = IDADE)) +
  geom_histogram(binwidth = 5, boundary = 0,
                 fill = "#2878B5", color = "white") +
  labs(
    title = "Distribuição etária das notificações de zika",
    x = "Idade (anos)",
    y = "Número de notificações"
  ) +
  theme_minimal()

ZIKA <- ZIKA %>%
  mutate(
    FAIXA_ETARIA = cut(
      IDADE,
      breaks = c(-Inf, 4, 11, 17, 29, 39, 49, 59, 69, Inf),
      labels = c(
        "0–4", "5–11", "12–17", "18–29", "30–39",
        "40–49", "50–59", "60–69", "70+"
      )
    )
  )

ZIKA %>%
  filter(!is.na(FAIXA_ETARIA)) %>%
  count(FAIXA_ETARIA) %>%
  mutate(percentual = round(n / sum(n) * 100, 1))

mensal <- ZIKA %>%
  filter(!is.na(DT_SIN_PRI)) %>%
  mutate(
    ANO_SIN = year(DT_SIN_PRI),
    MES_SIN = month(DT_SIN_PRI)
  ) %>%
  count(ANO_SIN, MES_SIN)

ggplot(mensal,
       aes(x = MES_SIN, y = ANO_SIN, fill = n)) +
  geom_tile(color = "white") +
  scale_x_continuous(
    breaks = 1:12,
    labels = month.abb
  ) +
  scale_fill_viridis_c(
    option = "C",
    labels = comma,
    name = "Notificações"
  ) +
  labs(
    title = "Sazonalidade das notificações de zika",
    subtitle = "Organizadas pelo ano e mês dos primeiros sintomas",
    x = "Mês",
    y = "Ano"
  ) +
  theme_minimal()

#COMPLETUDE

completude <- ZIKA %>%
  summarise(across(
    everything(),
    ~ round(mean(!is.na(.) & . != "") * 100, 1)
  )) %>%
  pivot_longer(
    cols = everything(),
    names_to = "variavel",
    values_to = "completude_pct"
  ) %>%
  arrange(completude_pct)

ggplot(completude,
       aes(x = reorder(variavel, completude_pct),
           y = completude_pct)) +
  geom_col(fill = "#D98E32") +
  coord_flip() +
  labs(
    title = "Completude das variáveis",
    x = NULL,
    y = "Registros preenchidos (%)"
  ) +
  theme_minimal()

anos <- 2015:2025

pop_municipios <- map_dfr(anos, function(ano) {
  
  message("Baixando população de ", ano)
  
  get_sidra(
    api = paste0("/t/6579/n6/all/v/9324/p/", ano)
  )
  
})

glimpse(pop_municipios)

saveRDS(
  pop_municipios,
  "dados/populacao_municipios_2015_2025.rds"
)

readr::write_csv(
  pop_municipios,
  "dados/populacao_municipios_2015_2025.csv"
)

#INCIDENCIA

casos_zika <- ZIKA %>%
  filter(
    CLASSI_FIN == "Confirmado",
    !is.na(ID_MN_RESI),
    !is.na(DT_SIN_PRI)
  ) %>%
  mutate(
    ANO = year(as.Date(DT_SIN_PRI)),
    ID_MN_RESI = as.character(ID_MN_RESI)
  ) %>%
  count(ID_MN_RESI, ANO, name = "casos")

pop_municipios <- pop_municipios %>%
  mutate(
    ID_MN_RESI = substr(
      as.character(`Município (Código)`), 1, 6
    ),
    ANO = as.integer(Ano),
    populacao = as.numeric(Valor)
  ) %>%
  select(ID_MN_RESI, ANO, populacao) %>%
  distinct()

incidencia_zika <- casos_zika %>%
  left_join(
    pop_municipios,
    by = c("ID_MN_RESI", "ANO")
  ) %>%
  mutate(
    incidencia_100mil = casos / populacao * 100000
  )

glimpse(incidencia_zika)

incidencia_brasil <- incidencia_zika %>%
  group_by(ANO) %>%
  summarise(
    casos = sum(casos, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(
    pop_municipios %>%
      group_by(ANO) %>%
      summarise(
        populacao = sum(populacao, na.rm = TRUE),
        .groups = "drop"
      ),
    by = "ANO"
  ) %>%
  mutate(
    incidencia_100mil = casos / populacao * 100000
  )

ggplot(incidencia_brasil,
       aes(x = ANO, y = incidencia_100mil)) +
  geom_line(linewidth = 1, color = "#2878B5") +
  geom_point(size = 2, color = "#2878B5") +
  scale_x_continuous(breaks = 2015:2025) +
  labs(
    title = "Incidência anual de zika no Brasil",
    subtitle = "Casos confirmados por 100 mil habitantes",
    x = "Ano",
    y = "Incidência por 100 mil habitantes",
    caption = "Fonte: SINAN e IBGE. Elaboração própria."
  ) +
  theme_minimal()


# Recuperar UF por código municipal
uf_municipios <- ZIKA %>%
  filter(!is.na(ID_MN_RESI), !is.na(SG_UF)) %>%
  mutate(ID_MN_RESI = as.character(ID_MN_RESI)) %>%
  count(ID_MN_RESI, SG_UF, sort = TRUE) %>%
  group_by(ID_MN_RESI) %>%
  slice_max(n, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(ID_MN_RESI, UF = SG_UF)

# Recuperar o nome do município
nomes_municipios <- ZIKA %>%
  filter(!is.na(ID_MN_RESI), !is.na(SG_UF)) %>%
  mutate(ID_MN_RESI = as.character(ID_MN_RESI)) %>%
  count(ID_MN_RESI, SG_UF, sort = TRUE) %>%
  group_by(ID_MN_RESI) %>%
  slice_max(n, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  transmute(
    ID_MN_RESI,
    municipio = ID_MN_RESI,
    UF = SG_UF
  )

# Ranking dos 10 municípios por ano
top10_zika <- incidencia_zika %>%
  left_join(
    nomes_municipios,
    by = "ID_MN_RESI"
  ) %>%
  filter(
    !is.na(incidencia_100mil),
    !is.na(populacao),
    populacao > 0
  ) %>%
  group_by(ANO) %>%
  slice_max(
    order_by = incidencia_100mil,
    n = 10,
    with_ties = FALSE
  ) %>%
  arrange(ANO, desc(incidencia_100mil)) %>%
  mutate(posicao = row_number()) %>%
  ungroup() %>%
  select(
    ANO, posicao, municipio, UF,
    casos, populacao, incidencia_100mil
  )

print(top10_zika, n = Inf)

library(tidyverse)
library(lubridate)
library(geobr)
library(sf)
library(scales)

# Correspondência entre código municipal e UF
mun_uf <- geobr::read_municipality(
  year = 2020,
  simplified = TRUE
) %>%
  transmute(
    ID_MN_RESI = substr(as.character(code_muni), 1, 6),
    UF = abbrev_state
  ) %>%
  distinct()

# Casos confirmados por UF e ano dos primeiros sintomas
casos_uf <- ZIKA %>%
  filter(
    CLASSI_FIN == "Confirmado",
    !is.na(DT_SIN_PRI),
    !is.na(ID_MN_RESI)
  ) %>%
  mutate(
    ANO = year(as.Date(DT_SIN_PRI)),
    ID_MN_RESI = as.character(ID_MN_RESI)
  ) %>%
  count(ID_MN_RESI, ANO, name = "casos") %>%
  left_join(mun_uf, by = "ID_MN_RESI") %>%
  filter(!is.na(UF)) %>%
  group_by(UF, ANO) %>%
  summarise(casos = sum(casos), .groups = "drop")

# População estadual a partir da população municipal
pop_uf <- pop_municipios %>%
  mutate(
    ID_MN_RESI = as.character(ID_MN_RESI),
    ANO = as.integer(ANO)
  ) %>%
  left_join(mun_uf, by = "ID_MN_RESI") %>%
  filter(!is.na(UF), !is.na(populacao)) %>%
  group_by(UF, ANO) %>%
  summarise(
    populacao = sum(populacao),
    .groups = "drop"
  )

# Calcular incidência
incidencia_uf <- pop_uf %>%
  left_join(casos_uf, by = c("UF", "ANO")) %>%
  mutate(
    casos = replace_na(casos, 0),
    incidencia_100mil = casos / populacao * 100000
  ) %>%
  filter(ANO %in% 2015:2025)


# Geometria dos estados brasileiros
estados <- geobr::read_state(
  year = 2020,
  simplified = TRUE
) %>%
  rename(UF = abbrev_state)

mapa_zika <- estados %>%
  left_join(incidencia_uf, by = "UF")

# Mapa facetado por ano
ggplot(mapa_zika) +
  geom_sf(aes(fill = incidencia_100mil),
          color = "white", linewidth = 0.2) +
  facet_wrap(~ ANO, ncol = 4) +
  scale_fill_viridis_c(
    option = "C",
    labels = label_number(accuracy = 0.1),
    na.value = "grey90",
    name = "Incidência\npor 100 mil"
  ) +
  labs(
    title = "Incidência de zika por unidade da Federação",
    subtitle = "Brasil, 2015–2025",
    caption = paste(
      "Fonte: SINAN e IBGE.",
      "Casos confirmados segundo o ano dos primeiros sintomas."
    )
  ) +
  theme_void() +
  theme(
    strip.text = element_text(face = "bold", size = 10),
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11),
    legend.position = "bottom",
    panel.spacing = unit(0.8, "lines")
  )

incidencia_uf %>%
  group_by(ANO) %>%
  summarise(
    estados = n_distinct(UF),
    populacao_ausente = sum(is.na(populacao)),
    casos = sum(casos, na.rm = TRUE),
    .groups = "drop"
  )

#Tempo Notificação

tempo_notificacao <- ZIKA %>%
  mutate(
    DT_SIN_PRI = as.Date(DT_SIN_PRI),
    DT_NOTIFIC = as.Date(DT_NOTIFIC),
    ANO_SIN = year(DT_SIN_PRI),
    atraso_dias = as.numeric(DT_NOTIFIC - DT_SIN_PRI)
  ) %>%
  filter(
    !is.na(atraso_dias),
    between(atraso_dias, 0, 365)
  )

# Estatísticas anuais
tempo_notificacao %>%
  group_by(ANO_SIN) %>%
  summarise(
    registros = n(),
    mediana_dias = median(atraso_dias),
    Q1 = quantile(atraso_dias, 0.25),
    Q3 = quantile(atraso_dias, 0.75),
    percentual_ate_7_dias = mean(atraso_dias <= 7) * 100,
    .groups = "drop"
  )

# Gráfico
ggplot(tempo_notificacao,
       aes(x = factor(ANO_SIN), y = atraso_dias)) +
  geom_boxplot(outlier.shape = NA) +
  coord_cartesian(ylim = c(0, 60)) +
  labs(
    title = "Tempo entre sintomas e notificação",
    x = "Ano dos sintomas",
    y = "Dias"
  ) +
  theme_minimal()

#GESTANTES


ZIKA %>%
  count(CS_GESTANT, sort = TRUE) %>%
  mutate(percentual = round(n / sum(n) * 100, 2))

zika_gestacao <- ZIKA %>%
  mutate(
    DT_SIN_PRI = as.Date(DT_SIN_PRI),
    ANO = year(DT_SIN_PRI),
    gestacao_original = str_squish(
      str_to_lower(CS_GESTANT)
    ),
    situacao_gestacional = case_when(
      is.na(gestacao_original) |
        gestacao_original == "" ~ "Sem informação",
      
      str_detect(gestacao_original, "trimestre") ~
        "Gestante — trimestre informado",
      
      str_detect(gestacao_original, "nao se aplica") ~
        "Não se aplica",
      
      str_detect(gestacao_original, "^nao$") ~
        "Não gestante",
      
      str_detect(gestacao_original, "ignorado") ~
        "Ignorado",
      
      TRUE ~ "Outra categoria"
    )
  ) %>%
  filter(ANO %in% 2015:2025)

zika_gestacao %>%
  count(gestacao_original, situacao_gestacional, sort = TRUE)

tab_gestacao <- zika_gestacao %>%
  count(situacao_gestacional, name = "notificacoes") %>%
  mutate(
    percentual = notificacoes / sum(notificacoes) * 100
  ) %>%
  arrange(desc(notificacoes))

tab_gestacao

ggplot(
  tab_gestacao,
  aes(
    x = reorder(situacao_gestacional, notificacoes),
    y = notificacoes
  )
) +
  geom_col(fill = "#2878B5") +
  geom_text(
    aes(label = comma(notificacoes)),
    hjust = -0.1,
    size = 3.5
  ) +
  coord_flip() +
  scale_y_continuous(
    labels = comma,
    expand = expansion(mult = c(0, 0.15))
  ) +
  labs(
    title = "Notificações de zika por situação gestacional",
    x = NULL,
    y = "Notificações"
  ) +
  theme_minimal()

trimestre_ano <- zika_gestacao %>%
  filter(
    str_detect(gestacao_original, "trimestre")
  ) %>%
  count(ANO, gestacao_original, name = "notificacoes")

ggplot(
  trimestre_ano,
  aes(
    x = ANO,
    y = notificacoes,
    color = gestacao_original,
    group = gestacao_original
  )
) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 2015:2025) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Notificações de zika em gestantes por trimestre",
    x = "Ano dos primeiros sintomas",
    y = "Notificações",
    color = "Trimestre"
  ) +
  theme_minimal()

evolucao_gestantes <- zika_gestacao %>%
  mutate(
    grupo = if_else(
      str_detect(gestacao_original, "trimestre"),
      "Gestante — trimestre informado",
      "Demais categorias"
    )
  ) %>%
  count(ANO, grupo, name = "notificacoes") %>%
  complete(
    ANO = 2015:2025,
    grupo,
    fill = list(notificacoes = 0)
  )

ggplot(
  evolucao_gestantes,
  aes(x = ANO, y = notificacoes, color = grupo)
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 2015:2025) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Evolução das notificações de zika em gestantes",
    x = "Ano",
    y = "Notificações",
    color = NULL
  ) +
  theme_minimal()

desfechos_gestacao <- zika_gestacao %>%
  filter(CLASSI_FIN == "Confirmado") %>%
  mutate(
    desfecho = case_when(
      is.na(EVOLUCAO) | str_squish(EVOLUCAO) == "" ~
        "Sem informação",
      TRUE ~ str_squish(EVOLUCAO)
    )
  ) %>%
  count(
    situacao_gestacional,
    desfecho,
    name = "notificacoes"
  ) %>%
  group_by(situacao_gestacional) %>%
  mutate(
    percentual = notificacoes / sum(notificacoes) * 100
  ) %>%
  ungroup()

desfechos_gestacao

ggplot(
  desfechos_gestacao,
  aes(
    x = situacao_gestacional,
    y = percentual,
    fill = desfecho
  )
) +
  geom_col() +
  coord_flip() +
  scale_y_continuous(
    labels = label_percent(scale = 1)
  ) +
  labs(
    title = "Evolução dos casos confirmados por situação gestacional",
    x = NULL,
    y = "Percentual dentro de cada categoria (%)",
    fill = "Evolução registrada"
  ) +
  theme_minimal()

dir.create("resultados/zika_gestacao",
           recursive = TRUE,
           showWarnings = FALSE)

write_csv(
  tab_gestacao,
  "resultados/zika_gestacao/distribuicao_gestacional.csv"
)

write_csv(
  trimestre_ano,
  "resultados/zika_gestacao/trimestre_por_ano.csv"
)

write_csv(
  desfechos_gestacao,
  "resultados/zika_gestacao/desfechos_por_gestacao.csv"
)

#raça/cor × sexo × classificação final

zika_raca <- ZIKA %>%
  mutate(
    RACA = case_when(
      is.na(CS_RACA) | str_squish(CS_RACA) == "" ~
        "Sem informação",
      str_to_lower(str_squish(CS_RACA)) %in%
        c("ignorado", "ignorada") ~
        "Ignorado",
      TRUE ~ str_squish(CS_RACA)
    ),
    SEXO = case_when(
      is.na(CS_SEXO) | str_squish(CS_SEXO) == "" ~
        "Sem informação",
      str_to_lower(str_squish(CS_SEXO)) %in%
        c("ignorado", "ignorada") ~
        "Ignorado",
      TRUE ~ str_squish(CS_SEXO)
    ),
    CLASSIFICACAO = case_when(
      is.na(CLASSI_FIN) | str_squish(CLASSI_FIN) == "" ~
        "Sem informação",
      TRUE ~ str_squish(CLASSI_FIN)
    )
  )

tab_raca_sexo <- zika_raca %>%
  count(RACA, SEXO, CLASSIFICACAO, name = "n") %>%
  group_by(RACA) %>%
  mutate(
    percentual = n / sum(n) * 100
  ) %>%
  ungroup() %>%
  arrange(RACA, SEXO, desc(n))

print(tab_raca_sexo, n = Inf)

ggplot(
  zika_raca,
  aes(
    x = RACA,
    fill = CLASSIFICACAO
  )
) +
  geom_bar(
    position = "fill"
  ) +
  facet_wrap(~ SEXO) +
  scale_y_continuous(
    labels = label_percent()
  ) +
  labs(
    title = "Classificação final por raça/cor e sexo",
    subtitle = "Distribuição percentual das notificações de zika",
    x = "Raça/cor",
    y = "Percentual dentro de raça/cor e sexo",
    fill = "Classificação final"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(
      angle = 35,
      hjust = 1
    ),
    legend.position = "bottom"
  )

confirmados_raca <- zika_raca %>%
  filter(CLASSIFICACAO == "Confirmado") %>%
  count(RACA, SEXO, name = "casos") %>%
  group_by(SEXO) %>%
  mutate(
    percentual = casos / sum(casos) * 100
  ) %>%
  ungroup()

confirmados_raca

ggplot(
  confirmados_raca,
  aes(
    x = RACA,
    y = percentual,
    fill = SEXO
  )
) +
  geom_col(position = "dodge") +
  scale_y_continuous(
    labels = label_percent(scale = 1)
  ) +
  labs(
    title = "Casos confirmados de zika por raça/cor e sexo",
    x = "Raça/cor",
    y = "Percentual dentro de cada sexo",
    fill = "Sexo"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(
      angle = 35,
      hjust = 1
    )
  )

completude_raca <- zika_raca %>%
  mutate(
    ano = lubridate::year(as.Date(DT_NOTIFIC)),
    raca_preenchida = !RACA %in%
      c("Sem informação", "Ignorado")
  ) %>%
  group_by(ano) %>%
  summarise(
    total = n(),
    preenchidos = sum(raca_preenchida),
    ausentes_ou_ignorados = total - preenchidos,
    percentual_preenchido =
      preenchidos / total * 100,
    .groups = "drop"
  )

completude_raca

ggplot(
  completude_raca,
  aes(x = ano, y = percentual_preenchido)
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 2015:2025) +
  scale_y_continuous(
    labels = label_percent(scale = 1),
    limits = c(0, 100)
  ) +
  labs(
    title = "Completude do campo raça/cor",
    x = "Ano",
    y = "Registros preenchidos (%)"
  ) +
  theme_minimal()

#Sazonalidade

# 1. Preparar os dados
zika_analise <- ZIKA %>%
  mutate(
    DT_SIN_PRI = as.Date(DT_SIN_PRI),
    ANO = year(DT_SIN_PRI),
    MES = month(DT_SIN_PRI),
    CLASSI_FIN = str_squish(as.character(CLASSI_FIN))
  ) %>%
  filter(
    !is.na(DT_SIN_PRI),
    ANO >= 2015,
    ANO <= 2025
  )

# 2. Casos por mês e ano
casos_mes <- zika_analise %>%
  count(ANO, MES, name = "notificacoes")

# Gráfico 1: sazonalidade da zika
ggplot(casos_mes, aes(x = MES, y = notificacoes, color = factor(ANO))) +
  geom_line(linewidth = 0.8, alpha = 0.8) +
  geom_point(size = 1.5) +
  scale_x_continuous(
    breaks = 1:12,
    labels = month.abb
  ) +
  scale_y_continuous(labels = label_number(big.mark = ".")) +
  labs(
    title = "Zika: distribuição mensal das notificações",
    subtitle = "Brasil, 2015–2025, segundo início dos sintomas",
    x = "Mês",
    y = "Notificações",
    color = "Ano"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

# 3. Proporção de notificações confirmadas por ano
perfil_anual <- zika_analise %>%
  mutate(
    classificacao = case_when(
      str_to_lower(CLASSI_FIN) == "confirmado" ~ "Confirmado",
      str_to_lower(CLASSI_FIN) == "descartado" ~ "Descartado",
      str_to_lower(CLASSI_FIN) == "inconclusivo" ~ "Inconclusivo",
      is.na(CLASSI_FIN) | CLASSI_FIN == "" ~ "Sem informação",
      TRUE ~ "Outras classificações"
    )
  ) %>%
  count(ANO, classificacao, name = "n") %>%
  group_by(ANO) %>%
  mutate(percentual = n / sum(n)) %>%
  ungroup()

# Gráfico 2: composição das notificações ao longo dos anos
ggplot(perfil_anual,
       aes(x = ANO, y = percentual, fill = classificacao)) +
  geom_col(width = 0.85) +
  scale_y_continuous(labels = label_percent()) +
  scale_x_continuous(breaks = 2015:2025) +
  labs(
    title = "Como se classificam as notificações de zika?",
    subtitle = "Proporção de cada classificação final por ano",
    x = "Ano de início dos sintomas",
    y = "Percentual das notificações",
    fill = "Classificação"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

install.packages(c("rmarkdown", "tidyverse", "lubridate", "scales", "knitr"))

rmarkdown::render("boletim_zika.Rmd")
