$actionsRun = $false
$maxRetries = 6
$retryDelay = 10

function Invoke-WithRetry {
    param(
        [scriptblock]$Command,
        [string]$Description
    )

    for ($i = 1; $i -le $maxRetries; $i++) {
        $output = & $Command 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Output $output
            return
        }

        if ($i -lt $maxRetries -and ($output -match "Forbidden" -or $output -match "ForbiddenByRbac")) {
            Write-Host "  Waiting for RBAC propagation (attempt $i/$maxRetries)..."
            Start-Sleep -Seconds $retryDelay
        }
        else {
            throw "Failed: $Description`n$output"
        }
    }
}

function Assert-FileExists {
    param(
        [string]$Path,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description was not found at '$Path'."
    }
}

function Assert-AzResult {
    param(
        [string]$Value,
        [string]$Description
    )

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Value)) {
        throw "Failed: $Description"
    }
}

if ($env:WORK_ITEM_BACKEND -like "*GitHub*") {
    if ([string]::IsNullOrEmpty($env:GITHUB_PRIVATE_KEY_ID) -or [string]::IsNullOrEmpty($env:GITHUB_PRIVATE_KEY_PATH)) {
        Write-Host "GitHub App auth not configured, skipping key upload."
    }
    else {
        $keyPath = Join-Path $PWD $env:GITHUB_PRIVATE_KEY_PATH
        Assert-FileExists -Path $keyPath -Description "GitHub private key"

        $kvId = az keyvault show --name $env:AZURE_KEY_VAULT_NAME --query id -o tsv
        Assert-AzResult -Value $kvId -Description "Getting Key Vault '$env:AZURE_KEY_VAULT_NAME'"

        Write-Host "Uploading GitHub private key: $keyPath"

        $userId = az ad signed-in-user show --query id -o tsv
        Assert-AzResult -Value $userId -Description "Getting the signed-in Azure user"

        $assignment = az role assignment create `
            --role "Key Vault Crypto Officer" `
            --assignee $userId `
            --scope $kvId `
            --query id -o tsv
        Assert-AzResult -Value $assignment -Description "Assigning Key Vault Crypto Officer"

        try {
            Invoke-WithRetry -Description "GitHub key import" -Command {
                az keyvault key import --name $env:GITHUB_PRIVATE_KEY_ID --pem-file $keyPath --vault-name $env:AZURE_KEY_VAULT_NAME
            }
            $actionsRun = $true
        }
        finally {
            az role assignment delete --ids $assignment
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to remove temporary role assignment '$assignment'."
            }
        }
    }
}

if ($env:WORK_ITEM_BACKEND -like "*AzureDevOps*") {
    if ([string]::IsNullOrEmpty($env:ADO_CERTIFICATE_ID) -or [string]::IsNullOrEmpty($env:ADO_CERTIFICATE_PATH)) {
        Write-Host "Azure DevOps certificate auth not configured, skipping certificate upload."
    }
    else {
        $certPath = Join-Path $PWD $env:ADO_CERTIFICATE_PATH
        Assert-FileExists -Path $certPath -Description "Azure DevOps certificate"

        $kvId = az keyvault show --name $env:AZURE_KEY_VAULT_NAME --query id -o tsv
        Assert-AzResult -Value $kvId -Description "Getting Key Vault '$env:AZURE_KEY_VAULT_NAME'"

        Write-Host "Uploading ADO certificate: $certPath"

        $userId = az ad signed-in-user show --query id -o tsv
        Assert-AzResult -Value $userId -Description "Getting the signed-in Azure user"

        $assignment = az role assignment create `
            --role "Key Vault Certificates Officer" `
            --assignee $userId `
            --scope $kvId `
            --query id -o tsv
        Assert-AzResult -Value $assignment -Description "Assigning Key Vault Certificates Officer"

        try {
            Invoke-WithRetry -Description "ADO certificate import" -Command {
                az keyvault certificate import --name $env:ADO_CERTIFICATE_ID --file $certPath --vault-name $env:AZURE_KEY_VAULT_NAME
            }
            $actionsRun = $true
        }
        finally {
            az role assignment delete --ids $assignment
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to remove temporary role assignment '$assignment'."
            }
        }
    }
}

if (-not [string]::IsNullOrEmpty($env:POWERBI_CERTIFICATE_ID) -and -not [string]::IsNullOrEmpty($env:POWERBI_CERTIFICATE_PATH)) {
    $certPath = Join-Path $PWD $env:POWERBI_CERTIFICATE_PATH
    Assert-FileExists -Path $certPath -Description "Power BI certificate"

    $kvId = az keyvault show --name $env:AZURE_KEY_VAULT_NAME --query id -o tsv
    Assert-AzResult -Value $kvId -Description "Getting Key Vault '$env:AZURE_KEY_VAULT_NAME'"

    Write-Host "Uploading PowerBI certificate: $certPath"

    $userId = az ad signed-in-user show --query id -o tsv
    Assert-AzResult -Value $userId -Description "Getting the signed-in Azure user"

    $assignment = az role assignment create `
        --role "Key Vault Certificates Officer" `
        --assignee $userId `
        --scope $kvId `
        --query id -o tsv
    Assert-AzResult -Value $assignment -Description "Assigning Key Vault Certificates Officer"

    try {
        Invoke-WithRetry -Description "PowerBI certificate import" -Command {
            az keyvault certificate import --name $env:POWERBI_CERTIFICATE_ID --file $certPath --vault-name $env:AZURE_KEY_VAULT_NAME
        }
        $actionsRun = $true
    }
    finally {
        az role assignment delete --ids $assignment
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to remove temporary role assignment '$assignment'."
        }
    }
}

if (-not $actionsRun) {
    Write-Host "No post-provision actions required."
}