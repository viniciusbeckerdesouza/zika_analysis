# Dependencias

O ambiente `renv` ainda nao foi inicializado neste projeto.
Nao foram criados `renv.lock`, `activate.R` ou mecanismos de ativacao automatica.
Esses arquivos devem ser gerados pelo proprio `renv`, nao escritos manualmente.

Depois de migrar o codigo e confirmar as dependencias:

1. Inicializar o projeto com `renv::init()` em uma sessao R na raiz.
2. Revisar as dependencias detectadas, incluindo as usadas via `pacote::funcao`.
3. Executar `renv::snapshot()` e revisar o arquivo `renv.lock`.
4. Versionar o lockfile e os arquivos de infraestrutura gerados pelo `renv`,
   mas nao sua biblioteca local.
5. Testar a restauracao com `renv::restore()` em uma copia limpa.

As versoes de R, Pandoc e bibliotecas de sistema necessarias a `sf` tambem
deverao ser documentadas. Um lockfile nao provisiona essas dependencias externas.
