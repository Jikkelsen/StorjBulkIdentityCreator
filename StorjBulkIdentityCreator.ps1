<#
   _____ _                 _   _____    _            _   _ _            _____                _
  / ____| |               | | |_   _|  | |          | | (_) |          / ____|              | |
 | (___ | |_ ___  _ __    | |   | |  __| | ___ _ __ | |_ _| |_ _   _  | |     _ __ ___  __ _| |_ ___  _ __
  \___ \| __/ _ \| '__|   | |   | | / _` |/ _ \ '_ \| __| | __| | | | | |    | '__/ _ \/ _` | __/ _ \| '__|
  ____) | || (_) | | | |__| |  _| || (_| |  __/ | | | |_| | |_| |_| | | |____| | |  __/ (_| | || (_) | |
 |_____/ \__\___/|_|  \____/  |_____\__,_|\___|_| |_|\__|_|\__|\__, |  \_____|_|  \___|\__,_|\__\___/|_|
                                                                __/ |
                                                               |___/
#>
#------------------------------------------------| HELP |------------------------------------------------#
<#
    .DESCRIPTION
        This script will take a .csv file as input, and attempt to create Storagenode pairs on it.
    .PARAMETER CSVPath
        Full path to .csv File
            .CSV must have a column named "NAME" and a column named "TOKEN"
            And "DASHBOARDPORT", "EXTERNALPORT", "IP" and "WALLET"
    .PARAMETER WorkingDirectory
        Changes what directory temporary files are downloaded to.
    .PARAMETER SetupCommandsFilePath
        Path to setup commands template file
    .PARAMETER DockerComposeFilePath
        Path To docker compose template file
    .EXAMPLE
        .\StorjBulkIdentityCreator -WorkingDirectory (Get-Location)

#>
#---------------------------------------------| PARAMETERS |---------------------------------------------#
# Set parameters for the script here
param
(
    [Parameter()]
    [System.IO.FileInfo]
    $CSVPath = ".\NodeInfo.csv",

    [Parameter()]
    [System.IO.FileInfo]
    $WorkingDirectory = "$HOME\documents\StorjIdentitycreator",

    [Parameter()]
    [System.IO.FileInfo]
    $SetupCommandsFilePath = ".\TEMPLATE_Setup.commands",

    [Parameter()]
    [System.IO.FileInfo]
    $DockerComposeFilePath = ".\TEMPLATE_docker-compose.yaml"
)


#region------------------------------------------| SETUP |-----------------------------------------------#

# Make sure the template files are present
try
{
    $SetupContents   = get-content -Path $SetupCommandsFilePath
    $ComposeContents = get-content -Path $DockerComposeFilePath
}
catch
{
    Write-host 'Make sure files "TEMPLATE_setup.commands" and "TEMPLATE_docker-compose.yaml" exist'
    throw
}


# Create working directory if not exist
if ($false -eq (Test-Path $WorkingDirectory))
{
    Write-Host 'Creating directory with path "$WorkingDirectory" ... ' -NoNewline
    [Void]::(New-Item -ItemType Directory -Path $WorkingDirectory)
    Write-Host "OK"
}
else
{
    Write-Host "Working directory exists"
}

# Create dump folder for config files
if ($false -eq (Test-Path "$WorkingDirectory\ConfigFiles"))
{
    Write-Host 'Creating directory with path "$WorkingDirectory\ConfigFiles" ... ' -NoNewline
    [Void]::(New-Item -ItemType Directory -Path "$WorkingDirectory\ConfigFiles")
    Write-Host "OK"
}
else
{
    Write-Host "Config dump directory exists"
}

# Get the installation files, if not present already
Write-Host "Forcing the newest installation program"
$ProgramFolderPath = (New-Item -ItemType "Directory" -Path "$WorkingDirectory\InstallationProgram" -Force)

try
{
    # Hide invoke-webrequest progress. It breaks some consoles
    $ProgressPreference = 'SilentlyContinue'

    Write-Host "Downloading installation files ... " -NoNewline
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://github.com/storj/storj/releases/latest/download/identity_windows_amd64.zip" -OutFile "$ProgramFolderPath\identity_windows_amd64.zip" | out-null
    Write-Host "OK"

    Write-Host "Expanding installation files  ... " -NoNewline
    Expand-Archive -path "$ProgramFolderPath\identity_windows_amd64.zip" -DestinationPath "$ProgramFolderPath" -Force | out-null
    Write-Host "OK"

    # No need to hide prefrence from here
    $ProgressPreference = 'Continue'
    Write-Host "" -NoNewline
}
catch
{
    Write-Host "FAIL!"
    Write-Host "Could not get install files"
    throw
}
#endregion


#region-----------------------------------| CREATING IDENTITIES |----------------------------------------#

Write-Host "Beginning idenity creation now"

# Prepare variables for iteration
$CSV     = Import-Csv -Path $CSVPath
$Total   = $CSV.Count
$Counter = 1

$ExternalStopWatch = [system.diagnostics.stopwatch]::startNew()

# Create identities
ForEach ($Row in $CSV)
{
    Write-Host "`n#------| $Counter / $Total : NOW WORKING ON $($Row.NODENAME) |------#"

    # Pull variables from CSV into shorthand variables
    $NodeName   = $Row.NODENAME
    $Token      = $Row.TOKEN

    # Create and authorize the identity
    try
    {
        $StopWatch = [system.diagnostics.stopwatch]::startNew()

        # Generate the key
        Start-Process -NoNewWindow -wait "$ProgramFolderPath\identity.exe" -ArgumentList "create storagenode"

        # authorize identity
        Start-Process -NoNewWindow -wait "$ProgramFolderPath\identity.exe" -ArgumentList "authorize storagenode $Token"
    }
    catch
    {
        #TODO: Somehow handle faults here. I don't know how.
        Throw
    }

    # Check amount is correct
    $CaCheck       = ((Select-String BEGIN "$env:AppData\Storj\identity\storagenode\ca.cert").count)       # should give 2
    $IdentityCheck = ((Select-String BEGIN "$env:AppData\Storj\identity\storagenode\identity.cert").count) # Should give 3
    $StopWatch.Stop()

    # Only continue if files created as expected
    if ($CaCheck -eq 2 -and $IdentityCheck -eq 3)
    {
        $TimeSpent = $StopWatch.Elapsed.Minutes
        $StopWatch.Reset()

        Write-Host ""
        Write-Host "-- Authorized key in $timespent minutes --" -BackgroundColor "Yellow"
        Write-Host ""
        Write-Host "Correct number of files found"

        # Prepare variables
        $Source            = "$env:AppData\Storj\identity\storagenode\"
        $CreateLocation    = "$env:AppData\Storj\identity\$NodeName\"

        try
        {
            # Create folder with name of current iteration, and subfolder "identity"
            Write-Host "Creating target folder ... " -NoNewline
            [void]::(New-Item -name "identity" -Path $CreateLocation -ItemType "Directory" -Force)
            Write-Host "OK"

            # Move files in Storagenode folder to newly created files
            Write-Host "Moving identity to target folder ... " -NoNewline
            [void]::(Get-ChildItem $Source | Move-Item -Destination "$CreateLocation\identity" -Force)
            Write-Host "OK"

            # Put token together with certificates
            Write-Host "Backing up Token used for authorization ... " -NoNewline
            [void]::(New-Item -ItemType "File" -Name "$NodeName - Token.txt" -Value $Token -Path "$CreateLocation\identity" -Force)
            Write-Host "OK"

            # remove old, now empty folder "storagenode" folder
            Write-Host "Removing old work folder ... " -NoNewline
            [void]::(Remove-Item -Path $Source)
            Write-Host "OK"

            Write-Host "Finished creating identity for $NodeName"
        }
        catch
        {
            Write-Host "FAIL!"
            Write-Host "Could not finalize identity. Check for duplicate names"
            Write-host 'The identity is currently in folder: "AppData\Storj\identity\storagenode\"'
            throw
        }


        #region---------------------------------------| DOCKER DATA |--------------------------------------------#

        Write-Host "Attempting to create Docker files for $Nodename"

        # Get additional information from .csv
        $DashBoardPort = $Row.DASHBOARDPORT
        $ExternalPort  = $Row.EXTERNALPORT
        $WalletAddr    = $Row.WALLET
        $IPAddr        = $Row.IP
        $EmailAddr     = ($Row.Token -split ":")[0]

        # Create data directory
        Write-Host "Creating docker directory"
        [void]::(New-Item -ItemType "Directory" -Name "data" -Path $CreateLocation -Force)

        # Create Docker compose
        try
        {
            Write-Host 'Creating "docker-compose.yaml" file ... ' -NoNewline

            # Customize file
            $ComposeContents = $ComposeContents.Replace("YOUR_NODENAME_GOES_HERE" ,$NodeName)
            $ComposeContents = $ComposeContents.Replace("EXTERNAL_PORT_HERE"      ,$ExternalPort)
            $ComposeContents = $ComposeContents.Replace("DASH_BOARD_PORT_HERE"    ,$DashBoardPort)
            $ComposeContents = $ComposeContents.Replace("YOUR_WALLET_GOES_HERE"   ,$WalletAddr)
            $ComposeContents = $ComposeContents.Replace("YOUR_IPADDRESS_GOES_HERE",$IPAddr)
            $ComposeContents = $ComposeContents.Replace("YOUR_EMAIL_GOES_HERE"    ,$EmailAddr)
            $Filename        = "Docker-Compose.yaml"

            # Create file
            [void]::(New-Item -ItemType "File" -name $Filename -Path $CreateLocation -Force)
            [void]::(Add-Content -Path "$CreateLocation\Docker-Compose.yaml" -Value $ComposeContents)
            Write-Host "OK"
        }
        catch
        {
            Write-host "Could not find compose files"
        }

        # Create Docker Run commands
        try
        {
            Write-Host 'Creating "setup.commands" file ... ' -NoNewline
            $SetupContents = $SetupContents.Replace("YOUR_NODENAME_GOES_HERE",$NodeName)
            $Filename      = "setup.commands"
            [void]::(New-Item -ItemType "File" -name $Filename -Path $CreateLocation -Force)
            [void]::(Add-Content -Path "$CreateLocation\$Filename" -Value $SetupContents)
            Write-Host "OK"
        }
        catch
        {
            Write-host "Could not find setup commands"
        }
        #endregion------------------------------------| DOCKER END |---------------------------------------------#


        # And finally back up the entire thing to destination folder
        [void]::(Copy-Item -LiteralPath $CreateLocation -Recurse -Destination $WorkingDirectory)

    }
    else
    {
        Write-Host "Authorization failed!"
        throw
    }

    $Counter++
}
#endregion


#region-----------------------------------| CLEANUP AND BACKUP |-----------------------------------------#

$ExternalStopWatch.Stop()
Write-Host "`n#------| Node Generation completed: Backing up |------#"

# Tell user about total time
$TimeSpentNew = $ExternalStopWatch.Elapsed.Minutes
$ExternalStopWatch.Reset()

Write-Host "Authorized all keys in $timespentNew minutes"

# Backup config files
$Date = Get-Date -Format "yyyy-MM-dd"
$Item = Get-Item $CSVPath
$DumpPath = "$WorkingDirectory\ConfigFiles\$Date"

# Create directory with date if not exists
if ($false -eq (Test-Path $DumpPath))
{
    $DumpDirectory = New-Item -ItemType "Directory" -Path $DumpPath
}
else
{
    $DumpDirectory = Get-Item -Path $DumpPath
}

# Copy over the CSV with values from run
Copy-item -Path $CSVPath -Destination "$DumpDirectory\$($Item.Name)"

# Copy over docker related files
Get-Item $SetupCommandsFilePath | Copy-Item -Destination "$DumpDirectory\$($SetupContents.name)"   -Force
Get-Item $DockerComposeFilePath | Copy-Item -Destination "$DumpDirectory\$($ComposeContents.name)" -Force



Write-Host "No opening Working directory: $WorkingDirectory"
explorer.exe $WorkingDirectory
#endregion
