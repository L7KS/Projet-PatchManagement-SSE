$FichierComputers = ".\computers.txt"
$FichierRequis = ".\required-patches.txt"
$LogFile = ".\Patch Manager.log"
$HtmlReport = ".\SecurityReport.html"
$CsvReport = ".\SecurityReport.csv"

function Write-Log {
    param ([string]$Message)$Timestamp = (Get-Date).ToString("dd/MM/yyyy HH:mm:ss")
    $LogLine = "$Timestamp; $Message"
    Add-Content -Path $LogFile -Value $LogLine
    Write-Host $LogLine -ForegroundColor Cyan
}

Set-Content -Path $LogFile -Value ""
Write-Log "Début de l'audit"

if (-Not (Test-Path $FichierRequis)) {
    Write-Log "ERREUR; Fichier required-patches.txt introuvable"
    Write-Host "Le fichier required-patches.txt est introuvable !" -ForegroundColor Red
    exit
}
$KBsRequis = Get-Content $FichierRequis | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

Write-Host "Veuillez entrer les identifiants pour l'administration à distance :" -ForegroundColor Yellow
$Cred = Get-Credential

$Resultats = @()
$Lignes = Get-Content $FichierComputers

$TotalPostes = 0
$TotalAccessibles = 0
$TotalInaccessibles = 0
$TotalConformes = 0
$TotalNonConformes = 0
$TotalCorrectifsManquants = 0

foreach ($Ligne in $Lignes) {
    if ([string]::IsNullOrWhiteSpace($Ligne)) { continue }$TotalPostes++
    $Donnees =$Ligne -split ";"
    $Nom =$Donnees[0].Trim()
    $IP =$Donnees[1].Trim()

    $EtatAccess = "Inaccessible"
    $EtatConf = "INACCESSIBLE"
    $WinVer = "N/A"
    $DernierBoot = "N/A"
    $WUState = "N/A"
    $KBsManquantes = @()

    if (Test-Connection -ComputerName $IP -Count 1 -Quiet) {
        try {
            # Utilisation d'une session explicite pour éviter les blocages IP en Workgroup
            $Session = New-PSSession -ComputerName $IP -Credential $Cred -ErrorAction Stop

            $Info = Invoke-Command -Session $Session -ScriptBlock {
                $OS = Get-CimInstance Win32_OperatingSystem
                $WU = Get-Service -Name wuauserv
                $HotFixes = Get-HotFix -ErrorAction SilentlyContinue | Select-Object -ExpandProperty HotFixID
                
                [PSCustomObject]@{
                    Windows = $OS.Caption
                    DernierBoot = $OS.LastBootUpTime
                    WU_Etat = $WU.Status
                    HotFixes = $HotFixes
                }
            }
            
            Remove-PSSession -Session $Session

            $EtatAccess = "Accessible"
            Write-Log "$Nom; Accessible"
            $TotalAccessibles++

            $WinVer = $Info.Windows
            $DernierBoot = $Info.DernierBoot
            $WUState = $Info.WU_Etat

            foreach ($kb in $KBsRequis) {
                if ($Info.HotFixes -notcontains $kb) {
                    $KBsManquantes += $kb
                }
            }

            if ($KBsManquantes.Count -eq 0) {
                $EtatConf = "CONFORME"
                $TotalConformes++
                Write-Log "$Nom; Conforme"
            } else {
                $EtatConf = "NON CONFORME"
                $TotalNonConformes++
                $TotalCorrectifsManquants += $KBsManquantes.Count
                Write-Log "$Nom; Non conforme; $($KBsManquantes -join ', ')"
            }

        } catch {
            $EtatAccess = "WinRM inaccessible"
            $TotalInaccessibles++
            Write-Log "$Nom; WinRM inaccessible"
        }
    } else {
        $TotalInaccessibles++
        Write-Log "$Nom; Inaccessible"
    }
$Resultats += [PSCustomObject]@{
        Poste = $Nom
        AdresseIP = $IP
        EtatAcces = $EtatAccess
        Windows = $WinVer
        DernierDemarrage = $DernierBoot
        WindowsUpdate = $WUState
        NbRequis = $KBsRequis.Count
        NbManquants = if ($EtatConf -eq "INACCESSIBLE") { "N/A" } else { $KBsManquantes.Count }
        ListeManquantes = ($KBsManquantes -join ", ")
        EtatConformite = $EtatConf
        DateControle = (Get-Date).ToString("dd/MM/yyyy HH:mm")
    }
}

Write-Log "Rapport généré"
Write-Log "Fin de l'audit"

$TauxConformite = 0
if ($TotalAccessibles -gt 0) {$TauxConformite = [math]::Round(($TotalConformes / $TotalAccessibles) * 100, 2)
}

$HtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Rapport de Sécurité - Patch Management</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f4f6f9; color: #333; }
        h1, h2 { color: #0056b3; }
        .summary-box { background: #fff; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; }
        .summary-box ul { list-style-type: none; padding: 0; }
        .summary-box li { padding: 6px 0; border-bottom: 1px solid #eee; }
        table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th, td { padding: 12px 15px; border: 1px solid #ddd; text-align: left; font-size: 14px; }
        th { background-color: #0056b3; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .conforme { color: #28a745; font-weight: bold; }
        .non-conforme { color: #dc3545; font-weight: bold; }
        .inaccessible { color: #ffc107; font-weight: bold; }
    </style>
</head>
<body>
    <h1>Rapport de Sécurité - Patch Management Windows</h1>
    <p><b>Date et heure du contrôle :</b> $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")</p>

    <div class="summary-box">
        <h2>Synthèse Globale du Parc</h2>
        <ul>
            <li><b>Nombre total de postes :</b> $TotalPostes</li>
            <li><b>Nombre de postes accessibles :</b> $TotalAccessibles</li>
            <li><b>Nombre de postes inaccessibles :</b> $TotalInaccessibles</li>
            <li><b>Nombre de postes conformes :</b> $TotalConformes</li>
            <li><b>Nombre de postes non conformes :</b> $TotalNonConformes</li>
            <li><b>Total des correctifs manquants :</b> $TotalCorrectifsManquants</li>
            <li><b>Taux de conformité global :</b> $TauxConformite %</li>
        </ul>
    </div>

    <h2>Détail des Postes et Anomalies</h2>
    <table>
        <tr>
            <th>Poste</th>
            <th>Adresse IP</th>
            <th>État Accès</th>
            <th>Version Windows</th>
            <th>Dernier Démarrage</th>
            <th>Service WU</th>
            <th>Manquants</th>
            <th>KB Manquantes</th>
            <th>Conformité</th>
        </tr>
"@

foreach ($res in $Resultats) {
    $classEtat = switch ($res.EtatConformite) {
        "CONFORME" { "conforme" }
        "NON CONFORME" { "non-conforme" }
        default { "inaccessible" }
    }
    $HtmlContent += "<tr>
        <td>$($res.Poste)</td>
        <td>$($res.AdresseIP)</td>
        <td>$($res.EtatAcces)</td>
        <td>$($res.Windows)</td>
        <td>$($res.DernierDemarrage)</td>
        <td>$($res.WindowsUpdate)</td>
        <td>$($res.NbManquants)</td>
        <td>$($res.ListeManquantes)</td>
        <td class='$classEtat'>$($res.EtatConformite)</td>
    </tr>"
}

$HtmlContent += @"
    </table>
</body>
</html>
"@

$HtmlContent | Out-File -FilePath $HtmlReport -Encoding UTF8
$Resultats | Export-Csv -Path $CsvReport -NoTypeInformation -Delimiter ";" -Encoding UTF8

Write-Host "`n--- SYNTHÈSE GLOBALE ---" -ForegroundColor Green
Write-Host "Postes contrôlés : $TotalPostes"
Write-Host "Postes non conformes : $TotalNonConformes" -ForegroundColor Red
Write-Host "Postes inaccessibles : $TotalInaccessibles" -ForegroundColor Yellow
Write-Host "Taux de conformité : $TauxConformite %" -ForegroundColor Cyan
Write-Host "`nRapport HTML généré : $HtmlReport" -ForegroundColor Green
Write-Host "Journal d'exécution mis à jour : $LogFile" -ForegroundColor Green