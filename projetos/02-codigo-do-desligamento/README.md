# 02 — Do zero ao produto no ar: e-book + página de vendas

**Ano:** 2026 · **Áreas:** produto digital · HTML/CSS · deploy · checkout
**Resultado:** produto próprio publicado, com página de vendas no ar e pagamento integrado

---

## Resumo

Criei um e-book do zero — do conteúdo à diagramação — e construí a página de vendas
que o apresenta: narrativa de oferta, blocos de benefício, bônus, garantia e CTA.
Publiquei na Vercel e integrei o checkout da Kiwify (PIX e cartão) com link direto
para o pagamento.

Este é o primeiro projeto em que eu **criei o produto**, não só a parte técnica —
e a página precisou resolver tudo: convencer, tirar dúvida e vender.

## Contexto

| Item | Valor |
|---|---|
| Produto | E-book "Código do Desligamento" (higiene do sono e energia) |
| Público | Pessoas com sono ruim e cansaço crônico |
| Meu papel | Conteúdo, página, publicação e integração de pagamento |
| Preço | R$ 37,90 (âncora em R$ 97,00) |
| Modelo | Pagamento único · acesso imediato · garantia de 7 dias |

## O que eu fiz

1. **Escrevi o e-book do zero** — estrutura, capítulos e a promessa central
   (regulação de cortisol e higiene neurológica do sono).
2. **Montei a página de vendas** — hierarquia da informação pensada para leitura
   em celular: dor → consequência → mecanismo → conteúdo → oferta → garantia.
3. **Publiquei na Vercel** — deploy contínuo a partir do repositório.
4. **Integrei o checkout** — link direto para a Kiwify, com PIX e cartão.

## Estrutura da página (a decisão que mais importou)

A ordem foi escolhida para conduzir a leitura, não para listar features:

| Bloco | Função |
|---|---|
| Headline ("VOCÊ ACORDA Atropelado?") | Identificar a dor em uma frase |
| O sequestro da mente | Fazer o leitor se reconhecer (sintomas em bullets) |
| O que você vai encontrar | Prometer o mecanismo, não o formato |
| Conteúdo do código | Dar peso ao material (3 pilares) |
| Oferta + bônus | Ancorar valor (R$ 97 → R$ 37,90 + checklist grátis) |
| Garantia de 7 dias | Transferir o risco para mim |
| CTA repetido | Não obrigar o leitor a rolar de volta |

## Stack

`HTML` · `CSS` · `Vercel` (deploy) · `Kiwify` (checkout) · imagens próprias

## Problemas e soluções

**Problema:** o repositório acumulou lixo de empacotamento (`__MACOSX/`, `._*`,
`.DS_Store`) e imagens duplicadas em várias pastas.
**Solução:** `.gitignore` + remoção dos arquivos versionados por engano.
> Ainda pendente neste repositório — registrado aqui como transparência.

**Problema:** PIX e cartão precisavam conviver na mesma oferta sem quebrar a
confiança no momento do clique.
**Solução:** selos das bandeiras junto ao preço e checkout externo único (Kiwify),
para não construir e manter uma integração de pagamento própria.

## O que eu validaria em seguida

O produto está no ar, mas ainda não tenho números para afirmar resultado. Em vez
de estimar, este é o plano de medição — cada métrica responde a uma pergunta
diferente:

| Métrica | Que pergunta responde | Como eu mediria |
|---|---|---|
| Visitas na página | Alguém chega até a oferta? | Analytics da Vercel (ou logs de acesso), separando origem |
| Cliques no CTA | A oferta convence? | Cliques ÷ visitas, por origem |
| Conversão do checkout | Preço ou meio de pagamento travam? | Vendas ÷ checkouts abertos, separando PIX e cartão |
| Tempo até a primeira venda | Quanto o funil leva para maturar? | Data de publicação → data da primeira venda |
| Reembolsos na garantia | A promessa se sustenta? | Reembolsos ÷ vendas no período de 7 dias |

Com esses cinco números dá para dizer onde o funil perde — tráfego, oferta ou
pagamento — em vez de atribuir tudo a "página que não converte".

## Aprendizados

- **Página de vendas é engenharia de atenção**: a ordem dos blocos muda o resultado
  mais que a estética.
- **Checkout é onde a confiança se prova**: preço, garantia e meios de pagamento
  precisam estar visíveis antes do clique.
- **Publicar cedo vale mais que polir**: estar no ar permitiu feedback real.
- **Higiene de repositório importa**: um repo limpo é a diferença entre "projeto" e
  "rascunho".

## Links

- Página no ar: [codigo-do-desligamento.vercel.app](https://codigo-do-desligamento.vercel.app)
- Código-fonte: [LucasVieira009/Codigo-do-desligamento](https://github.com/LucasVieira009/Codigo-do-desligamento)
