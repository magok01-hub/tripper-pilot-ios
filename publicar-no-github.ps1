$ErrorActionPreference = "Stop"

$repository = "https://github.com/magok01-hub/tripper-pilot-ios.git"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git não foi encontrado. Instale o Git for Windows e execute este arquivo novamente."
}

if (-not (Test-Path ".git")) {
    git init -b main
}

git add .
git commit -m "Add initial Tripper Pilot iOS prototype"

$origin = git remote get-url origin 2>$null
if (-not $origin) {
    git remote add origin $repository
} elseif ($origin -ne $repository) {
    git remote set-url origin $repository
}

git branch -M main
git push -u origin main

