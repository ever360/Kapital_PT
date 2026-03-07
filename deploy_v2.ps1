# === SCRIPT DE DESPLIEGUE KAPITAL CON VERSIONES ===

# 1. Solicitar versión del usuario
$NuevaVersion = Read-Host "Ingresa la nueva versión (ej: v1.1.3)"
$MensajeCommit = Read-Host "Describe los cambios brevemente"

# 2. Actualizar visualmente la versión en login_page.dart
$LoginPath = "lib\pages\login_page.dart"
(Get-Content $LoginPath) -replace "v\d+\.\d+\.\d+ - Estable", "$NuevaVersion - Estable" | Set-Content $LoginPath

# 3. Guardar en GIT RAMA MAIN
git add .
git commit -m "[$NuevaVersion] $MensajeCommit"
git push origin main

# 4. Compilar para la Web
flutter build web --base-href "/Kapital_PT/" --no-tree-shake-icons

# 5. Mover a carpeta temporal y desplegar en GH-PAGES
$DeployPath = "C:\temp_deploy_kapital"
if (Test-Path $DeployPath) { Remove-Item -Path $DeployPath -Recurse -Force }
New-Item -ItemType Directory -Force -Path $DeployPath
Copy-Item -Path "build\web\*" -Destination $DeployPath -Recurse -Force

cd $DeployPath
git init
git add .
git commit -m "Despliegue $NuevaVersion"
git remote add origin https://github.com/ever360/Kapital_PT.git
git push origin master:gh-pages --force

# 6. Volver al origen
cd C:\Users\everh\kapital_app
Write-Host "=========================================="
Write-Host "¡Despliegue de $NuevaVersion completado con éxito! 🚀"
Write-Host "URL: https://ever360.github.io/Kapital_PT/"
Write-Host "=========================================="
