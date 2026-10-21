$FichierComputers = ".\computers.txt"
$FichierRequis = ".\required-patches.txt"
$ExportCSV = ".\ComplianceReport.csv"


if (-Not (Test-Path $FichierRequis)) {
    Write-Host "Le fichier $FichierRequis est introuvable." -ForegroundColor Red
    exit
}
$KBsRequis = Get-Content $FichierRequis | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

Write-Host "Veuillez entrer les identifiants pour l'administration à distance :" -ForegroundColor Yellow
$Cred = Get-Credential

$Resultats = @()
$Lignes = Get-Content $FichierComputers

$TotalConformes = 0
$TotalAnalyses = 0

foreach ($Ligne in $Lignes) {
    if ([string]::IsNullOrWhiteSpace($Ligne)) { continue }
    $Donnees =$Ligne -split ";"
    $Nom =$Donnees[0].Trim()
    $IP =$Donnees[1].Trim()

    Write-Host "Analyse de conformité pour $Nom ($IP)..." -ForegroundColor Cyan
    
    $KBsManquantes = @()
    $Etat = "INACCESSIBLE"


    if (Test-Connection -ComputerName $IP -Count 1 -Quiet) {
        try {
            # 3. Récupération des KB installées
            $HotFixes = Invoke-Command -ComputerName $IP -Credential $Cred -ErrorAction Stop -ScriptBlock {
                Get-HotFix | Select-Object -ExpandProperty HotFixID
            }
            

            foreach ($kb in $KBsRequis) {
                if ($HotFixes -notcontains $kb) {
                    $KBsManquantes +=$kb
                }
            }
            

            if ($KBsManquantes.Count -eq 0) {$Etat = "CONFORME"
                $TotalConformes++
            } else {
                $Etat = "NON CONFORME"
            }
            $TotalAnalyses++
            
        } catch {
            $Etat = "INACCESSIBLE"
        }
    } else {
        $Etat = "INACCESSIBLE"
    }


    $Resultats += [PSCustomObject]@{
        Poste = $Nom
        KB_Requises = $KBsRequis.Count
        KB_Manquantes = if ($Etat -eq "INACCESSIBLE") { "N/A" } else { $KBsManquantes.Count }
        Liste_Manquantes = $KBsManquantes -join ", "
        Etat = $Etat
        Date_Heure = (Get-Date).ToString("dd/MM/yyyy HH:mm")
    }
}


Write-Host "`n--- Rapport de Conformité ---" -ForegroundColor Green
$Resultats | Format-Table -AutoSize

if ($TotalAnalyses -gt 0) {
    $Taux = [math]::Round(($TotalConformes / $TotalAnalyses) * 100, 2)
    Write-Host "Taux de conformité global (sur les postes analysés) : $Taux %" -ForegroundColor Yellow
}

$Resultats | Export-Csv -Path $ExportCSV -NoTypeInformation -Delimiter ";" -Encoding UTF8
Write-Host "`nRapport de conformité exporté dans : $ExportCSV" -ForegroundColor Green