#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive sandbox for the ScalePad Lifecycle Manager API.

.DESCRIPTION
    A menu-driven PowerShell tool that demonstrates core ScalePad API operations:
    listing clients, creating and managing initiatives (with one-time and recurring
    budgets), and scheduling meetings. Built as a learning recipe for the ScalePad
    public API.

.NOTES
    This recipe does not handle cursor-based pagination. If your account has more
    records than a single page returns, only the first page will be shown.

.LINK
    https://developer.scalepad.com
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Configuration ─────────────────────────────────────────────

$script:CoreBaseUri = "https://api.scalepad.com/core/v1"
$script:LmBaseUri   = "https://api.scalepad.com/lifecycle-manager/v1"
$script:LmBaseUriV2 = "https://api.scalepad.com/lifecycle-manager/v2"
$script:ApiKey      = ""

# ── UI Helpers ────────────────────────────────────────────────

function Show-Header([string]$Title) {
    Clear-Host
    Write-Host "  +------------------------------------------------------+"
    Write-Host ("  | {0,-52} |" -f $Title)
    Write-Host "  +------------------------------------------------------+"
    Write-Host ""
}

function Show-Box([string]$Heading, [string[]]$Lines) {
    $w = 58
    Write-Host ("  +" + ("-" * $w) + "+")
    Write-Host ("  | " + $Heading.PadRight($w - 1) + "|")
    Write-Host ("  +" + ("-" * $w) + "+")
    foreach ($line in $Lines) {
        $s = [string]$line
        if ($s.Length -gt ($w - 1)) { $s = $s.Substring(0, $w - 4) + "..." }
        Write-Host ("  | " + $s.PadRight($w - 1) + "|")
    }
    Write-Host ("  +" + ("-" * $w) + "+")
    Write-Host ""
}

function Wait-ForEnter {
    Write-Host ""
    Write-Host "  Press ENTER to continue..." -ForegroundColor DarkGray
    [void](Read-Host)
}

function Read-MenuChoice([string]$Prompt, [int[]]$ValidChoices) {
    while ($true) {
        $raw = Read-Host ("  {0}" -f $Prompt)
        if ($raw -match '^\d+$') {
            $n = [int]$raw
            if ($ValidChoices -contains $n) { return $n }
        }
        Write-Host "  Invalid choice. Try again." -ForegroundColor Yellow
    }
}

# ── API Layer ─────────────────────────────────────────────────

function Assert-ApiKey {
    if ([string]::IsNullOrWhiteSpace($script:ApiKey)) {
        Show-Box "API KEY" @(
            "Enter your ScalePad API key below.",
            "The key is stored in memory for this session only."
        )
        $script:ApiKey = Read-Host "  API Key"
        Write-Host ""
    }
}

function Invoke-ScalePadApi {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Get", "Post", "Put", "Delete")]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Uri,

        [object]$Body
    )

    Assert-ApiKey

    $headers = @{
        Accept      = "application/json"
        "x-api-key" = $script:ApiKey
    }

    $splat = @{
        Method  = $Method
        Uri     = $Uri
        Headers = $headers
    }

    if ($PSBoundParameters.ContainsKey("Body")) {
        $headers["Content-Type"] = "application/json"
        $splat.Body = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 10 }
    }

    Invoke-RestMethod @splat
}

# ── Data Fetchers ─────────────────────────────────────────────

function Get-Clients {
    $response = Invoke-ScalePadApi -Method Get -Uri "$script:CoreBaseUri/clients"
    if ($response -and $response.data) { return @($response.data) }
    return @()
}

function Get-Initiatives {
    $response = Invoke-ScalePadApi -Method Get -Uri "$script:LmBaseUri/initiatives"
    if ($response -and $response.data) { return @($response.data) }
    return @()
}

function Get-Meetings {
    $response = Invoke-ScalePadApi -Method Get -Uri "$script:LmBaseUri/meetings"
    if ($response -and $response.data) { return @($response.data) }
    return @()
}

# ── Sample Data (loaded from samples.json) ────────────────────

$script:SamplesPath = Join-Path $PSScriptRoot "samples.json"
if (-not (Test-Path $script:SamplesPath)) {
    Write-Host "  ERROR: samples.json not found next to script." -ForegroundColor Red
    Write-Host "  Expected path: $script:SamplesPath" -ForegroundColor Red
    exit 1
}
$script:Samples           = Get-Content -Path $script:SamplesPath -Raw | ConvertFrom-Json
$script:InitiativeCatalog = @($script:Samples.initiatives)
$script:MeetingCatalog    = @($script:Samples.meetings)

# ── Initiative Budget Helpers ─────────────────────────────────

function Update-InitiativeBudget([string]$InitiativeId, $Fixed) {
    $payload = @{
        budget_line_items = @(
            @{
                cost_type     = "Fixed"
                label         = $Fixed.label
                cost_subunits = [int]$Fixed.cost_subunits
            }
        )
    }
    Invoke-ScalePadApi -Method Put `
        -Uri "$script:LmBaseUri/initiatives/$InitiativeId/budget" `
        -Body $payload
}

function Update-InitiativeRecurring([string]$InitiativeId, $Recurring) {
    $payload = @{
        recurring_line_items = @(
            @{
                label         = $Recurring.label
                cost_subunits = [int]$Recurring.cost_subunits
                cost_type     = "Fixed"
                frequency     = $Recurring.frequency
            }
        )
    }
    Invoke-ScalePadApi -Method Put `
        -Uri "$script:LmBaseUri/initiatives/$InitiativeId/recurring" `
        -Body $payload
}

# ── Meeting Payload Builder ───────────────────────────────────

function New-MeetingPayload([string]$ClientId, $Template) {
    $startTime = (Get-Date).AddDays(7).Date.AddHours(10)
    $endTime   = $startTime.AddHours(1)

    $agendaJson = @{
        type    = "doc"
        content = @(
            @{
                type    = "paragraph"
                attrs   = @{ textAlign = $null }
                content = @( @{ type = "text"; text = $Template.Agenda } )
            }
        )
    } | ConvertTo-Json -Depth 10 -Compress

    return @{
        client_key  = @{ id = $ClientId }
        title       = $Template.Title
        starts_at   = $startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        ends_at     = $endTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        agenda_json = $agendaJson
    }
}

# ── Clients Module ────────────────────────────────────────────

function Show-ClientList {
    Show-Header "Clients > List"
    Show-Box "Calling API" @(
        "GET /core/v1/clients",
        "Returns: Client ID, Name, Lifecycle status"
    )

    try {
        $clients = Get-Clients
        if ($clients.Count -eq 0) {
            Write-Host "  No clients returned by the API." -ForegroundColor Yellow
            Wait-ForEnter; return
        }

        Write-Host "  $($clients.Count) client(s) found." -ForegroundColor Green
        Write-Host ""

        $table = $clients |
            Select-Object `
                @{N="Client ID";   E={$_.id}},
                @{N="Client Name"; E={$_.name}},
                @{N="Lifecycle";   E={$_.lifecycle}} |
            Sort-Object "Client Name" |
            Format-Table -AutoSize | Out-String

        Write-Host $table -ForegroundColor Green
        Wait-ForEnter
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Wait-ForEnter
    }
}

function Show-ClientMenu {
    while ($true) {
        Show-Header "Clients"
        Show-Box "CLIENTS" @(
            "1. List clients",
            "2. Back"
        )
        $c = Read-MenuChoice "Clients> " @(1,2)
        if ($c -eq 1) { Show-ClientList }
        if ($c -eq 2) { return }
    }
}

# ── Initiatives Module ────────────────────────────────────────

function Show-InitiativeList {
    Show-Header "Initiatives > List"
    Show-Box "Calling API" @(
        "GET /core/v1/clients",
        "GET /lifecycle-manager/v1/initiatives",
        "Returns: Client, Initiative, ID, Status"
    )

    try {
        $clients     = Get-Clients
        $initiatives = Get-Initiatives

        if ($clients.Count -eq 0) {
            Write-Host "  No clients returned by the API." -ForegroundColor Yellow
            Wait-ForEnter; return
        }

        $map = @{}
        foreach ($init in $initiatives) {
            $cid = [string]$init.client.id
            if ([string]::IsNullOrWhiteSpace($cid)) { continue }
            if (-not $map.ContainsKey($cid)) { $map[$cid] = @() }
            $map[$cid] += [pscustomobject]@{
                Name   = $init.name
                Id     = $init.id
                Status = $init.status
            }
        }

        $rows = @()
        foreach ($c in ($clients | Sort-Object name)) {
            $cid  = [string]$c.id
            $list = $map[$cid]

            if (-not $list) {
                $rows += [pscustomobject]@{
                    "Client"        = $c.name
                    "Initiative"    = ""
                    "Initiative ID" = ""
                    "Status"        = ""
                }
            }
            else {
                for ($k = 0; $k -lt $list.Count; $k++) {
                    $rows += [pscustomobject]@{
                        "Client"        = $(if ($k -eq 0) { $c.name } else { "" })
                        "Initiative"    = $list[$k].Name
                        "Initiative ID" = $list[$k].Id
                        "Status"        = $list[$k].Status
                    }
                }
            }
        }

        $table = $rows | Format-Table -AutoSize | Out-String
        Write-Host $table -ForegroundColor Green
        Wait-ForEnter
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Wait-ForEnter
    }
}

function New-Initiative {
    Show-Header "Initiatives > Create"
    Show-Box "Create Flow" @(
        "1) Pick a client (or ALL clients)",
        "2) Pick a sample initiative",
        "3) POST the initiative",
        "4) Optionally PUT budget + recurring"
    )

    try {
        $clients = Get-Clients
        if ($clients.Count -eq 0) {
            Write-Host "  No clients returned by the API." -ForegroundColor Yellow
            Wait-ForEnter; return
        }

        $applyFees = (Read-Host "  Apply budget + recurring investments? (Y/N)").Trim().ToUpper() -eq "Y"
        Write-Host ""

        Write-Host "  Choose client scope:" -ForegroundColor Cyan
        Write-Host "  0. ALL clients"
        $sorted = @($clients | Sort-Object name)
        for ($i = 0; $i -lt $sorted.Count; $i++) {
            Write-Host ("  {0}. {1}" -f ($i + 1), $sorted[$i].name)
        }

        $pick = Read-MenuChoice "Client#> " (@(0) + @(1..$sorted.Count))
        $targets = if ($pick -eq 0) { $sorted } else { @($sorted[$pick - 1]) }

        Write-Host ""
        Write-Host "  Choose an initiative:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $script:InitiativeCatalog.Count; $i++) {
            Write-Host ("  {0}. {1}" -f ($i + 1), $script:InitiativeCatalog[$i].Name)
        }

        $initPick = Read-MenuChoice "Initiative#> " (1..$script:InitiativeCatalog.Count)
        $template = $script:InitiativeCatalog[$initPick - 1]

        Write-Host ""
        Write-Host ("  Creating '{0}' for {1} client(s)..." -f $template.Name, $targets.Count) -ForegroundColor Green
        Write-Host ""

        $results = @()

        foreach ($c in $targets) {
            $payload = @{
                client_key        = @{ id = [string]$c.id }
                name              = $template.Name
                executive_summary = $template.Summary
            }

            $newId        = ""
            $createStatus = "OK"
            $budgetStatus = "SKIPPED"
            $recurStatus  = "SKIPPED"

            try {
                $created = Invoke-ScalePadApi -Method Post `
                    -Uri "$script:LmBaseUri/initiatives" -Body $payload
                $newId = [string]$created.id

                if ($applyFees -and -not [string]::IsNullOrWhiteSpace($newId)) {
                    try {
                        [void](Update-InitiativeBudget $newId $template.Budget)
                        $budgetStatus = "OK"
                    } catch { $budgetStatus = "ERROR: $($_.Exception.Message)" }

                    try {
                        [void](Update-InitiativeRecurring $newId $template.Recurring)
                        $recurStatus = "OK"
                    } catch { $recurStatus = "ERROR: $($_.Exception.Message)" }
                }
            }
            catch {
                $createStatus = "ERROR: $($_.Exception.Message)"
            }

            $results += [pscustomobject]@{
                "Client"    = $c.name
                "Initiative"= $template.Name
                "ID"        = $newId
                "Create"    = $createStatus
                "Budget"    = $budgetStatus
                "Recurring" = $recurStatus
            }
        }

        $table = $results | Format-Table -AutoSize | Out-String
        Write-Host $table -ForegroundColor Green
        Wait-ForEnter
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Wait-ForEnter
    }
}

function Remove-Initiative {
    Show-Header "Initiatives > Delete"
    Show-Box "Delete Flow" @(
        "1) Search initiatives by name (partial match)",
        "2) Pick which matches to delete",
        "3) DELETE /lifecycle-manager/v1/initiatives/{id}"
    )

    try {
        $initiatives = Get-Initiatives

        if ($initiatives.Count -eq 0) {
            Write-Host "  No initiatives found." -ForegroundColor Yellow
            Wait-ForEnter; return
        }

        $query = Read-Host "  Initiative name (or partial)"
        if ([string]::IsNullOrWhiteSpace($query)) {
            Write-Host "  No input provided." -ForegroundColor Yellow
            Wait-ForEnter; return
        }

        $found = @()
        foreach ($init in $initiatives) {
            if ($init.name -like "*$query*") {
                $found += [pscustomobject]@{
                    InitiativeId = [string]$init.id
                    Initiative   = [string]$init.name
                    ClientName   = [string]$init.client.label
                }
            }
        }

        if ($found.Count -eq 0) {
            Write-Host "  No initiatives matched '$query'." -ForegroundColor Yellow
            Wait-ForEnter; return
        }

        Show-Header "Initiatives > Delete (Matches)"
        Write-Host "  Matches:" -ForegroundColor Green
        Write-Host ""

        for ($i = 0; $i -lt $found.Count; $i++) {
            $m = $found[$i]
            Write-Host ("  {0}. {1}  |  {2}  |  {3}" -f `
                ($i + 1), $m.Initiative, $m.ClientName, $m.InitiativeId) -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "  Enter numbers (e.g. 1,3,4), 'A' for ALL, or 0 to cancel." -ForegroundColor Cyan
        $selRaw = (Read-Host "  Delete> ").Trim()

        if ($selRaw -match '^\s*0\s*$') {
            Write-Host "  Cancelled." -ForegroundColor Yellow
            Wait-ForEnter; return
        }

        $toDelete = @()

        if ($selRaw -match '^\s*[aA]\s*$') {
            $confirm = Read-Host "  Type DELETE to confirm deleting ALL matches"
            if ($confirm -ne "DELETE") {
                Write-Host "  Cancelled." -ForegroundColor Yellow
                Wait-ForEnter; return
            }
            $toDelete = $found
        }
        else {
            $nums = @(
                ($selRaw -split '[,\s]+') |
                Where-Object { $_ -match '^\d+$' } |
                ForEach-Object { [int]$_ } |
                Where-Object { $_ -ge 1 -and $_ -le $found.Count } |
                Select-Object -Unique
            )
            if ($nums.Count -eq 0) {
                Write-Host "  No valid selections." -ForegroundColor Yellow
                Wait-ForEnter; return
            }
            $toDelete = @($nums | ForEach-Object { $found[$_ - 1] })
        }

        Show-Header "Initiatives > Delete (Executing)"
        Write-Host ("  Deleting {0} initiative(s)..." -f $toDelete.Count) -ForegroundColor Green
        Write-Host ""

        $results = @()

        foreach ($m in $toDelete) {
            try {
                # ScalePad DELETE requires a non-empty request body
                [void](Invoke-ScalePadApi -Method Delete `
                    -Uri "$script:LmBaseUri/initiatives/$($m.InitiativeId)" `
                    -Body "{}")
                $status = "DELETED"
            }
            catch {
                $status = "ERROR: $($_.Exception.Message)"
            }

            $results += [pscustomobject]@{
                "Initiative"    = $m.Initiative
                "Client"        = $m.ClientName
                "Initiative ID" = $m.InitiativeId
                "Status"        = $status
            }
        }

        $table = $results | Format-Table -AutoSize | Out-String
        Write-Host $table -ForegroundColor Green
        Wait-ForEnter
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Wait-ForEnter
    }
}

function Show-InitiativeMenu {
    while ($true) {
        Show-Header "Initiatives"
        Show-Box "INITIATIVES" @(
            "1. List all initiatives",
            "2. Create initiative",
            "3. Delete initiative (by name)",
            "4. Back"
        )
        $c = Read-MenuChoice "Initiatives> " @(1,2,3,4)
        switch ($c) {
            1 { Show-InitiativeList }
            2 { New-Initiative }
            3 { Remove-Initiative }
            4 { return }
        }
    }
}

# ── Meetings Module ───────────────────────────────────────────

function Show-MeetingList {
    Show-Header "Meetings > List"
    Show-Box "Calling API" @(
        "GET /lifecycle-manager/v1/meetings",
        "Returns: Client, Title, Meeting ID, Scheduled time"
    )

    try {
        $meetings = Get-Meetings

        if ($meetings.Count -eq 0) {
            Write-Host "  No meetings found." -ForegroundColor Yellow
            Wait-ForEnter; return
        }

        $rows = @()
        foreach ($m in ($meetings | Sort-Object starts_at)) {
            $rows += [pscustomobject]@{
                "Client"       = $m.client.label
                "Meeting"      = $m.title
                "Meeting ID"   = $m.id
                "Scheduled At" = $(if ($m.starts_at) { [string]$m.starts_at } else { "" })
            }
        }

        $table = $rows | Format-Table -AutoSize | Out-String
        Write-Host $table -ForegroundColor Green
        Wait-ForEnter
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Wait-ForEnter
    }
}

function New-Meeting {
    Show-Header "Meetings > Create"
    Show-Box "Create Flow" @(
        "1) Pick a client (or ALL clients)",
        "2) Pick a sample meeting",
        "3) POST to /lifecycle-manager/v2/meetings"
    )

    try {
        $clients = Get-Clients
        if ($clients.Count -eq 0) {
            Write-Host "  No clients returned by the API." -ForegroundColor Yellow
            Wait-ForEnter; return
        }

        Write-Host "  Choose client scope:" -ForegroundColor Cyan
        Write-Host "  0. ALL clients"
        $sorted = @($clients | Sort-Object name)
        for ($i = 0; $i -lt $sorted.Count; $i++) {
            Write-Host ("  {0}. {1}" -f ($i + 1), $sorted[$i].name)
        }

        $pick = Read-MenuChoice "Client#> " (@(0) + @(1..$sorted.Count))
        $targets = if ($pick -eq 0) { $sorted } else { @($sorted[$pick - 1]) }

        Write-Host ""
        Write-Host "  Choose a meeting:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $script:MeetingCatalog.Count; $i++) {
            Write-Host ("  {0}. {1}" -f ($i + 1), $script:MeetingCatalog[$i].menu_name)
        }

        $meetPick = Read-MenuChoice "Meeting#> " (1..$script:MeetingCatalog.Count)
        $template = $script:MeetingCatalog[$meetPick - 1]

        Write-Host ""
        Write-Host ("  Creating '{0}' for {1} client(s)..." -f $template.menu_name, $targets.Count) -ForegroundColor Green
        Write-Host ""

        $results = @()

        foreach ($c in $targets) {
            $payload = New-MeetingPayload -ClientId ([string]$c.id) -Template $template

            $newId  = ""
            $status = "OK"

            try {
                $created = Invoke-ScalePadApi -Method Post `
                    -Uri "$script:LmBaseUriV2/meetings" -Body $payload
                $newId = [string]$created.id
            }
            catch {
                $status = "ERROR: $($_.Exception.Message)"
            }

            $results += [pscustomobject]@{
                "Client"     = $c.name
                "Meeting"    = $template.menu_name
                "Created ID" = $newId
                "Status"     = $status
            }
        }

        $table = $results | Format-Table -AutoSize | Out-String
        Write-Host $table -ForegroundColor Green
        Wait-ForEnter
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Wait-ForEnter
    }
}

function Show-MeetingMenu {
    while ($true) {
        Show-Header "Meetings"
        Show-Box "MEETINGS" @(
            "1. List meetings",
            "2. Create meeting",
            "3. Back"
        )
        $c = Read-MenuChoice "Meetings> " @(1,2,3)
        switch ($c) {
            1 { Show-MeetingList }
            2 { New-Meeting }
            3 { return }
        }
    }
}

# ── Main Menu ─────────────────────────────────────────────────

function Start-Sandbox {
    while ($true) {
        Show-Header "ScalePad API Sandbox"
        Show-Box "MAIN MENU" @(
            "Explore the ScalePad API interactively.",
            "",
            "1. Clients",
            "2. Initiatives",
            "3. Meetings",
            "4. Exit"
        )

        $c = Read-MenuChoice "Main> " @(1,2,3,4)
        switch ($c) {
            1 { Show-ClientMenu }
            2 { Show-InitiativeMenu }
            3 { Show-MeetingMenu }
            4 { return }
        }
    }
}

Start-Sandbox
