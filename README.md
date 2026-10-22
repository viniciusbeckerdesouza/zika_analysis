# Como baixar os dados e gerar o boletim

Este guia explica o uso de dois arquivos:

| Arquivo | Funcao |
|---|---|
| [scripts/01_baixar_dados.R](scripts/01_baixar_dados.R) | Executa os downloads do SINAN e da populacao, nessa ordem. |
| [R/download.R](R/download.R) | Define as funcoes `baixar_sinan()` e `baixar_populacao()`, usadas pelo script. |

**A diferenca principal:** executar o primeiro arquivo inicia os downloads.
Carregar o segundo apenas disponibiliza as funcoes; voce escolhe qual executar.

## 1. Preparar o ambiente

Voce precisa de R, acesso a internet e dos pacotes `microdatasus`, `sidrar`,
`purrr` e `readr`.

No console do R, instale os pacotes disponiveis no CRAN:

```r
install.packages(c("sidrar", "purrr", "readr"))
```

Para instalar `microdatasus`, siga as instrucoes da
[documentacao oficial do pacote](https://github.com/rfsaldanha/microdatasus).

Os arquivos de download nao instalam pacotes automaticamente. Nao e necessario
carregar o `tidyverse` nem instalar pacotes de graficos para esta etapa.

Abra [zika-brasil.Rproj](zika-brasil.Rproj) no RStudio ou inicie o R na raiz
do repositorio: a pasta que contem os diretorios `R/` e `scripts/`.
Todos os comandos abaixo devem ser executados a partir dessa pasta.

## 2. Baixar tudo pelo script

No console do R:

```r
source("scripts/01_baixar_dados.R")
```

Ou, no terminal:

```sh
Rscript scripts/01_baixar_dados.R
```

Escolha uma dessas formas; nao e necessario executar as duas.

### O que acontece

O script:

1. Verifica se os quatro pacotes estao instalados.
2. Verifica se encontra `R/download.R` a partir da pasta atual.
3. Carrega as funcoes desse arquivo.
4. Define o periodo em `anos <- 2015:2025`.
5. Baixa e processa os dados de zika de cada ano, salvando CSV e RDS.
6. Consulta a populacao municipal de cada ano e salva um consolidado.

As etapas sao sequenciais: se o download do SINAN falhar, a consulta da
populacao nao sera iniciada.

### Como mudar o periodo

Edite esta linha em [scripts/01_baixar_dados.R](scripts/01_baixar_dados.R):

```r
anos <- 2015:2025
```

Por exemplo, para solicitar 2024 e 2025:

```r
anos <- 2024:2025
```

Alterar o periodo muda os anos solicitados nas duas fontes. Isso nao garante
que esses anos estejam disponiveis.

## 3. Baixar apenas os dados desejados

Se quiser controlar os downloads separadamente, carregue somente as funcoes:

```r
source("R/download.R")
```

Esse comando nao baixa nada. Depois, execute uma das chamadas abaixo.

### Dados de zika do SINAN

```r
# Um ano, somente em RDS
baixar_sinan("zika", 2025, formato = "rds")

# Um intervalo, somente em CSV
baixar_sinan("zika", 2024:2025, formato = "csv")

# Um intervalo, nos dois formatos
baixar_sinan("zika", 2024:2025, formato = c("csv", "rds"))
```

Esses exemplos sao alternativas. Nao execute todos em sequencia esperando
regravar as mesmas saidas: a funcao recusa arquivos existentes.

| Argumento | O que informar |
|---|---|
| `agravo` | Nome do agravo, como `"zika"`. Deve ser reconhecido pelo `microdatasus`, inclusive por sua funcao de processamento. |
| `anos` | Um ano, um intervalo como `2015:2025` ou um vetor como `c(2015, 2017)`. |
| `formato` | `"csv"`, `"rds"` ou `c("csv", "rds")`. Se omitido, grava ambos. |

Para cada ano, a funcao:

1. Solicita os registros com `microdatasus::fetch_datasus()`.
2. Confere se recebeu uma tabela com registros.
3. Converte `NU_IDADE_N` para numerico, quando a coluna existe.
4. Aplica a funcao de processamento do agravo, como `process_sinan_zika()`.
5. Grava os dados processados nos formatos escolhidos.

**Os arquivos salvos nao sao copias brutas do SINAN:** ja passaram pelo
processamento do `microdatasus`.

### Populacao municipal do IBGE

```r
baixar_populacao(2015:2025)
```

A funcao consulta o SIDRA com:

- Tabela: **6579**.
- Variavel: **9324**.
- Abrangencia: todos os municipios, nivel territorial **n6**.
- Periodo: cada ano informado em `anos`.

Ela verifica se a resposta contem registros e as colunas
`Município (Código)`, `Ano` e `Valor`, e se o ano recebido corresponde ao
solicitado. Depois, une as respostas com `purrr::map_dfr()` e grava o
consolidado em CSV e RDS.

**A disponibilidade de todos os anos de 2015 a 2025 nessa tabela nao e
garantida.** Se uma consulta falhar ou retornar uma resposta invalida, a
funcao interrompe a execucao. Ela nao interpola populacoes, nao preenche
anos ausentes e nao muda de fonte automaticamente.

## 4. Onde os arquivos sao salvos

Com o periodo padrao e os dois formatos do SINAN, as saidas sao:

```text
zika/
  ZIKA15.csv
  ZIKA15.rds
  ...
  ZIKA25.csv
  ZIKA25.rds

dados/
  populacao_municipios_2015_2025.csv
  populacao_municipios_2015_2025.rds
```

Os diretorios sao criados automaticamente quando necessario.
O SINAN gera arquivos separados por ano. A populacao gera um unico arquivo
por formato, cujo nome usa o menor e o maior ano solicitados.

- **CSV:** tabela de texto que pode ser aberta em outros programas.
- **RDS:** objeto R que pode ser carregado com `readRDS()`.

Para usar os arquivos depois de um download concluido:

```r
zika_2025 <- readRDS("zika/ZIKA25.rds")
populacao <- readRDS("dados/populacao_municipios_2015_2025.rds")
```

As funcoes retornam os caminhos das saidas de forma invisivel. Para guardar
esses caminhos, atribua o resultado da chamada a um objeto:

```r
arquivos <- baixar_sinan("zika", 2025, formato = "rds")
```

Essa chamada tambem executa o download; nao serve para apenas listar um
arquivo ja existente.

## 5. Erros e retomada

### Pacote ausente

Instale o pacote indicado na mensagem e execute novamente. O script verifica
as dependencias antes de iniciar os downloads.

### Arquivo ja existente

As funcoes nao sobrescrevem arquivos. Antes de cada chamada, elas verificam
as saidas previstas; se alguma existir, interrompem essa chamada.

Se os dados do SINAN ja estiverem salvos e voce precisar apenas da populacao,
nao execute o script completo:

```r
source("R/download.R")
baixar_populacao(2015:2025)
```

### Falha durante o download ou processamento

No SINAN, cada ano e salvo separadamente. Os anos concluidos antes da falha
permanecem no disco. Confira os arquivos e retome apenas os anos e formatos
que ainda nao foram gravados.

Por exemplo, se 2024 foi concluido e 2025 falhou antes de gerar qualquer saida:

```r
baixar_sinan("zika", 2025, formato = c("csv", "rds"))
```

Na populacao, o consolidado so comeca a ser gravado depois de receber e
validar todos os anos solicitados. Uma falha de consulta exige investigar
a causa e repetir a chamada; nao ha retomada automatica.

Em qualquer das fontes, uma falha durante a gravacao pode deixar arquivos
incompletos. Verifique as saidas antes de reutiliza-las: a existencia de um
arquivo, por si so, nao confirma que a etapa terminou corretamente.

## 6. Como funciona o boletim

O arquivo [boletim_zika_v2.Rmd](boletim_zika_v2.Rmd) e um documento
**R Markdown**: combina texto explicativo, codigo R e resultados em um
mesmo arquivo. Ao renderizar o documento, o R executa os blocos de codigo,
produz tabelas e figuras e monta o boletim em HTML ou Word.

Ele nao e apenas um modelo visual: tambem realiza sua propria preparacao
dos dados e calcula os indicadores.

### Quais dados ele usa

O boletim le diretamente:

- Os arquivos anuais `ZIKA15.rds` a `ZIKA25.rds`, gerados pelo download
  do SINAN.
- O arquivo `dados/populacao_municipios_2015_2025.rds`, com a resposta
  do SIDRA e suas colunas originais.
- Malhas e nomes de estados e municipios de 2020, obtidos pelo `geobr`.

**O boletim atual nao utiliza as bases de `dados/processados/` nem chama
as funcoes de `R/limpeza.R`.** Executar a etapa de preparacao nao substitui
as entradas acima. Em particular, a populacao preparada possui outro esquema
de colunas e nao deve ser passada diretamente ao boletim.

### Como os blocos se conectam

| Bloco | O que faz |
|---|---|
| `setup` | Carrega pacotes e define cores, tema e formatacao de numeros. |
| `dados-sinan` | Une os arquivos anuais, converte datas, decodifica idade e recodifica classificacao, sexo, raca/cor, gestacao e evolucao. |
| `dados-geo` e `geo-mun` | Obtem malhas e correspondencias territoriais para tabelas e mapas. |
| `dados-pop` | Le e padroniza a populacao, preenche lacunas e agrega os denominadores por UF e Brasil. |
| `indicadores` | Calcula contagens, incidencia, letalidade registrada e tempo ate a notificacao. |
| Blocos `tab-*` e `fig-*` | Organizam os resultados em tabelas e graficos ao longo do texto. |

O objeto `zika` contem as notificacoes incluidas no periodo, enquanto `conf`
contem somente as classificadas como confirmadas.

Neste documento, o ano de referencia e o de inicio dos sintomas; se essa
data estiver ausente, usa-se a notificacao. O mes, porem, vem apenas da
data dos sintomas. Essa regra difere da etapa de preparacao, que cria
`ANO` e `MES` pela notificacao.

O boletim apresenta panorama anual, distribuicao temporal e espacial,
ranking municipal, tipologia de registros municipais, perfil dos casos,
gestacao, evolucao, oportunidade da notificacao e completude.

Os numeros inseridos no texto com expressoes R sao recalculados ao
renderizar. **Os paragrafos interpretativos escritos manualmente nao sao
atualizados automaticamente** e devem ser revisados quando os dados ou
o periodo mudarem.

## 7. Preparar a geracao do boletim

### Instalar as dependencias adicionais

No console do R:

```r
install.packages(c(
  "rmarkdown", "knitr", "tidyverse", "lubridate",
  "janitor", "scales", "geobr", "sf", "stringi"
))

rmarkdown::pandoc_available()
```

O ultimo comando deve retornar `TRUE`. Pandoc e necessario para converter
o documento; normalmente acompanha o RStudio. Em Linux, a instalacao de
`sf` pode exigir bibliotecas de sistema, como GDAL, GEOS e PROJ.
Use R 4.1 ou superior para a sintaxe empregada no boletim, respeitando
tambem os requisitos das versoes dos pacotes instalados.

O `geobr` pode precisar de internet para obter as malhas na primeira
execucao. Nao e necessario abrir o Word para gerar o arquivo DOCX.

### Ajustar a leitura dos arquivos SINAN antes de executar

**Existe um ajuste pendente no documento original:** o bloco `dados-sinan`
procura os arquivos na raiz, embora o download os grave em `zika/`.
O parametro `dir_zika` ainda nao e usado nessa leitura.

Antes de renderizar, substitua as tres linhas que montam e filtram
`arquivos` e verificam se nenhum arquivo existe pelo trecho:

```r
arquivos <- file.path(
  params$dir_zika,
  sprintf("ZIKA%02d.rds", anos %% 100)
)

faltantes <- arquivos[!file.exists(arquivos)]
if (length(faltantes) > 0L) {
  stop("Arquivos anuais ausentes: ", paste(faltantes, collapse = ", "))
}
```

Essa alteracao faz a leitura respeitar a pasta configurada e impede gerar
um boletim com apenas parte dos anos solicitados. **O trecho acima e uma
instrucao de ajuste; a documentacao nao altera o R Markdown automaticamente.**
Para conservar o original intacto, faca o ajuste em uma copia e use o nome
dessa copia nos comandos de renderizacao.

### Entender o tratamento da populacao

Diferentemente do download, que exige resposta para todos os anos pedidos,
o boletim possui preenchimento de lacunas populacionais:

- Interpolacao linear entre valores disponiveis.
- Repeticao do valor da extremidade para anos fora do intervalo observado.
- Uso do unico valor disponivel quando so ha uma observacao no municipio.

Portanto, nem todo denominador utilizado sera uma estimativa oficial
observada naquele ano. Confira a cobertura da base e revise esse tratamento
antes de interpretar as incidencias. O boletim nao resolve a indisponibilidade
de um ano na etapa de download.

## 8. Gerar HTML ou Word

Depois de ajustar a leitura e conferir as entradas, execute os comandos
na raiz do projeto. Eles consideram o ajuste aplicado ao documento original;
se voce ajustou uma copia, substitua o nome do arquivo de entrada.

### HTML

```r
rmarkdown::render(
  input = "boletim_zika_v2.Rmd",
  output_format = "html_document",
  output_file = "boletim_zika_recalculado.html"
)
```

O HTML pode ser aberto no navegador e possui sumario navegavel.

### Word

```r
rmarkdown::render(
  input = "boletim_zika_v2.Rmd",
  output_format = "word_document",
  output_file = "boletim_zika_recalculado.docx"
)
```

O DOCX pode ser aberto em um editor compativel com Word.

Os nomes acima diferem do HTML original para preserva-lo. No entanto,
**renderizar novamente pode sobrescrever uma saida recalculada com o
mesmo nome**. O processo tambem pode criar figuras e caches auxiliares.
A protecao contra sobrescrita das funcoes de download nao se aplica ao
`rmarkdown::render()`.

Use o nome real `boletim_zika_v2.Rmd`: os exemplos antigos dentro do
documento mencionam `boletim_zika.Rmd`, que nao e o mesmo arquivo.

### Alterar parametros sem editar o cabecalho

O cabecalho inicial, entre `---`, define:

| Parametro | Padrao | Finalidade |
|---|---|---|
| `ano_inicio` | `2015` | Primeiro ano da analise. |
| `ano_fim` | `2025` | Ultimo ano da analise. |
| `dir_zika` | `"zika"` | Pasta dos RDS anuais, apos o ajuste de leitura. |
| `arquivo_pop` | `"dados/populacao_municipios_2015_2025.rds"` | Caminho da populacao no esquema original do SIDRA. |
| `min_casos_ranking` | `5` | Minimo de casos confirmados para entrar no ranking municipal. |

Para manter o periodo e alterar somente o limite do ranking:

```r
rmarkdown::render(
  input = "boletim_zika_v2.Rmd",
  output_format = "html_document",
  output_file = "boletim_zika_ranking_10.html",
  params = list(min_casos_ranking = 10)
)
```

Os parametros nao informados mantem seus valores padrao. Para alterar o
periodo, passe tambem `ano_inicio` e `ano_fim`, confira os arquivos anuais
e indique a populacao correspondente em `arquivo_pop`.

A tipologia compara os tres primeiros com os tres ultimos anos do periodo.
Use pelo menos seis anos para evitar sobreposicao entre essas janelas;
o documento ainda nao valida essa condicao automaticamente.

### Conferir o resultado

Ao terminar, verifique:

1. Se todos os anos e fontes esperados foram incluidos.
2. Se tabelas, figuras e numeros no texto estao coerentes.
3. Se os paragrafos interpretativos ainda descrevem os resultados.
4. Se os denominadores preenchidos e as limitacoes estao documentados.

O documento oculta mensagens e avisos dos blocos na saida final. A ausencia
de avisos no HTML ou Word nao garante que os dados e os metodos foram
validados.
