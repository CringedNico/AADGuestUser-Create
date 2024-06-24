<#
Script Name: ENG-CreazioneAADGuestUsersWebuild.ps1
Description: Questo script PowerShell automatizza il processo di creazione di utenti guest nell'ambiente Microsoft Azure Active Directory (AAD).

Author: Nicolò Bertucci
Contributors: Armando Romeo

First release date: 19/04/2024
Last edit date: 19/06/2024

Patch notes:
- Aggiunto sistema log
- Aggiunto gestione errore creazione utenze
- Fix creazione utenti guest che contengono il singolo apice
#>

# Importa il modulo necessario per lavorare con file Excel
Import-Module -Name ImportExcel

Connect-AzureAD | Out-null

# Controllo esistenza folder logs
if(-not (Test-Path ".\logs")) {
    # Creazione della folder qualora non esistesse
    New-Item -ItemType Directory -Force -Path ".\logs"
}

# Definizione funzione di Log dello script
$DateFile = (Get-Date).ToString("yyyyMMdd-HHmm")
$Logfile = ".\logs\" + $DateFile + "-creazioneAADGuestUsersWebuild.log"
function WriteLog {
    Param ([string]$LogString)
    $TimeLog = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss")
    $LogMessage = "$TimeLog $LogString"
    Add-Content $LogFile -Value $LogMessage
}

WriteLog "[INFO] Creazione utenti Guest"
#WriteLog "[INFO] "

### MAIN ###

# Ottiene i dati dal file di input
$file = $args[0]
$data = Import-Excel -Path $file

# Ottiene la colonna contenente gli indirizzi email e il displayname
$column = $data | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
$displaynames = $data | Select-Object -ExpandProperty $column[1]
$mailboxes = $data | Select-Object -ExpandProperty $column[2]

# Creo tutti gli utenti guest (New-AzureADMSInvitation)
$redirectURL = "https://myapps.microsoft.com/?tenantid=85f2c903-844e-491f-aea6-5729a8d3b0e9"

$arrayLength = $mailboxes.Count

# Modifico la mail aggiungendo l'estensione mail dei guest
$guests = @()

WriteLog "[INFO] trasformazione UPN utenti..."

foreach ($mailbox in $mailboxes) {
    $tmp = $mailbox -replace "@", "_"
    $tmp += "#EXT#@saliniimpregilo.onmicrosoft.com"
    $guests += $tmp

    WriteLog "[INFO] $mailbox -> $tmp"
}

# Itera attraverso gli indici degli array
WriteLog "[INFO] Verifica esistenza utenti guest..."

for ($i = 0; $i -lt $arrayLength; $i++) {
    $displayname = $displaynames[$i]
    $mailbox = $mailboxes[$i]
    $guest = $guests[$i]

    WriteLog "[INFO] Check utente $displayname [$mailbox]..."

    if (Get-AzureADUser -Filter "UserPrincipalName eq '$($guest -replace "'", "''")'") {
        Write-Host "• Utente $displayname con mailbox $mailbox già presente nel tenant."
        WriteLog "[INFO] Utente presente!"
    } else {
        WriteLog "[INFO] Utente NON presente"
        WriteLog "[INFO] Crezione utente $displayname [$mailbox]..."
        try {
            New-AzureADMSInvitation -InvitedUserDisplayName "$displayname" -InvitedUserEmailAddress "$mailbox" -InviteRedirectUrl $redirectURL -InvitedUserType 'Guest' | Out-Null
            Write-Host "• Invitato utente con mailbox $mailbox e assegnato il displayname $displayname"
            WriteLog "[INFO] Utente creato ed invitato!"
        } catch {
            Write-Warning "• Non è stato possibile creare l'utente guest [$guest]"
            WriteLog "[ERROR] Non è stato possibile creare l'utente guest [$guest]: $($_.Exception.Message)"
        }
    }
}
Write-Host

# Prendo l'objectID dei vari guest (Get-AzureADUser)
$ids = @()

# Itera attraverso gli indirizzi email e ottiene gli ID corrispondenti
WriteLog "[INFO] Ottenimento IDs degli utenti..."
foreach ($guest in $guests) {
    WriteLog "[INFO] Guest $guest..."
    try {
        $objectId = Get-AzureADUser -Filter "UserPrincipalName eq '$($guest -replace "'", "''")'" | Select-Object -ExpandProperty ObjectId
        $ids += $objectId
        WriteLog "[INFO] Guest $guest = $objectId"
    } catch {
        Write-Warning "• Non è stato trovato l'utente [$guest] nel tenant"
        WriteLog "[ERROR] Utente [$guest] non trovato nel tenant: $($_.Exception.Message)"
    }
}

# Ottiene la colonna contenente il nome e il cognome
$names = $data | Select-Object -ExpandProperty $column[3]
$surnames = $data | Select-Object -ExpandProperty $column[0]

# lancio il comando per modificare gli utenti e aggiungere nome e cognome (Set-AzureADUser)
WriteLog "[INFO] Modifica informazioni anagrafiche utenti..."
for ($i = 0; $i -lt $arrayLength; $i++) {
    $objectId = $ids[$i]
    $name = $names[$i]
    $surname = $surnames[$i]

    WriteLog "[INFO] Aggiornamento $objectId [$name,$surname]..."

    try {
        Set-AzureADUser -ObjectId $objectId -GivenName "$name" -Surname "$surname"
        Write-Host "• Assegnato all'utente con ObjectID $objectId il nome e cognome: $name $surname"
        WriteLog "[INFO] Ok!"
    } catch {
        WriteLog "[ERROR] Si è verificato un errore: $($_.Exception.Message)"
    }
}

do {
    Write-Host
    $mfa = Read-Host "• Assegnare il gruppo MFA Production (y/N)"
    Write-Host

    if ($mfa -eq "Y" -or $mfa -eq "y") {
        WriteLog "[INFO] Assegnazione gruppo MFA agli utenti..."

        foreach ($objectId in $ids) {
            WriteLog "[INFO] Assegnando gruppo MFA all'utente $objectId..."

            try {
                Add-AzureADGroupMember -ObjectId '3001a0d6-705c-480d-9faf-40dbf2c17a09' -RefObjectId $objectId
                Write-Host "• Assegnato MFA all'utente con ObjectID: $objectId"
                WriteLog "[INFO] Ok!"
            } catch {
                WriteLog "[ERROR] Si è verificato un errore: $($_.Exception.Message)"
            }
        }
        break
    } elseif ($mfa -eq "N" -or $mfa -eq "n" -or $mfa -eq "") {
        break
    } else {
        Write-Host "• Input non valido. Si prega di inserire Y o N."
    }
} while ($true)

WriteLog "[INFO] Procedura completata!"
