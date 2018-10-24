#==========================================================================
#
# Install Citrix StoreFront
#
# AUTHOR: Dennis Span (http://dennisspan.com)
# DATE  : 19.01.2018
#
# COMMENT:
# This script has been prepared for Windows Server 2008 R2, 2012 R2 and 2016.
#
# The version of StoreFront used in this script is 3.13 (released in Q4 2017),
# but it should also work for previous versions.
#
#==========================================================================

# Get the script parameters if there are any
param
(
    # The only parameter which is really required is 'Uninstall'
    # If no parameters are present or if the parameter is not
    # 'uninstall', an installation process is triggered
    [string]$Installationtype
)

# define Error handling
# note: do not change these values
$global:ErrorActionPreference = "Stop"
if($verbose){ $global:VerbosePreference = "Continue" }

# FUNCTION DS_WriteLog
#==========================================================================
Function DS_WriteLog {
    <#
        .SYNOPSIS
        Write text to this script's log file
        .DESCRIPTION
        Write text to this script's log file
        .PARAMETER InformationType
        This parameter contains the information type prefix. Possible prefixes and information types are:
            I = Information
            S = Success
            W = Warning
            E = Error
            - = No status
        .PARAMETER Text
        This parameter contains the text (the line) you want to write to the log file. If text in the parameter is omitted, an empty line is written.
        .PARAMETER LogFile
        This parameter contains the full path, the file name and file extension to the log file (e.g. C:\Logs\MyApps\MylogFile.log)
        .EXAMPLE
        DS_WriteLog -$InformationType "I" -Text "Copy files to C:\Temp" -LogFile "C:\Logs\MylogFile.log"
        Writes a line containing information to the log file
        .Example
        DS_WriteLog -$InformationType "E" -Text "An error occurred trying to copy files to C:\Temp (error: $($Error[0]))" -LogFile "C:\Logs\MylogFile.log"
        Writes a line containing error information to the log file
        .Example
        DS_WriteLog -$InformationType "-" -Text "" -LogFile "C:\Logs\MylogFile.log"
        Writes an empty line to the log file
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position = 0)][ValidateSet("I","S","W","E","-",IgnoreCase = $True)][String]$InformationType,
        [Parameter(Mandatory=$true, Position = 1)][AllowEmptyString()][String]$Text,
        [Parameter(Mandatory=$true, Position = 2)][AllowEmptyString()][String]$LogFile
    )

    begin {
    }

    process {
     $DateTime = (Get-Date -format dd-MM-yyyy) + " " + (Get-Date -format HH:mm:ss)

        if ( $Text -eq "" ) {
            Add-Content $LogFile -value ("") # Write an empty line
        } Else {
         Add-Content $LogFile -value ($DateTime + " " + $InformationType.ToUpper() + " - " + $Text)
        }
    }

    end {
    }
}
#==========================================================================

# FUNCTION DS_InstallOrUninstallSoftware
#==========================================================================
Function DS_InstallOrUninstallSoftware {
     <#
        .SYNOPSIS
        Install or uninstall software (MSI or SETUP.exe)
        .DESCRIPTION
        Install or uninstall software (MSI or SETUP.exe)
        .PARAMETER File
        This parameter contains the file name including the path and file extension, for example C:\Temp\MyApp\Files\MyApp.msi or C:\Temp\MyApp\Files\MyApp.exe.
        .PARAMETER Installationtype
        This parameter contains the installation type, which is either 'Install' or 'Uninstall'.
        .PARAMETER Arguments
        This parameter contains the command line arguments. The arguments list can remain empty.
        In case of an MSI, the following parameters are automatically included in the function and do not have
        to be specified in the 'Arguments' parameter: /i (or /x) /qn /norestart /l*v "c:\Logs\MyLogFile.log"
        .EXAMPLE
        DS_InstallOrUninstallSoftware -File "C:\Temp\MyApp\Files\MyApp.msi" -InstallationType "Install" -Arguments ""
        Installs the MSI package 'MyApp.msi' with no arguments (the function already includes the following default arguments: /i /qn /norestart /l*v $LogFile)
        .Example
        DS_InstallOrUninstallSoftware -File "C:\Temp\MyApp\Files\MyApp.msi" -InstallationType "Uninstall" -Arguments ""
        Uninstalls the MSI package 'MyApp.msi' (the function already includes the following default arguments: /x /qn /norestart /l*v $LogFile)
        .Example
        DS_InstallOrUninstallSoftware -File "C:\Temp\MyApp\Files\MyApp.exe" -InstallationType "Install" -Arguments "/silent /logfile:C:\Logs\MyApp\log.log"
        Installs the SETUP file 'MyApp.exe'
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position = 0)][String]$File,
        [Parameter(Mandatory=$true, Position = 1)][AllowEmptyString()][String]$Installationtype,
        [Parameter(Mandatory=$true, Position = 2)][AllowEmptyString()][String]$Arguments
    )

    begin {
        [string]$FunctionName = $PSCmdlet.MyInvocation.MyCommand.Name
        DS_WriteLog "I" "START FUNCTION - $FunctionName" $LogFile
    }

    process {
        $FileName = ($File.Split("\"))[-1]
        $FileExt = $FileName.SubString(($FileName.Length)-3,3)

        # Prepare variables
        if ( !( $FileExt -eq "MSI") ) { $FileExt = "SETUP" }
        if ( $Installationtype -eq "Uninstall" ) {
            $Result1 = "uninstalled"
            $Result2 = "uninstallation"
        } else {
            $Result1 = "installed"
            $Result2 = "installation"
        }
        $LogFileAPP = Join-path $LogDir ( "$($Installationtype)_$($FileName.Substring(0,($FileName.Length)-4))_$($FileExt).log" )

        # Logging
        DS_WriteLog "I" "File name: $FileName" $LogFile
        DS_WriteLog "I" "File full path: $File" $LogFile

        # Check if the installation file exists
        if (! (Test-Path $File) ) {
            DS_WriteLog "E" "The file '$File' does not exist!" $LogFile
            Exit 1
        }

        # Check if custom arguments were defined
        if ([string]::IsNullOrEmpty($Arguments)) {
            DS_WriteLog "I" "File arguments: <no arguments defined>" $LogFile
        } Else {
            DS_WriteLog "I" "File arguments: $Arguments" $LogFile
        }

        # Install the MSI or SETUP.exe
        DS_WriteLog "-" "" $LogFile
        DS_WriteLog "I" "Start the $Result2" $LogFile
        if ( $FileExt -eq "MSI" ) {
            if ( $Installationtype -eq "Uninstall" ) {
                $FixedArguments = "/x ""$File"" /qn /norestart /l*v ""$LogFileAPP"""
            } else {
                $FixedArguments = "/i ""$File"" /qn /norestart /l*v ""$LogFileAPP"""
            }
            if ([string]::IsNullOrEmpty($Arguments)) {   # check if custom arguments were defined
                $arguments = $FixedArguments
                DS_WriteLog "I" "Command line: Start-Process -FilePath 'msiexec.exe' -ArgumentList $arguments -Wait -PassThru" $LogFile
                $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $arguments -Wait -PassThru
            } Else {
                $arguments =  $FixedArguments + " " + $arguments
                DS_WriteLog "I" "Command line: Start-Process -FilePath 'msiexec.exe' -ArgumentList $arguments -Wait -PassThru" $LogFile
                $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $arguments -Wait -PassThru
            }
        } Else {
            if ([string]::IsNullOrEmpty($Arguments)) {   # check if custom arguments were defined
                DS_WriteLog "I" "Command line: Start-Process -FilePath ""$File"" -Wait -PassThru" $LogFile
                $process = Start-Process -FilePath "$File" -Wait -PassThru
            } Else {
                DS_WriteLog "I" "Command line: Start-Process -FilePath ""$File"" -ArgumentList $arguments -Wait -PassThru" $LogFile
                $process = Start-Process -FilePath "$File" -ArgumentList $arguments -Wait -PassThru
            }
        }

        # Check the result (the exit code) of the installation
        switch ($Process.ExitCode)
        {
            0 { DS_WriteLog "S" "The software was $Result1 successfully (exit code: 0)" $LogFile }
            3 { DS_WriteLog "S" "The software was $Result1 successfully (exit code: 3)" $LogFile } # Some Citrix products exit with 3 instead of 0
            1603 { DS_WriteLog "E" "A fatal error occurred (exit code: 1603). Some applications throw this error when the software is already (correctly) installed! Please check." $LogFile }
            1605 { DS_WriteLog "I" "The software is not currently installed on this machine (exit code: 1605)" $LogFile }
            1619 {
                DS_WriteLog "E" "The installation files cannot be found. The PS1 script should be in the root directory and all source files in the subdirectory 'Files' (exit code: 1619)" $LogFile
                Exit 1
                }
            3010 { DS_WriteLog "W" "A reboot is required (exit code: 3010)!" $LogFile }
            default {
                [string]$ExitCode = $Process.ExitCode
                DS_WriteLog "E" "The $Result2 ended in an error (exit code: $ExitCode)!" $LogFile
                Exit 1
            }
        }
    }

    end {
        DS_WriteLog "I" "END FUNCTION - $FunctionName" $LogFile
    }
}
#==========================================================================

# FUNCTION DS_CopyFile
#==========================================================================
Function DS_CopyFile {
    <#
        .SYNOPSIS
        Copy one or more files
        .DESCRIPTION
        Copy one or more files
        .PARAMETER SourceFiles
        This parameter can contain multiple file and folder combinations including wildcards. UNC paths can be used as well. Please see the examples for more information.
        To see the examples, please enter the following PowerShell command: Get-Help DS_CopyFile -examples
        .PARAMETER Destination
        This parameter contains the destination path (for example 'C:\Temp2' or 'C:\MyPath\MyApp'). This path may also include a file name.
        This situation occurs when a single file is copied to another directory and renamed in the process (for example '$Destination = C:\Temp2\MyNewFile.txt').
        UNC paths can be used as well. The destination directory is automatically created if it does not exist (in this case the function 'DS_CreateDirectory' is called).
        This works both with local and network (UNC) directories. In case the variable $Destination contains a path and a file name, the parent folder is
        automatically extracted, checked and created if needed.
        Please see the examples for more information.To see the examples, please enter the following PowerShell command: Get-Help DS_CopyFile -examples
        .EXAMPLE
        DS_CopyFile -SourceFiles "C:\Temp\MyFile.txt" -Destination "C:\Temp2"
        Copies the file 'C:\Temp\MyFile.txt' to the directory 'C:\Temp2'
        .EXAMPLE
        DS_CopyFile -SourceFiles "C:\Temp\MyFile.txt" -Destination "C:\Temp2\MyNewFileName.txt"
        Copies the file 'C:\Temp\MyFile.txt' to the directory 'C:\Temp2' and renames the file to 'MyNewFileName.txt'
        .EXAMPLE
        DS_CopyFile -SourceFiles "C:\Temp\*.txt" -Destination "C:\Temp2"
        Copies all files with the file extension '*.txt' in the directory 'C:\Temp' to the destination directory 'C:\Temp2'
        .EXAMPLE
        DS_CopyFile -SourceFiles "C:\Temp\*.*" -Destination "C:\Temp2"
        Copies all files within the root directory 'C:\Temp' to the destination directory 'C:\Temp2'. Subfolders (including files within these subfolders) are NOT copied.
        .EXAMPLE
        DS_CopyFile -SourceFiles "C:\Temp\*" -Destination "C:\Temp2"
        Copies all files in the directory 'C:\Temp' to the destination directory 'C:\Temp2'. Subfolders as well as files within these subfolders are also copied.
        .EXAMPLE
        DS_CopyFile -SourceFiles "C:\Temp\*.txt" -Destination "\\localhost\Temp2"
        Copies all files with the file extension '*.txt' in the directory 'C:\Temp' to the destination directory '\\localhost\Temp2'. The directory in this example is a network directory (UNC path).
    #>
    [CmdletBinding()]
 Param(
 [Parameter(Mandatory=$true, Position = 0)][String]$SourceFiles,
        [Parameter(Mandatory=$true, Position = 1)][String]$Destination
 )

    begin {
        [string]$FunctionName = $PSCmdlet.MyInvocation.MyCommand.Name
        DS_WriteLog "I" "START FUNCTION - $FunctionName" $LogFile
    }

    process {
        DS_WriteLog "I" "Copy the source file(s) '$SourceFiles' to '$Destination'" $LogFile
        # Retrieve the parent folder of the destination path
        if ( $Destination.Contains(".") ) {
            # In case the variable $Destination contains a dot ("."), return the parent folder of the path
            $TempFolder = split-path -path $Destination
        } else {
            $TempFolder = $Destination
        }

        # Check if the destination path exists. If not, create it.
        DS_WriteLog "I" "Check if the destination path '$TempFolder' exists. If not, create it" $LogFile
        if ( Test-Path $TempFolder) {
            DS_WriteLog "I" "The destination path '$TempFolder' already exists. Nothing to do" $LogFile
        } else {
            DS_WriteLog "I" "The destination path '$TempFolder' does not exist" $LogFile
            DS_CreateDirectory -Directory $TempFolder
        }

        # Copy the source files
        DS_WriteLog "I" "Start copying the source file(s) '$SourceFiles' to '$Destination'" $LogFile
        try {
            Copy-Item $SourceFiles -Destination $Destination -Force -Recurse
            DS_WriteLog "S" "Successfully copied the source files(s) '$SourceFiles' to '$Destination'" $LogFile
        } catch {
            DS_WriteLog "E" "An error occurred trying to copy the source files(s) '$SourceFiles' to '$Destination'" $LogFile
            Exit 1
        }
    }

    end {
        DS_WriteLog "I" "END FUNCTION - $FunctionName" $LogFile
    }
}
#==========================================================================

# FUNCTION DS_DeleteDirectory
# Description: delete the entire directory
#==========================================================================
Function DS_DeleteDirectory {
    <#
        .SYNOPSIS
        Delete a directory
        .DESCRIPTION
        Delete a directory
        .PARAMETER Directory
        This parameter contains the full path to the directory which needs to be deleted (for example C:\Temp\MyOldFolder).
        .EXAMPLE
        DS_DeleteDirectory -Directory "C:\Temp\MyOldFolder"
        Deletes the directory "C:\Temp\MyNewFolder"
    #>
    [CmdletBinding()]
 Param(
 [Parameter(Mandatory=$true, Position = 0)][String]$Directory
 )

    begin {
        [string]$FunctionName = $PSCmdlet.MyInvocation.MyCommand.Name
        DS_WriteLog "I" "START FUNCTION - $FunctionName" $LogFile
    }

    process {
        DS_WriteLog "I" "Delete directory $Directory" $LogFile
        if ( Test-Path $Directory ) {
            try {
                Remove-Item $Directory -force -recurse | Out-Null
                DS_WriteLog "S" "Successfully deleted the directory $Directory" $LogFile
            } catch {
                DS_WriteLog "E" "An error occurred trying to delete the directory $Directory (exit code: $($Error[0])!" $LogFile
                Exit 1
            }
        } else {
           DS_WriteLog "I" "The directory $Directory does not exist. Nothing to do." $LogFile
        }
    }

    end {
        DS_WriteLog "I" "END FUNCTION - $FunctionName" $LogFile
    }
}
#==========================================================================


################
# Main section #
################

# Disable File Security
$env:SEE_MASK_NOZONECHECKS = 1

# Custom variables [edit]
$BaseLogDir = "C:\Logs"                                         # [edit] add the location of your log directory here
$PackageName = "Citrix StoreFront (installation)"               # [edit] enter the display name of the software (e.g. 'Arcobat Reader' or 'Microsoft Office')

# Global variables
$StartDir = $PSScriptRoot # the directory path of the script currently being executed
if (!($Installationtype -eq "Uninstall")) { $Installationtype = "Install" }
$LogDir = (Join-Path $BaseLogDir $PackageName).Replace(" ","_")
$LogFileName = "$($Installationtype)_$($PackageName).log"
$LogFile = Join-path $LogDir $LogFileName

# Create the log directory if it does not exist
if (!(Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType directory | Out-Null }

# Create new log file (overwrite existing one)
New-Item $LogFile -ItemType "file" -force | Out-Null

DS_WriteLog "I" "START SCRIPT - $Installationtype $PackageName" $LogFile
DS_WriteLog "-" "" $LogFile

#################################################
# INSTALL CITRIX STOREFRONT                     #
#################################################

DS_WriteLog "I" "Install Citrix StoreFront" $LogFile

DS_WriteLog "-" "" $LogFile

# Set the default to the StoreFront log files
$DefaultStoreFrontLogPath = "$env:SystemRoot\temp\StoreFront"

# Delete old log files (= delete the directory C:\Windows\temp\StoreFront"
DS_WriteLog "I" "Delete old log folders" $LogFile
DS_DeleteDirectory -Directory $DefaultStoreFrontLogPath

DS_WriteLog "-" "" $LogFile

# Install StoreFront
$File = Join-Path $StartDir "Files\CitrixStoreFront-x64.exe"
$Arguments = "-silent"
DS_InstallOrUninstallSoftware -File $File -InstallationType "Install" -Arguments $Arguments

DS_WriteLog "-" "" $LogFile

# Copy the StoreFront log files from the StoreFront default log directory to our custom directory
DS_WriteLog "I" "Copy the log files from the directory $DefaultStoreFrontLogPath to $LogDir" $LogFile
DS_CopyFile -SourceFiles (Join-Path $DefaultStoreFrontLogPath "*.log") -Destination $LogDir

# Enable File Security
Remove-Item env:\SEE_MASK_NOZONECHECKS

DS_WriteLog "-" "" $LogFile
DS_WriteLog "I" "End of script" $LogFile
