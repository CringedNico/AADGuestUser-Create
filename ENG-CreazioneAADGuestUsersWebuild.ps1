<#
Script Name: ENG-CreazioneAADGuestUsersWebuild.ps1
Description: Questo script PowerShell automatizza il processo di creazione di utenti guest nell'ambiente Microsoft Azure Active Directory (AAD).
Author: Nicolò Bertucci
Date: 19/04/2024
#>

# Importa il modulo necessario per lavorare con file Excel
Import-Module -Name ImportExcel

Invoke-Expression -Command "Connect-AzureAD | Out-null"

# Ottiene i dati dal file di input
$file = $args[0]
$data = Import-Excel -Path $file

Write-Host $data

# Ottiene la colonna contenente gli indirizzi email e il displayname
$column = $data | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
$displaynames = $data | Select-Object -ExpandProperty $column[1]
$mailboxes = $data | Select-Object -ExpandProperty $column[2]

# Creo tutti gli utenti guest (New-AzureADMSInvitation)
$redirectURL = "https://myapps.microsoft.com/?tenantid=85f2c903-844e-491f-aea6-5729a8d3b0e9"

$arrayLength = $mailboxes.Count

# Itera attraverso gli indici degli array
for ($i = 0; $i -lt $arrayLength; $i++) {
    $displayname = $displaynames[$i]
    $mailbox = $mailboxes[$i]

    Invoke-Expression -Command "New-AzureADMSInvitation -InvitedUserDisplayName '$displayname' -InvitedUserEmailAddress '$mailbox' -InviteRedirectUrl '$redirectURL' -InvitedUserType 'Guest'"
    Write-Host "Invitato utente con mailbox $mailbox e assegnato il displayname $displayname"
}
Write-Host

# Modifico la mail aggiungendo l'estensione mail dei guest
$guests = @()

foreach ($mailbox in $mailboxes) {
    $tmp = $mailbox -replace "@", "_"
    $tmp += "#EXT#@saliniimpregilo.onmicrosoft.com"
    $guests += $tmp
}

# Prendo l'objectID dei vari guest (Get-AzureADUser)
$ids = @()

# Itera attraverso gli indirizzi email e ottiene gli ID corrispondenti
foreach ($guest in $guests) { 
    $objectId = Invoke-Expression -Command "Get-AzureADUser -ObjectId '$guest' | Select-Object -ExpandProperty ObjectId"
    $ids += $objectId
}

# Ottiene la colonna contenente il nome e il cognome
$names = $data | Select-Object -ExpandProperty $column[3]
$surnames = $data | Select-Object -ExpandProperty $column[0]

# lancio il comando per modificare gli utenti e aggiungere nome e cognome (Set-AzureADUser)
for ($i = 0; $i -lt $arrayLength; $i++) {
    $objectId = $ids[$i]
    $name = $names[$i]
    $surname = $surnames[$i]

    Invoke-Expression -Command "Set-AzureADUser -ObjectId $objectId -GivenName '$name' -Surname '$surname'"
    Write-Host "Assegnato all'utente con ObjectID $objectID il nome e cognome: $name $surname"
}

do {
    Write-Host
    $mfa = Read-Host "Assegnare il gruppo MFA Production (y/N)"
    Write-Host

    if ($mfa -eq "Y" -or $mfa -eq "y") {

        foreach ($objectID in $ids) {
            Invoke-Expression -Command "Add-AzureADGroupMember -ObjectId '$objectID' -RefObjectId '3001a0d6-705c-480d-9faf-40dbf2c17a09'"
            Write-Host "Assegnato MFA all'utente con ObjectID: $objectID"
        }

        break
    }
    elseif ($mfa -eq "N" -or $mfa -eq "n" -or $mfa -eq "") {
        break
    }
    else {
        Write-Host "Input non valido. Si prega di inserire Y o N."
    }
} while ($true)