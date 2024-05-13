# Script per la creazione degli utenti Guest su Azure Active Directory
Questo script PowerShell automatizza la creazione di utenti guest nell'ambiente Microsoft Azure Active Directory (AAD) utilizzando un file Excel come input. Estrae i dettagli degli utenti, come nome visualizzato e indirizzo email, quindi invita gli utenti guest utilizzando il modulo New-AzureADMSInvitation. Successivamente, modifica gli indirizzi email degli utenti guest aggiungendo un'estensione per distinguerli dagli utenti interni. Aggiunge anche il nome e il cognome agli utenti guest. L'utente può scegliere di assegnare gli utenti al gruppo MFA Production per l'autenticazione a due fattori. Questo script semplifica notevolmente la gestione degli utenti guest in Azure AD, qualora fosse richiesta una creazione massiva di utenti.
