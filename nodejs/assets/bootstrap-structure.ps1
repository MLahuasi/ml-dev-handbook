# bootstrap-structure.ps1
# Uso: Ejecuta este script en PowerShell desde la raíz donde quieras crear el proyecto.
# Crea todas las carpetas y archivos del proyecto (sin incluir `package.json` ni artefactos).
# Requiere: PowerShell 5+
# Nota: No sobreescribe contenido existente; solo crea archivos vacíos si no existen.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Ensure-File {
  param([string]$Path)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType File -Path $Path | Out-Null
  }
}

# --- Crear carpetas base ---

Ensure-Dir '.'
Ensure-Dir 'src'
Ensure-Dir 'tests'
Ensure-Dir 'src\config'
Ensure-Dir 'src\domain'
Ensure-Dir 'src\infrastructure'
Ensure-Dir 'src\presentation'
Ensure-Dir 'tests\domain'
Ensure-Dir 'tests\infrastructure'
Ensure-Dir 'tests\presentation'
Ensure-Dir 'src\config\plugins'
Ensure-Dir 'src\domain\dtos'
Ensure-Dir 'src\domain\entities'
Ensure-Dir 'src\domain\repositories'
Ensure-Dir 'src\domain\use-cases'
Ensure-Dir 'src\infrastructure\adapters'
Ensure-Dir 'src\infrastructure\datasources'
Ensure-Dir 'src\infrastructure\repositories'
Ensure-Dir 'src\presentation\user'
Ensure-Dir 'src\domain\use-cases\user'
Ensure-Dir 'src\infrastructure\datasources\json'
Ensure-Dir 'src\presentation\user\dto'

# --- Crear archivos ---
Ensure-File '.env'
Ensure-File '.env.template'
Ensure-File '.gitignore'
Ensure-File 'README.md'
Ensure-File 'jest.config.cjs'
Ensure-File 'src\app.ts'
Ensure-File 'src\config\plugins\envs.plugin.ts'
Ensure-File 'src\domain\dtos\create-user.dto.ts'
Ensure-File 'src\domain\dtos\index.ts'
Ensure-File 'src\domain\entities\index.ts'
Ensure-File 'src\domain\entities\user.entity.ts'
Ensure-File 'src\domain\repositories\index.ts'
Ensure-File 'src\domain\repositories\user.repository.ts'
Ensure-File 'src\domain\use-cases\user\create-user.use-case.ts'
Ensure-File 'src\domain\use-cases\user\index.ts'
Ensure-File 'src\infrastructure\adapters\index.ts'
Ensure-File 'src\infrastructure\datasources\json\users.datasource.ts'
Ensure-File 'src\infrastructure\datasources\json\users.json'
Ensure-File 'src\infrastructure\repositories\index.ts'
Ensure-File 'src\infrastructure\repositories\user.repository.impl.ts'
Ensure-File 'src\presentation\routes.ts'
Ensure-File 'src\presentation\server.ts'
Ensure-File 'src\presentation\user\controller.ts'
Ensure-File 'src\presentation\user\dto\create-user.request.dto.ts'
Ensure-File 'src\presentation\user\dto\index.ts'
Ensure-File 'src\presentation\user\index.ts'
Ensure-File 'tests\app.test.ts'
Ensure-File 'tests\domain\create-user.use-case.test.ts'
Ensure-File 'tests\infrastructure\user.repository.impl.test.ts'
Ensure-File 'tests\presentation\user.routes.test.ts'
Ensure-File 'tsconfig.json'
