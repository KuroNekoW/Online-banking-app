
# SE113 - Nhom 5
# Automation Testing: Basic API Tests
# Chi chay cac test co ban, khong test chuc nang khoa tai khoan.

$ErrorActionPreference = "Stop"

# Thu muc chua project Online-banking-app
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

# Duong dan file test
$testFile = Join-Path $root "automation testing\backend\tests\test_automation_basic.py"

# Thu muc luu bao cao
$reportDir = Join-Path $root "automation testing\reports"

# Kiem tra file va project
if (-not (Test-Path $testFile)) {
    throw "Khong tim thay file test: $testFile"
}

if (-not (Test-Path (Join-Path $root "docker-compose.yml"))) {
    throw "Khong tim thay docker-compose.yml trong: $root"
}

# Tao thu muc reports
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

Push-Location $root

try {
    # Kiem tra Docker
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Khong tim thay Docker. Hay mo Docker Desktop."
    }

    # Buoc 1: Build Backend
    Write-Host "[1/4] Building Backend image..." -ForegroundColor Cyan

    docker compose build api

    if ($LASTEXITCODE -ne 0) {
        throw "Build Backend that bai."
    }

    # Buoc 2: Khoi dong database test
    Write-Host "[2/4] Starting test database..." -ForegroundColor Cyan

    docker compose --profile test up -d postgres-test

    if ($LASTEXITCODE -ne 0) {
        throw "Khong the khoi dong PostgreSQL test."
    }

    # Cho database san sang
    $dbId = (
        docker compose --profile test ps -q postgres-test |
        Select-Object -First 1
    )

    if (-not $dbId) {
        throw "Khong tim thay container postgres-test."
    }

    $healthy = $false

    for ($i = 0; $i -lt 30; $i++) {
        $state = (
            docker inspect --format '{{.State.Health.Status}}' $dbId
        ).Trim()

        if ($state -eq "healthy") {
            $healthy = $true
            break
        }

        Start-Sleep -Seconds 2
    }

    if (-not $healthy) {
        throw "PostgreSQL test chua san sang."
    }

    # Buoc 3: Chay 9 Basic Automation Tests
    Write-Host "[3/4] Running Basic Automation Tests..." -ForegroundColor Cyan

    $testUrl = "postgresql+psycopg://banking_test:banking_test_password@postgres-test:5432/banking_test"

    docker compose run --rm --no-deps `
        -v "${testFile}:/code/tests/test_automation_basic.py:ro" `
        -v "${reportDir}:/code/reports" `
        -e PYTHONPATH=/code `
        -e SEED_DEMO_DATA=false `
        -e DATABASE_URL=$testUrl `
        -e TEST_DATABASE_URL=$testUrl `
        api pytest -v -ra tests/test_automation_basic.py `
        --junitxml=/code/reports/automation_basic.xml

    $testExit = $LASTEXITCODE

    # Kiem tra bao cao XML
    $xml = Join-Path $reportDir "automation_basic.xml"

    if (-not (Test-Path $xml)) {
        throw "Khong tim thay bao cao XML sau khi chay test."
    }

    # Buoc 4: Tao bao cao HTML, CSV, Markdown
    Write-Host "[4/4] Generating test reports..." -ForegroundColor Cyan

    $reportScript = Join-Path $PSScriptRoot "generate_report.py"

    if (Get-Command python -ErrorAction SilentlyContinue) {
        python $reportScript $xml
    }
    elseif (Get-Command py -ErrorAction SilentlyContinue) {
        py -3 $reportScript $xml
    }
    else {
        Write-Host "Chua co Python de tao HTML/CSV/MD. XML da duoc luu." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "AUTOMATION TEST FINISHED" -ForegroundColor Green
    Write-Host "Reports: $reportDir" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green

    if ($testExit -ne 0) {
        Write-Host "Co Test Case FAILED hoac ERROR. Hay kiem tra bao cao." -ForegroundColor Yellow
    }
}
finally {
    Pop-Location
}
