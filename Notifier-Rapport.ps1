$CsvReport = ".\SecurityReport.csv"
$HtmlReport = ".\SecurityReport.html"
$LogFile = ".\Patch Manager.log"

if (-Not (Test-Path $CsvReport)) {
    Write-Host "Rapport CSV introuvable. Lancez d'abord l'audit." -ForegroundColor Red
    exit
}

$Rapport = Get-Content $CsvReport | ConvertFrom-Csv -Delimiter ";"
$TotalPostes = @($Rapport).Count
$PostesNonConformes = @($Rapport | Where-Object { $_.EtatConformite -eq "NON CONFORME" })
$PostesInaccessibles = @($Rapport | Where-Object { $_.EtatConformite -eq "INACCESSIBLE" })

$NbNonConformes = $PostesNonConformes.Count
$NbInaccessibles = $PostesInaccessibles.Count

# Condition : Si aucune anomalie, le script s'arrête sans notifier (comme demandé)
if ($NbNonConformes -eq 0 -and $NbInaccessibles -eq 0) {
    Write-Host "Aucune anomalie détectée. Aucune notification envoyée." -ForegroundColor Green
    exit
}

$DateControle = Get-Date -Format "dd/MM/yyyy"
$TimestampLog = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

# Construction du corps du message exigé par le sujet
$Corps = @"
Objet : [PATCH MANAGEMENT] Anomalies détectées

Date du contrôle : $DateControle

Postes contrôlés     : $TotalPostes
Postes non conformes : $NbNonConformes
Postes inaccessibles : $NbInaccessibles

"@

foreach ($p in $PostesNonConformes) {
    $Corps += "$($p.Poste) : NON CONFORME`n       $($p.ListeManquantes) manquante`n`n"
}

foreach ($p in $PostesInaccessibles) {$Corps += "$($p.Poste) : INACCESSIBLE`n`n"
}



$SmtpServer = "smtp.gmail.com"
$SmtpPort = 587
$Expediteur = "thbrandy05@gmail.com"
$Destinataire = "admin@entreprise.local"
$Sujet = "[PATCH MANAGEMENT] Anomalies détectées"
$Credential = Get-Credential

try {
    # Tentative d'envoi de l'e-mail avec le rapport HTML en pièce jointe
    Send-MailMessage -SmtpServer $SmtpServer -Port $SmtpPort -UseSsl -Credential $Credential -From $Expediteur -To $Destinataire -Subject  $Sujet -Body $Corps -Attachments $HtmlReport -ErrorAction Stop
    
    # Journalisation du succès (Format exact du sujet)
    $LogLine = "$TimestampLog ; Notification envoyée à $Destinataire"
    Add-Content -Path $LogFile -Value $LogLine
    Write-Host "Notification envoyée avec succès." -ForegroundColor Green
}
catch {
    # Journalisation de l'échec (Format exact du sujet)
    $LogLine = "$TimestampLog ; ERREUR ; Notification non envoyée"
    Add-Content -Path $LogFile -Value $LogLine
    Write-Host "Échec de l'envoi SMTP. L'erreur a été consignée dans le journal." -ForegroundColor Yellow
}