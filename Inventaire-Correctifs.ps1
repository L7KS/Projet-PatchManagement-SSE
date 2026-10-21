$Fichier = ".\computers.txt"
$ExportCSV = ".\Patches_Inventory.csv"

Write-Host "Veuillez entrer les identifiants pour l'administration à distance :" -ForegroundColor Yellow
$Cred = Get-Credential

$Resultats = @()
$Lignes = Get-Content $Fichier

foreach ($Ligne in $Lignes) {
    if ([string]::IsNullOrWhiteSpace($Ligne)) { continue }
    $Donnees =$Ligne -split ";"
    $Nom =$Donnees[0].Trim()
    $IP =$Donnees[1].Trim()

    Write-Host "Recherche des correctifs sur $Nom ($IP)..." -ForegroundColor Cyan

    if (Test-Connection -ComputerName $IP -Count 1 -Quiet) {
        try {
            $HotFixes = Invoke-Command -ComputerName $IP -Credential $Cred -ErrorAction Stop -ScriptBlock {
                Get-HotFix | Select-Object HotFixID, Description, InstalledOn, InstalledBy
            }

            foreach ($Patch in $HotFixes) {$Resultats += [PSCustomObject]@{
                    Poste = $Nom
                    AdresseIP = $IP
                    KB = $Patch.HotFixID
                    Description = $Patch.Description
                    Date_Installation = if ($Patch.InstalledOn) {$Patch.InstalledOn.ToString("dd/MM/yyyy") } else { "Inconnue" }
                    Installe_Par = $Patch.InstalledBy
                }
            }
        } catch {
            Write-Host "  -> Accès refusé ou impossible sur $Nom" -ForegroundColor Red
        }
    } else {
        Write-Host "  -> $Nom est inaccessible sur le réseau" -ForegroundColor Red
    }
}

$ResultatsTries =$Resultats | Sort-Object Poste, @{Expression={$_."Date_Installation" -as [datetime]}; Descending=$true}

Write-Host "`n--- Résumé des correctifs ---" -ForegroundColor Green
$Groupes = $ResultatsTries | Group-Object Poste
foreach ($Groupe in $Groupes) {
    $DernierPatch = $Groupe.Group | Select-Object -First 1
    Write-Host "Poste : $($Groupe.Name) | Total correctifs : $($Groupe.Count) | Dernier : $($DernierPatch.KB) le $($DernierPatch.Date_Installation)"
}


$ResultatsTries | Export-Csv -Path $ExportCSV -NoTypeInformation -Delimiter ";" -Encoding UTF8
Write-Host "`nInventaire des correctifs exporté dans : $ExportCSV" -ForegroundColor Green