# 01 — WSL 2 no Windows 10: "Acesso negado" escondendo quatro problemas

**Ano:** 2026 · **Áreas:** Windows · registro/ACL · virtualização · WSL
**Tempo:** ~1 dia (investigação intercalada) · **Resultado:** WSL 3.0.1 + Ubuntu 24.04 funcionando

---

## Resumo

Instalar o WSL 2 num Windows 10 22H2 falhava com um `Acesso negado 0,0%` genérico,
**inclusive em janela de administrador**. O erro não apontava para a causa real:
a chave de registro do serviço Windows Update estava com ACL **somente leitura** —
sobra de uma ferramenta de bloqueio de updates.

Resolvida essa camada, apareceram mais três bloqueios independentes: um flag que
não existia na build antiga do `wsl.exe`, o **VT-x desligado na BIOS** e o **WSLg**
quebrado (erros de RemoteApp). O que parecia "Windows bichado" eram quatro
problemas empilhados.

**Resultado:** WSL 3.0.1 + Ubuntu 24.04 + AgentBox rodando, com o processo todo
documentado e reaplicável.

---

## Contexto

| Item | Valor |
|---|---|
| Sistema | Windows 10 Pro 22H2 (19045.3803) |
| Hardware | ASUS P8H61-M LX3 R2.0 · Intel Xeon E3-1230 V2 |
| Objetivo | Rodar o AgentBox, que exige WSL 2 |
| Restrição | O comando oficial (`wsl --install --no-distribution`) não funcionava |

## O sintoma

```text
C:\Users\Lucas Aguiar>wsl --install --no-distribution
A operação solicitada requer elevação.
Instalando: Subsistema do Windows para Linux
Acesso negado.              0,0%
```

O detalhe que chamou atenção: **acontecia igual em janela elevada**. E não era só
o WSL — `Set-Service`, `Start-Service` e `dism /online /enable-feature` também
retornavam "Acesso negado".

A saída acima é da execução que chegou a iniciar a instalação. Na build
`10.0.19041.4522` do `wsl.exe` o parâmetro `--no-distribution` ainda não era
reconhecido — esse é o bloqueio 2, encontrado depois e descrito mais abaixo.

## Hipóteses que caíram

| Hipótese | Como testei | Resultado |
|---|---|---|
| Falta de privilégio | `whoami /groups` na janela | `Administradores` presente — estava elevada |
| Política de grupo | `Policies\Microsoft\Windows\WindowsUpdate\AU` | Só `NoAutoUpdate=1` |
| Antivírus de terceiros | Serviços e programas instalados | Nenhum |
| Store corrompida | `wsl --update`, `--web-download` | Falhava igual |
| Driver de anti-cheat | Serviços não-Microsoft | Presentes, mas irrelevantes |

## A virada: comparar com os vizinhos

Em vez de investigar o serviço isolado, comparei a chave dele com **todas** as
outras chaves de serviço do Windows:

```powershell
$root = 'HKLM:\SYSTEM\CurrentControlSet\Services'
$need = [System.Security.AccessControl.RegistryRights]::SetValue -bor `
        [System.Security.AccessControl.RegistryRights]::ChangePermissions

$keys = Get-ChildItem $root
$bad = foreach ($k in $keys) {
    $acl = Get-Acl $k.PSPath
    $ok = $false
    foreach ($ace in $acl.Access) {
        if ($ace.AccessControlType -ne 'Allow') { continue }
        if ($ace.IdentityReference -notmatch 'SISTEMA|SYSTEM|Administradores|Administrators') { continue }
        if (($ace.RegistryRights -band $need) -eq $need) { $ok = $true; break }
    }
    if (-not $ok) { $k.PSChildName }
}
"Chaves de servico travadas (sem SetValue p/ SYSTEM/Admins): $($bad.Count) de $($keys.Count)"
$bad
```

```text
Chaves de servico travadas (sem SetValue p/ SYSTEM/Admins): 1 de 772
wuauserv
```

**1 outlier entre 772 chaves.** A ACL era só leitura para todo mundo:

```text
HKLM\SYSTEM\CurrentControlSet\Services\wuauserv
  Todos                     Allow  ReadKey
  NT AUTHORITY\SYSTEM       Allow  ReadKey
  BUILTIN\Administradores   Allow  ReadKey
```

Sem `SetValue`, o SCM não grava o tipo de inicialização do serviço → "Acesso negado"
em qualquer operação que dependa dele.

## Correção

Restaurar a DACL exige `WRITE_DAC`, que `Administradores` não tinha. A sequência:
tomar posse da chave (habilitando `SeTakeOwnership`), devolver `FullControl` para
`SYSTEM` e `Administradores`, religar o serviço e remover a política de update.

Script completo e idempotente nesta pasta: [`fix-wuauserv.ps1`](fix-wuauserv.ps1)

> O script termina mandando rodar `wsl --install --no-distribution`. Na build
> `10.0.19041.4522` isso ainda cai no bloqueio 2 — instale o WSL pelo MSI oficial
> antes de usá-lo.

O trecho que destrava a ACL:

```powershell
$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
    'SYSTEM\CurrentControlSet\Services\wuauserv',
    [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
    [System.Security.AccessControl.RegistryRights]::TakeOwnership)
$acl = $key.GetAccessControl()
$acl.SetOwner([System.Security.Principal.SecurityIdentifier]'S-1-5-32-544')
$key.SetAccessControl($acl)
```

Resultado: `wuauserv` → `Running / Manual`.

## Os outros três bloqueios

**2. Flag inexistente.** `wsl --install --no-distribution` retornava
`Unrecognized option: no-distribution` no `wsl.exe` 10.0.19041.4522; a Store
travava em `0,0%`. Solução: instalar o WSL pelo **MSI oficial**
([github.com/microsoft/WSL/releases](https://github.com/microsoft/WSL/releases)),
que não depende da Store. Passou a reportar `3.0.1.0`.

**3. Hypervisor não iniciava.** `HCS_E_HYPERV_NOT_INSTALLED` mesmo com
`VirtualMachinePlatform` instalado (confirmado no log do DISM) e
`hypervisorlaunchtype Auto`. O Event Viewer entregou o motivo:

```text
Microsoft-Windows-Hyper-V-Hypervisor · ID 41 · Erro
"Hypervisor launch failed; Either VMX not present or not enabled in BIOS."
```

→ **VT-x desligado na BIOS** (Advanced → CPU Configuration → Intel Virtualization
Technology). Depois do boot: `HvHost` = `Running`.

**4. RemoteApp / `rdpclientax.dll`.** Diálogos de ActiveX e "não foi possível
conectar ao computador remoto" ao abrir o WSL — era o **WSLg** tentando abrir
sessão RDP. Desnecessário para uso headless — em `C:\Users\<usuário>\.wslconfig`:

```ini
[wsl2]
guiApplications=false
```

Depois de salvar, `wsl --shutdown` para o WSL reler o arquivo.

## Resultado final

Estado final resumido a partir de `wsl --version`, `wsl -l -v` e
`Get-Service HvHost, WslService, wuauserv`:

```text
WSL              3.0.1.0
Ubuntu-24.04     v2  (DefaultUid=1000)
HvHost           Running
WslService       Running / Automatic
wuauserv         Running / Manual
```

O UID padrão da distro se confirma com `wsl -d Ubuntu-24.04 -- id -u`.

## Aprendizados

- **"Acesso negado" raramente é o que parece.** Comparar o objeto suspeito com os
  equivalentes revelou o problema em segundos — nenhuma documentação do WSL diria isso.
- **Ler o log certo economiza horas.** O Event Viewer disse em uma linha o que o
  código de erro do WSL não dizia.
- **Validar cada camada isoladamente.** Quatro problemas em sequência fazem o
  primeiro parecer a causa de todos.
- **Documentar o caminho** transforma um dia de dor em 10 minutos para a próxima pessoa.

## Arquivos deste projeto

| Arquivo | O que é |
|---|---|
| `README.md` | este caso |
| [`fix-wuauserv.ps1`](fix-wuauserv.ps1) | script que restaura a ACL e religa o serviço |
