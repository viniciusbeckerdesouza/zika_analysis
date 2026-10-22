# Dados

As bases nao acompanham o repositorio. As funcoes de aquisicao estao em
[R/download.R](../R/download.R).

## Convencoes

- `brutos/`: arquivos obtidos das fontes, preservados sem alteracao.
- `processados/`: bases derivadas, geradas pelo codigo de preparacao.

Ambos os diretorios sao ignorados pelo Git, exceto seus arquivos `.gitkeep`.
Nao editar manualmente as bases processadas.

Por compatibilidade com o codigo original, o download atual grava o SINAN
processado em `zika/`, na raiz, e a populacao em
`dados/populacao_municipios_<inicio>_<fim>.rds` e `.csv`.
Esses caminhos tambem sao ignorados pelo Git. A adocao das subpastas acima
fica para a migracao da preparacao dos dados; arquivos existentes nao sao movidos.

As funcoes nao sobrescrevem saidas. Falhas no processamento SINAN interrompem
a execucao; no SIDRA, o consolidado so e gravado apos receber todos os anos.
Anos indisponiveis nao sao preenchidos nem imputados.

## Preparar as bases

Depois de concluir os downloads, execute na raiz:

```r
source("scripts/02_preparar_dados.R")
```

Ou, no terminal:

```sh
Rscript scripts/02_preparar_dados.R
```

A etapa exige `dplyr`, `purrr` e `lubridate`. Ajuste `anos` no script se o
periodo baixado for diferente de 2015-2025.
As funcoes reutilizaveis estao em [R/limpeza.R](../R/limpeza.R):

```r
source("R/limpeza.R")
ZIKA <- preparar_zika(2015:2025, dir_zika = "zika")
pop_municipios <- preparar_populacao(
  "dados/populacao_municipios_2015_2025.rds", 2015:2025
)
```

`preparar_zika()` une todos os arquivos anuais, converte as tres datas
(`DT_NOTIFIC`, `DT_SIN_PRI`, `DT_OBITO`), cria `ANO` e `MES` pela notificacao,
converte `IDADEanos` em `IDADE` e aplica os intervalos de `FAIXA_ETARIA`
do script original. Nao exclui registros nem arredonda idades fracionarias.
As colunas originais sao preservadas, exceto pelas conversoes de data.
Tipos incompativeis entre arquivos anuais interrompem a uniao; nao ha
conversao geral de todas as colunas para texto.

`preparar_populacao()` reduz o codigo municipal aos seis primeiros digitos,
converte ano e populacao para numerico, seleciona `ID_MN_RESI`, `ANO` e
`populacao`, e remove apenas linhas exatamente iguais, como no original.
Restringe a base aos anos solicitados, exige cobertura de todos esses anos
e recusa denominadores invalidos ou valores conflitantes por municipio-ano.
Essa verificacao nao garante cobertura de todos os municipios.

O script grava os objetos como:

- `dados/processados/ZIKA_2015_2025.rds`
- `dados/processados/populacao_municipios_2015_2025.rds`

Os nomes acompanham o periodo configurado. Nenhuma saida existente e
sobrescrita. Entradas e resultados anteriores permanecem intactos.
Nao sao produzidos graficos, indicadores ou recodificacoes especificas de
gestacao e raca/cor nesta etapa.

## Fontes previstas

- SINAN/DATASUS: notificacoes de zika, com aquisicao via `microdatasus`.
- IBGE/SIDRA: populacao residente; o codigo original consulta a tabela 6579.
- IBGE via `geobr`: malhas e correspondencias territoriais.

A disponibilidade, as definicoes e a compatibilidade das fontes ainda devem
ser verificadas. Nao presumir que todo ano solicitado esta disponivel nem
substituir indisponibilidade por zero.

## Proveniencia a registrar na implementacao

Para cada extracao, registrar:

- Fonte e endereco ou consulta utilizada.
- Data e hora da aquisicao.
- Periodo solicitado e cobertura efetivamente recebida.
- Versoes dos pacotes e do dicionario de dados.
- Nome, tamanho e hash dos arquivos de entrada.
- Quantidade de registros antes e depois de cada etapa de selecao.
- Transformacoes, exclusoes e regras de duplicidade.
- Origem de cada denominador populacional e identificacao de valores imputados.

## Compartilhamento

Preferir instrucoes de aquisicao e resultados agregados revisados a publicar
microdados neste repositorio. Verificar termos de uso, confidencialidade e
risco de identificacao em pequenas contagens antes de compartilhar.
