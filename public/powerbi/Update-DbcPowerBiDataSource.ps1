<#
.SYNOPSIS
Converts Pester results and exports file in required format for launching the
Power BI command. **You will need refresh* the Power BI dashboard every time to
see the new results.

.DESCRIPTION
Converts Pester results and exports file in required format for launching the
Power BI command. **You will need refresh* the Power BI dashboard every time to
see the new results.

Basically, it does this:
$InputObject.TestResult | Select-Object -First 20 | ConvertTo-Json -Depth 3 | Out-File "$env:windir\temp\dbadisa.json"

.PARAMETER InputObject
Required. Resultset from Invoke-DbsCheck. If InputObject is not provided, it will be generated using a very generic resultset:

.PARAMETER Path
The directory to store your JSON files. "C:\windows\temp\dbadisa\*.json" by default

.PARAMETER FileName
if you want to give the file a specific name

.PARAMETER Environment
A Name to give your suite of tests IE Prod - This will also alter the name of the file

.PARAMETER Force
Delete all json files in the data source folder.

.PARAMETER Append
Appends results to existing file. Use this if you have custom check repos

.PARAMETER EnableException
By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

.EXAMPLE
Invoke-DbsCheck -SqlInstance $Instance -Check DatabaseStatus -Show None -PassThru | Update-DbsPowerBiDataSource

Runs the DatabaseStatus checks against $Instance then saves to json to $env:windir\temp\dbadisa\dbadisa_1_DatabaseStatus.json

.EXAMPLE
Invoke-DbsCheck -SqlInstance $Instance -Check DatabaseStatus -Show None -PassThru | Update-DbsPowerBiDataSource -Path C:\Temp

Runs the DatabaseStatus checks against $Instance then saves to json to C:\Temp\dbadisa_1_DatabaseStatus.json

.EXAMPLE
Invoke-DbsCheck -SqlInstance $Instance -Check DatabaseStatus -Show None -PassThru | Update-DbsPowerBiDataSource -Path C:\Temp  -FileName BeardyTests

Runs the DatabaseStatus checks against $Instance then saves to json to C:\Temp\BeardyTests.json

.EXAMPLE
Invoke-DbsCheck -SqlInstance $Instance -Check DatabaseStatus -Show None -PassThru | Update-DbsPowerBiDataSource -Path C:\Temp  -FileName BeardyTests.json

Runs the DatabaseStatus checks against $Instance then saves to json to C:\Temp\BeardyTests.json

.EXAMPLE
Invoke-DbsCheck -SqlInstance $Instance -Check DatabaseStatus -Show None -PassThru | Update-DbsPowerBiDataSource -Path C:\Temp  -Environment Prod_DBChecks

Runs the DatabaseStatus checks against $Instance then saves to json to  C:\Temp\dbadisa_1_Prod_DBChecks_DatabaseStatus.json

.EXAMPLE
Invoke-DbsCheck -SqlInstance $Instance -Check DatabaseStatus -Show None -PassThru | Update-DbsPowerBiDataSource -Environment Prod_DBChecks

Runs the DatabaseStatus checks against $Instance then saves to json to  C:\Windows\temp\dbadisa\dbadisa_1_Prod_DBChecks_DatabaseStatus.json

.EXAMPLE
Invoke-DbsCheck -SqlInstance sql2017 -Tag Backup -Show Summary -PassThru | Update-DbsPowerBiDataSource -Path \\nas\projects\dbadisa.json
Start-DbsPowerBi -Path \\nas\projects\dbadisa.json

Runs tests, saves to json to \\nas\projects\dbadisa.json
Opens the PowerBi using that file
then you'll have to change your data source in Power BI because by default it
points to C:\Windows\Temp (limitation of Power BI)

.EXAMPLE

Set-DbsConfig -Name app.checkrepos -Value \\SharedPath\CustomPesterChecks
Invoke-DbsCheck -SqlInstance $Instance -Check DatabaseStatus, CustomCheckTag -PassThru | Update-DbsPowerBiDataSource -Path \\SharedPath\CheckResults -Name CustomCheckResults -Append

Because we are using a custom check repository you MUSTR use the Append parameter for Update-DbsPowerBiDataSource
otherwise the json file will be overwritten

Sets the custom check repository to \\SharedPath\CustomPesterChecks
Runs the DatabaseStatus checks and custom checks with the CustomCheckTag against $Instance then saves all the results
to json to \\SharedPath\CheckResults.json -Name CustomCheckResults


.EXAMPLE
Invoke-DbsCheck -SqlInstance sql2017 -Check SuspectPage -Show None -PassThru | Update-DbsPowerBiDataSource -Environment Test -Whatif

What if: Performing the operation "Removing .json files named *Default*" on target "C:\Windows\temp\dbadisa".
What if: Performing the operation "Passing results" on target "C:\Windows\temp\dbadisa\dbadisa_1_Test__SuspectPage.json".

Will not actually create or update the data sources but will output what happens with the command and what the file name will be
called.

.LINK
https://dbadisa.readthedocs.io/en/latest/functions/Update-DbsPowerBiDataSource/

#>
function Update-DbsPowerBiDataSource {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param (
        [parameter(ValueFromPipeline, Mandatory)]
        [pscustomobject]$InputObject,
        [string]$Path = "$env:windir\temp\dbadisa",
        [string]$FileName,
        [string]$Environment = "Default",
        [switch]$Force,
        [switch]$EnableException,
        [switch]$Append
    )
    begin {
        Write-PSFMessage "Starting begin block" -Level Debug
        if ($IsLinux -and $Path -eq '\temp\dbadisa') {
            Write-PSFMessage "Setting path on Linux" -Level Verbose
            $Path = Get-DbsConfigValue -Name app.localapp
            Write-PSFMessage "Setting path on Linux to $Path" -Level Verbose
        }
        if ($Force) {
            if ($PSCmdlet.ShouldProcess($Path, 'Removing all .json files')) {
                try {
                    $null = Remove-Item "$Path\*.json" -ErrorAction Stop
                    Write-PSFMessage "Removed all files from $Path" -Level Verbose
                } catch {
                    Stop-PSFFunction -Message "FAILED - Removing all files from $Path" -ErrorRecord $_
                    return
                }
            }
        }
    }
    process {
        ++$i
        try {
            if (-not (Test-Path -Path $Path)) {
                if ($PSCmdlet.ShouldProcess($Path, 'Creating new directory')) {
                    $null = New-Item -ItemType Directory -Path $Path -ErrorAction Stop
                    Write-PSFMessage "Created New Directory $Path" -Level Verbose
                }
            }
        } catch {
            Stop-PSFFunction -Message "Failed - Creating New Directory $Path" -ErrorRecord $_
            return
        }
        $basename = "dbadisa_$i"
        if ($Environment) {
            $basename = "dbadisa_$i" + "_$Environment`_"
        }
        if ($FileName) {
            $basename = $FileName
        } else {
            if ($InputObject.TagFilter) {
                $tagnames = $InputObject.TagFilter[0..3] -join "_"
                $basename = "$basename`_" + $tagnames + ".json"
            }
        }

        if ($basename.EndsWith('.json')) { }
        else {
            $basename = $basename + ".json"
        }

        Write-PSFMessage "Set basename to $basename" -Level Verbose
        $FilePath = "$Path\$basename"
        Write-PSFMessage "Set filepath to $FilePath" -Level Verbose

        if ($InputObject.TotalCount -gt 0) {
            try {
                if ($PSCmdlet.ShouldProcess($FilePath, 'Passing results')) {
                    if ($Append) {
                        $InputObject.TestResult | ConvertTo-Json -Depth 3 | Out-File -FilePath $FilePath -Append
                        Write-PSFMessage -Level Output -Message "Appended results to $FilePath"
                    } else {
                        $InputObject.TestResult | ConvertTo-Json -Depth 3 | Out-File -FilePath $FilePath
                        Write-PSFMessage -Level Output -Message "Wrote results to $FilePath"
                    }
                }
            } catch {
                Stop-PSFFunction -Message "Failed Passing Results to $FilePath" -ErrorRecord $_
                return
            }
        }
    }
    end {
        if ($InputObject.TotalCount -isnot [int]) {
            Stop-PSFFunction -Message "Invalid TestResult. Did you forget to use -Passthru with Invoke-DbsCheck?"
            return
        }
    }
}