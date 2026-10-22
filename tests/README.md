# Testes

O arquivo `testthat/test-download.R` testa as funcoes de aquisicao com
respostas sinteticas, sem downloads nem acesso a microdados reais.
As gravacoes sao realizadas em diretorios temporarios.

Os testes cobrem nomes e formatos dos arquivos, conversao da idade antes do
processamento, entradas invalidas, protecao contra sobrescrita e interrupcao
em falhas de processamento ou indisponibilidade no SIDRA.

O arquivo `testthat/test-preparacao.R` verifica as transformacoes de datas,
idade, faixas etarias e populacao contra o codigo original, arquivos ausentes,
colunas obrigatorias, denominadores invalidos e conflitos por municipio-ano.
Tambem executa a etapa de preparacao com RDS sinteticos e verifica a
persistencia e a protecao contra sobrescrita.

Cobertura inicial prevista:

- Idades em horas, dias, meses e anos e limites das faixas etarias.
- Recodificacoes, valores desconhecidos e variaveis obrigatorias ausentes.
- Arquivos anuais ausentes e cobertura temporal incompleta.
- Unicidade de municipio-ano e cardinalidade das juncoes.
- Denominadores positivos e cobertura territorial.
- Distincao entre zero casos e informacao indisponivel.
- Reconciliacao dos totais e tratamento de residencia desconhecida.
- Renderizacao do relatorio com uma base sintetica.

Com `testthat`, `withr`, `purrr`, `readr`, `dplyr` e `lubridate` instalados,
executar na raiz:

```r
testthat::test_dir("tests/testthat")
```

O projeto e uma analise, nao um pacote R. Os testes deverao carregar
explicitamente as funcoes necessarias de `R/`.
