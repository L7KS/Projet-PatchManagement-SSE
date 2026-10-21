$Fichier = ".\computers.txt"
$ExportCSV = ".\Inventaire.csv"

Write-Host "Veuillez entrer les identifiants pour l'administration à distance (ex: .\thbra) :" -ForegroundColor Yellow
$Cred = Get-Credential

$Resultats = @()
$Lignes = Get-Content $Fichier

foreach ($Ligne in $Lignes) {
    if ([string]::IsNullOrWhiteSpace($Ligne)) { continue }
    
    $Donnees = $Ligne -split ";"
    $Nom = $Donnees[0].Trim()
    $IP = $Donnees[1].Trim()

    Write-Host "Collecte des informations sur $Nom ($IP)..." -ForegroundColor Cyan

    $Etat = "Inaccessible"
    $Info = $null

    if (Test-Connection -ComputerName $IP -Count 1 -Quiet) {
        try {
            $Info = Invoke-Command -ComputerName $IP -Credential $Cred -ErrorAction Stop -ScriptBlock {
                $OS = Get-CimInstance Win32_OperatingSystem
                $CS = Get-CimInstance Win32_ComputerSystem
                $Bios = Get-CimInstance Win32_BIOS
                $Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
                $WU = Get-Service -Name wuauserv
                $HotFixes = Get-HotFix -ErrorAction SilentlyContinue
                
                [PSCustomObject]@{
                    Modele = $CS.Model
                    Bios = $Bios.SMBIOSBIOSVersion
                    Windows = $OS.Caption
                    Architecture = $OS.OSArchitecture
                    DernierDemarrage = $OS.LastBootUpTime
                    RAM_Go = [math]::Round($CS.TotalPhysicalMemory / 1GB, 2)
                    EspaceLibre_Go = [math]::Round($Disk.FreeSpace / 1GB, 2)
                    WU_Etat = $WU.Status
                    NbMaj = if ($HotFixes) { @($HotFixes).Count } else { 0 }
                    DerniereMaj = if ($HotFixes) { (@($HotFixes) | Sort-Object InstalledOn -Descending)[0].InstalledOn } else { "N/A" }
                }
            }
            $Etat = "Accessible"
        } catch {
            $Etat = "Erreur d'accès distant (Identifiants ou WinRM)"
        }
    }

    $Resultats += [PSCustomObject]@{
        Poste = $Nom
        AdresseIP = $IP
        Modele = if ($Info) { $Info.Modele } else { "N/A" }
        Bios = if ($Info) { $Info.Bios } else { "N/A" }
        Windows = if ($Info) { $Info.Windows } else { "N/A" }
        Architecture = if ($Info) { $Info.Architecture } else { "N/A" }
        DernierDemarrage = if ($Info) { $Info.DernierDemarrage } else { "N/A" }
        RAM_Go = if ($Info) { $Info.RAM_Go } else { "N/A" }
        EspaceDisque_Go = if ($Info) { $Info.EspaceLibre_Go } else { "N/A" }
        WindowsUpdate = if ($Info) { $Info.WU_Etat } else { "N/A" }
        Nb_MAJ = if ($Info) { $Info.NbMaj } else { "N/A" }
        Derniere_MAJ = if ($Info) { $Info.DerniereMaj } else { "N/A" }
        Etat = $Etat
    }
}

Write-Host "`n--- Tableau Récapitulatif ---" -ForegroundColor Green
$Resultats | Format-Table -AutoSize

$Resultats | Export-Csv -Path $ExportCSV -NoTypeInformation -Delimiter ";" -Encoding UTF8
Write-Host "Inventaire exporté avec succès dans le fichier : $ExportCSV" -ForegroundColor Green