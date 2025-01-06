Clear-Host

#region Variables


# Theme variables

$ohMyPoshTheme = "lambdageneration"
$previousTheme = "montys"
$themePattern = 'ohMyPoshTheme\s*=\s*"([^"]*)"'
$previousPattern = 'previousTheme\s*=\s*"([^"]*)"'

#endregion

#region Dependency Variables

$requiredModules = @('PSReadLine')

#endregion
#endregion

#region Functions

function Get-OhMyPoshInstallCommand {
    switch ($true) {
        $IsWindows {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                return "winget install oh-my-posh"
            }
            else {
                throw "Winget is required for Windows installation"
            }
        }
        $IsMacOS {
            if (Get-Command brew -ErrorAction SilentlyContinue) {
                return "brew install oh-my-posh"
            }
            else {
                throw "Homebrew is required for Mac installation"
            }
        }
        $IsLinux {
            return "Install-Module -Name oh-my-posh -Scope CurrentUser -Force -AllowClobber"
        }
        default {
            return $null
        }
    }
}

#region Font Functions

<#
    TODO: Implement a checker to see which VScode version is installed and set the font accordingly (VScode insider, stable, etc.)
#>
function Set-VSCodeFont {
    [CmdletBinding()]
    param (
        [Parameter()]
        [TypeName('System.String')]
        $font = '0xProto Nerd Font' # Default font for my profile currently
    )
    $vsCodeSettingsPath = ""

}

<#
    TODO: Implement a way for users to easily add their terminal and way to get the font from that terminal application,
    as accounting for all terminal applications is not feasible.
    TODO: Implement a way to set a font for the terminal application
#>
function Get-CurrentTerminalFont {

    #check for the current OS

    #check for the current terminal application
    
    $windowsTerminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

    return $fonts
}

#endregion

#region Theme Functions

function Set-OhMyPoshTheme {
    <#
    .SYNOPSIS
        Sets Oh-My-Posh theme and manages theme history.
    .DESCRIPTION
        Changes the current Oh-My-Posh theme and stores the previous theme for potential reversion.
    .PARAMETER Theme
        The name of the Oh-My-Posh theme to apply (without .omp.json extension)
    .PARAMETER ProfilePath
        Path to the PowerShell profile file
    .PARAMETER Revert
        Switch to revert to the previous theme
    .EXAMPLE
        Set-OhMyPoshTheme -Theme powerlevel10k_lean
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Theme = 'powerlevel10k_lean',

        [Parameter()]
        [ValidateScript({ Test-Path $_ -IsValid })]
        [string]
        $ProfilePath = $PROFILE.AllUsersAllHosts,

        [Parameter()]
        [switch]
        $Revert
    )

    process {
        try {
            if ($Revert) {
                Write-Verbose "Reverting theme change"
                $result = Undo-OhMyPoshThemeSelection -ProfilePath $ProfilePath
                return $result
            }

            $themePath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Programs\oh-my-posh\themes\$Theme.omp.json"
            if (-not (Test-Path $themePath)) {
                throw "Theme not found: $Theme"
            }

            Write-Verbose "Reading profile content from $ProfilePath"
            $profileContent = Get-Content $ProfilePath -Raw

            $currentTheme = [regex]::Match($profileContent, $themePattern).Groups[1].Value
            if ([string]::IsNullOrEmpty($currentTheme)) {
                throw "Could not find current theme in profile"
            }

            Write-Verbose "Updating theme from '$currentTheme' to '$Theme'"
            
            $profileContent = $profileContent -replace $previousPattern, "previousTheme = `"$currentTheme`""
            $profileContent = $profileContent -replace $themePattern, "ohMyPoshTheme = `"$Theme`""

            Set-Content -Path $ProfilePath -Value $profileContent
            Write-Verbose "Theme updated successfully"
            
            return @{
                PreviousTheme = $currentTheme
                CurrentTheme  = $Theme
                Success       = $true
            }
        }
        catch {
            Write-Error "Failed to set theme: $_"
            return $null
        }
    } end {
        Invoke-ProfileReload -ProfilePath $ProfilePath
    }
}

function Undo-OhMyPoshThemeSelection {
    <#
    .SYNOPSIS
        Reverts Oh-My-Posh theme to previous selection.
    .DESCRIPTION
        Restores the previously used Oh-My-Posh theme from profile configuration.
    .PARAMETER ProfilePath
        Path to the PowerShell profile file.
    .EXAMPLE
        Undo-OhMyPoshThemeSelection
    .EXAMPLE
        Undo-OhMyPoshThemeSelection -ProfilePath $PROFILE.CurrentUserAllHosts
    .OUTPUTS
        PSCustomObject with PreviousTheme, CurrentTheme and Success properties
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateScript({ Test-Path $_ -IsValid })]
        [string]
        $ProfilePath = $PROFILE.AllUsersAllHosts
    )

    process {
        try {
            Write-Verbose "Reading profile from $ProfilePath"
            $profileContent = Get-Content $ProfilePath -Raw
            
            $currentTheme = [regex]::Match($profileContent, $themePattern).Groups[1].Value
            $previousTheme = [regex]::Match($profileContent, $previousPattern).Groups[1].Value

            if ([string]::IsNullOrEmpty($previousTheme)) {
                Write-Warning "No previous theme found to revert to"
                return $false
            }

            if ([string]::IsNullOrEmpty($currentTheme)) {
                Write-Warning "Current theme not found in profile"
                return $false
            }

            Write-Verbose "Reverting from '$currentTheme' to '$previousTheme'"
            $profileContent = $profileContent -replace $themePattern, "ohMyPoshTheme = `"$previousTheme`""
            
            Set-Content -Path $ProfilePath -Value $profileContent -Force
            Write-Host "Theme has been reverted to $previousTheme"

            return @{
                PreviousTheme = $currentTheme
                CurrentTheme  = $previousTheme
                Success       = $true
            }
        }
        catch {
            Write-Error "Failed to revert theme: $_"
            return $null
        }
    }

    end {
        Write-Verbose "Theme reversion operation completed"
        Invoke-ProfileReload -ProfilePath $ProfilePath
    }
}

function Invoke-ProfileReload {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateScript({ Test-Path $_ -IsValid })]
        [string]
        $ProfilePath = $PROFILE.AllUsersAllHosts
    )

    try {
        Write-Verbose "Reloading profile: $ProfilePath"
        . $ProfilePath
    }
    catch {
        Write-Error "Failed to reload profile: $_"
    }
}

#endregion
#endregion

#region Dependencies

try {
    $ohMyPoshInstalled = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    if (-not $ohMyPoshInstalled) {
        $installCommand = Get-OhMyPoshInstallCommand
        if (-not $installCommand) {
            throw "Unsupported operating system"
        }

        Write-Host "Oh-My-Posh is not installed. The following command will be executed:" -ForegroundColor Yellow
        Write-Host $installCommand -ForegroundColor Cyan
        $confirmation = Read-Host "Do you want to proceed with the installation? (Y/N)"

        if ($confirmation -eq 'Y') {
            Write-Host "Installing Oh-My-Posh..." -ForegroundColor Green
            switch ($true) {
                $IsWindows {
                    $result = Invoke-Expression $installCommand
                    if ($LASTEXITCODE -ne 0) { throw "Failed to install Oh-My-Posh via winget" }
                }
                $IsMacOS {
                    if (Get-Command brew -ErrorAction SilentlyContinue) {
                        $result = Invoke-Expression $installCommand
                        if ($LASTEXITCODE -ne 0) { throw "Failed to install Oh-My-Posh via brew" }
                    }
                    else {
                        throw "Homebrew is required for Mac installation"
                    }
                }
                $IsLinux {
                    $result = Invoke-Expression $installCommand
                    if ($LASTEXITCODE -ne 0) { throw "Failed to install Oh-My-Posh on Linux" }
                }
            }
            Write-Host "Oh-My-Posh installed successfully!" -ForegroundColor Green
        }
        else {
            Write-Warning "Oh-My-Posh installation was skipped by user"
        }
    }
}
catch {
    Write-Warning "Failed to install Oh-My-Posh: $_"
}

foreach ($module in $requiredModules) {
    try {
        if (-not (Get-Module -Name $module -ListAvailable)) {
            Write-Host "Installing module: $module"
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
        }
        else {
            $installed = Get-Module -Name $module -ListAvailable
            Write-Verbose "Module $module version $($installed.Version) is already installed"
        }
    }
    catch {
        Write-Warning "Failed to install module $module : $_"
    }
}

$missingDeps = @()
foreach ($module in $requiredModules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        $missingDeps += $module
    }
}

if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    $missingDeps += "oh-my-posh"
}

if ($missingDeps) {
    Write-Warning "The following dependencies are missing: $($missingDeps -join ', ')"
}

#endregion

#region PSReadline Setup

try {
    # History search and navigation
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
        
    # Vi mode configuration
    Set-PSReadLineOption -EditMode Vi
        
    # Prediction and suggestion settings
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -HistoryNoDuplicates
        
    # Sound settings
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineOption -DingTone 0
        
    Write-Verbose "PSReadLine configured successfully"
}
catch {
    Write-Warning "Failed to configure PSReadLine: $_"
}

#endregion

#region Oh-My-Posh Initialization

try {
    $themePath = Join-Path $env:LOCALAPPDATA "Programs\oh-my-posh\themes\$ohMyPoshTheme.omp.json"
    if (-not (Test-Path $themePath)) {
        throw "Theme not found: $themePath, please use Set-OhMyPoshTheme to select a valid theme"
    }
    
    $initScript = (oh-my-posh init pwsh --config $themePath) -join "`n"
    Invoke-Expression $initScript
    
    Write-Verbose "Oh-My-Posh initialized with theme: $ohMyPoshTheme"
}
catch {
    Write-Warning "Failed to initialize Oh-My-Posh: $_"
}

#endregion




