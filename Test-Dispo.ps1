$Fichier = ".\computers.txt"

if (-Not (Test-Path $Fichier)) {
    Write-Host "Le fichier $Fichier est introuvable." -ForegroundColor Red
    exit
}

$Lignes = Get-Content $Fichier

foreach ($Ligne in $Lignes) {
    $Donnees = $Ligne -split ";"
    $Nom = $Donnees[0].Trim()
    $IP = $Donnees[1].Trim()

    if (Test-Connection -ComputerName $IP -Count 1 -Quiet) {
        $Etat = "Accessible"
        $Couleur = "Green"
    } else {
        $Etat = "Inaccessible"
        $Couleur = "Red"
    }

    Write-Host "Poste : $Nom | IP : $IP | État : $Etat" -ForegroundColor $Couleur
}