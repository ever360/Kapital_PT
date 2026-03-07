# === Deploy Kapital PWA ===

# 1. Guardar cambios en main
git checkout main
git add .
$msg = Read-Host "Escribe el mensaje del commit en main"
git commit -m "$msg"
git push origin main

# 2. Compilar Flutter Web
flutter build web --no-tree-shake-icons

# 3. Corregir index.html (base href)
(Get-Content build\web\index.html) -replace '<base href="/">', '<base href="/Kapital_App/">' | Set-Content build\web\index.html

# 4. Copiar compilados a carpeta temporal
Copy-Item build\web\* C:\deploy_temp -Recurse -Force

# 5. Validar compilados antes de limpiar gh-pages
if (!(Test-Path C:\deploy_temp\index.html)) {
    Write-Host "❌ Error: No se encontraron compilados en C:\deploy_temp"
    exit
}

# 6. Cambiar a gh-pages y limpiar
git checkout gh-pages
git rm -rf .

# 7. Pegar compilados y publicar
Copy-Item C:\deploy_temp\* . -Recurse -Force
git add .
git commit -m "Deploy Kapital PWA"
git push origin gh-pages --force

# 8. Volver a main
git checkout main

# 9. forzar actualizado
git add .
git commit -m "Descripción de los cambios realizados"

Write-Host "==============================="
Write-Host "Deploy Kapital PWA completado 🚀"
Write-Host "==============================="