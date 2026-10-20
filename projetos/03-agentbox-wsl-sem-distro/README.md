# 03 — `agentbox wsl init` abortando quando não há distro instalada

**Ano:** 2026 · **Áreas:** WSL 2 · Linux · CLI · diagnóstico
**Resultado:** ambiente WSL 2 + Ubuntu 24.04 + AgentBox configurado

---

## Resumo

Depois de instalar o WSL 2 numa máquina limpa, o `agentbox wsl init` abortou
porque `wsl --list --verbose` não retornou nenhuma distribuição. Lista vazia não
é falha: é apenas "ainda não há distro". O comando tratava a saída vazia como
erro. Instalei o Ubuntu antes de inicializar o AgentBox e o fluxo seguiu — o
tropeço seguinte foi a criação do usuário Linux, que o assistente não concluía.

## Contexto

| Item | Valor |
|---|---|
| Sistema | Windows 10 Pro 22H2 (build 19045.3803) |
| WSL | 3.0.1.0 (instalado pelo MSI oficial) |
| Distro instalada depois | Ubuntu 24.04 (WSL 2) |
| Ferramenta | AgentBox |
| Objetivo | Deixar o AgentBox pronto para rodar agentes |
| Restrição | Nenhuma distro Linux existia na máquina ainda |

## O sintoma

Com o WSL recém-instalado e nenhuma distro registrada, o comando de inicialização
abortou:

```text
error: wsl --list --verbose: ... não tem distribuições instaladas
```

O WSL em si respondia normalmente — o problema era a interpretação da resposta.

## A virada

O erro não vinha do WSL: vinha do AgentBox ao ler a saída de
`wsl --list --verbose`. O comando devolve uma mensagem dizendo que não há
distribuições; o código tratou essa mensagem como erro fatal. Lista vazia deveria
cair no caminho de "nenhuma distro", não no de exceção.

## Correção

**1. Instalar uma distro antes de inicializar o AgentBox:**

```powershell
wsl --install -d Ubuntu-24.04 --web-download
```

**2. Rodar o `agentbox wsl init` de novo**, agora com uma distro presente.

## O segundo tropeço: usuário Linux

O assistente de primeira execução do Ubuntu falhava ao definir a senha:

```text
passwd: Authentication token manipulation error
```

A causa provável foi a digitação às cegas no prompt do assistente somada ao
layout de teclado. Criar o usuário direto como root resolveu:

```powershell
wsl -d Ubuntu-24.04 -u root -- bash -c "useradd -m -s /bin/bash lucas_aguiar; echo 'lucas_aguiar:SENHA' | chpasswd; printf '[user]\ndefault=lucas_aguiar\n' > /etc/wsl.conf; echo PRONTO"
```

`useradd` e `passwd` são comandos **Linux**: precisam rodar dentro do WSL, não no
PowerShell. Troque `SENHA` pela senha real na hora de executar.

## Resultado

```text
WSL              3.0.1.0
Ubuntu-24.04     v2  (DefaultUid=1000)
WslService       Running / Automatic
```

Com a distro instalada e o usuário criado, o AgentBox concluiu a configuração e
passou a rodar os agentes.

## O que eu levaria para o próximo problema

- **Saída vazia não é erro.** Antes de abortar, vale distinguir "comando falhou"
  de "comando não encontrou nada" — são caminhos diferentes.
- **Ferramenta de inicialização depende do estado anterior.** O `init` assumia uma
  distro que ainda não existia; instalar o pré-requisito primeiro destrava o fluxo.
- **Quando o assistente falha, o comando direto funciona.** `useradd` + `chpasswd`
  dentro do WSL resolveu o que o prompt interativo não concluía.

## Evidências

- Versão exata do AgentBox: `[PREENCHER]`
- Texto completo do erro do `agentbox wsl init`: `[PREENCHER]`
- Log do `agentbox wsl init` após a correção: `[PREENCHER]`
