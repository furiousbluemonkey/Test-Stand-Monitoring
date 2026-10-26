param(
    [Parameter(Mandatory = $true)] [string] $GrafanaHome
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$GrafanaHome = (Resolve-Path $GrafanaHome).Path
$Exe = Join-Path $GrafanaHome 'bin\grafana.exe'
if (!(Test-Path $Exe)) { throw "Grafana executable not found at $Exe. Extract the official Grafana Windows standalone archive, and pass the directory containing bin and conf." }
$Provision = Join-Path $GrafanaHome 'conf\provisioning'
$PluginDir = Join-Path $GrafanaHome 'data\plugins'
New-Item -ItemType Directory -Force -Path $PluginDir, (Join-Path $Provision 'dashboards'), (Join-Path $Provision 'datasources') | Out-Null
if (!(Test-Path (Join-Path $PluginDir 'yesoreyeram-infinity-datasource\plugin.json'))) {
    & $Exe cli --homepath $GrafanaHome --pluginsDir $PluginDir plugins install yesoreyeram-infinity-datasource
    if ($LASTEXITCODE -ne 0) { throw "Infinity installation failed (exit $LASTEXITCODE)" }
}
Copy-Item (Join-Path $Root 'grafana\provisioning\datasources\infinity.yaml') (Join-Path $Provision 'datasources\logger-infinity.yaml') -Force
$Template = Get-Content (Join-Path $Root 'grafana\provisioning\dashboards\dashboards.yaml') -Raw
$DashPath = ((Join-Path $Root 'grafana\dashboards') -replace '\\','/').Replace("'", "''")
$Template = [regex]::Replace($Template, '(?m)^\s*path:\s*.*$', "      path: '$DashPath'")
Set-Content -Path (Join-Path $Provision 'dashboards\logger-dashboard.yaml') -Value $Template -Encoding utf8
Write-Host 'Provisioning completed. Start Grafana with:'
Write-Host "  Set-Location '$GrafanaHome'"
Write-Host '  .\bin\grafana.exe server --homepath .'
Write-Host 'Then visit http://localhost:3000/d/adkpsps'
