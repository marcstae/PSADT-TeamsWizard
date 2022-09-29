<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $true,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'LyncWizard'
	[string]$appName = 'TeamsWizard'
	[string]$appVersion = '0.4.6'
	[string]$appArch = 'x64' #e.g x64
	[string]$appLang = 'ML'
	[string]$appRevision = '001'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '23/09/2022'
	[string]$appScriptAuthor = 'Marc Staeuble'
	[string]$packageIdentifier = "$($appVendor)_$($appName)_$($appVersion)_$($appArch)_$($appLang)_$($appRevision)"
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = $packageIdentifier
	[string]$installTitle = $packageIdentifier

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.4'
	[string]$deployAppScriptDate = '26/01/2021'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	[string]$MSIProductCode = '{85F4CBCB-9BBC-4B50-A7D8-E1106771498D}' # e.g {0EB47F41-0FF3-472D-ADA1-2389E96A56C4}
	[string]$MSIName = 'TeamsWizard_x64.msi' #MSI 
	#[string]$MSIName0 = '' #MSI 
	#[string]$MSIName1 = '' #MSI 
	[string]$TransformName = '' #MST
	#[string]$TransformName0 = '' #MST
	#[string]$TransformName1 = '' #MST
	
    $Date=Date
    #only for .exe
    [string]$LOG = $configToolkitLogDir + "\$installName" + "_$DeploymentType.log"
	
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		#Show-InstallationWelcome -CloseApps 'iexplore' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt
        #Show-InstallationWelcome -CloseApps 'outlook,act!' -CheckDiskSpace -PersistPrompt -BlockExecution
		#Show-InstallationWelcome -CloseApps 'winword=Microsoft Office Word,excel=Microsoft Office Excel' -CloseAppsCountdown 1800 -DeferTimes 3 -CheckDiskSpace
		
		## Show Progress Message (with the default message)
		#Show-InstallationProgress

		## <Perform Pre-Installation tasks here>


		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## MSI
        if ($TransformName)
        {
			# Abbruch bei Fehler
			Execute-MSI -Action Install -Path "$MSIName" -Transform "$TransformName" -private:$installName -AddParameters "ALLUSERS=1"
			Execute-MSI -Action Install -Path "$MSIName0" -Transform "$TransformName;$TransformName0" -private:$installName
			
			# Kein Abbruch bei Fehler da returncode mit -passthru �bergeben wird
			#[psobject]$ExecuteResult = Execute-MSI -Action Install -Path "$MSIName" -Transform "$TransformName" -private:$installName -PassThru
        } 
        else 
        {
            Execute-MSI -Action Install -Path "$MSIName" -private:$installName -AddParameters "ALLUSERS=1"
			#Execute-MSI -Action Install -Path "$MSIName1" -private:$installName -AddParameters "ALLUSERS=1"
        }
		
		## LEGACY
		##Execute-Process -Path "$dirFiles\setup.exe" -Parameters "-xml `"creohelpdma.p.xml`""
		##Execute-Process -Path "$dirFiles\setup2.exe" -Parameters "-xml creohelpdma.p.xml" #ohne gaensefuesse
		##Execute-Process -Path "$dirFiles\setup.exe" -Parameters "-xml `"creohelpdma.p.xml`"" -IgnoreExitCodes 19 # ignores Exitcode
		## <Perform Installation tasks here>


		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'
		
		## <Perform Post-Installation tasks here>
        Set-Brandingkeys $DeploymentType

        ## write EventLog
        Write-ToEventLog "Application" "AveniqInstaller" "100" "$installName -- Installation operation completed successfully. -- $ExecuteResult. Detailed Information see LOGFILE" "Information" 
		


		#++++++++++++++++++NEWLY ADDED PART STARTS HERE++++++++++++++++++++++NEWLY ADDED PART STARTS HERE++++++++++++++++++++++NEWLY ADDED PART STARTS HERE++++++++++++++++++++++
		#++++++++++++++++++NEWLY ADDED PART STARTS HERE++++++++++++++++++++++NEWLY ADDED PART STARTS HERE++++++++++++++++++++++NEWLY ADDED PART STARTS HERE++++++++++++++++++++++
		#++++++++++++++++++NEWLY ADDED PART STARTS HERE++++++++++++++++++++++NEWLY ADDED PART STARTS HERE++++++++++++++++++++++NEWLY ADDED PART STARTS HERE++++++++++++++++++++++

		#do chunnt s'restlich gschmeus inne für nachkonfiguration
		#regshot für registry verwende und ganze mit active setup dureführe
		
		#creates a new registry entry
		Set-RegistryKey -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\ServiceInstances" -Name "TeamsWizard" -value "1" -Type DWord

		#HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\ServiceInstances
		#HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\ServiceInstances\b19df79f-56aa-4017-be25-a5636a65962c
		#HKLM\SYSTEM\Software\Microsoft\TIP\TestResults\27641008\ { 1ABB19DE-098C-4E1C-A7A0-B0408D8C9A31 }
		#HKLM\SYSTEM\Software\Microsoft\TIP\TestResults\27641008\ { 2A4B2391-E47A-453B-A625-3197A4E9229F }
		#HKLM\SYSTEM\Software\Microsoft\TIP\TestResults\27641008\ { 84985E62 - 83B8-489E-B52F-86AA9841B6C1 }
		#HKU\S-1-12-1-2783419563-1193993123-3302152632-1042603199\Software\Microsoft\Windows\CurrentVersion\SearchSettings\Dynamic\ { 35ac0828-603c-4c7d-b11a-965fd66de4a7 }
		#HKU\S-1-12-1-2783419563-1193993123-3302152632-1042603199\Software\Microsoft\Windows\CurrentVersion\SearchSettings\Dynamic\ { 35ac0828-603c-4c7d-b11a-965fd66de4a7 }\icons


		#delete registry keys (these are the same as in the regshot capture)
		Remove-RegistryKey -Key 'HKU\S-1-12-1-2783419563-1193993123-3302152632-1042603199\Software\Microsoft\Windows\CurrentVersion\Explorer\SessionInfo\2\ApplicationViewManagement\W32:000000000009145C' -SID $UserProfile.SID
		Remove-RegistryKey -Key 'HKU\S-1-12-1-2783419563-1193993123-3302152632-1042603199\Software\Microsoft\Windows\CurrentVersion\SearchSettings\Dynamic\ { 0d319bdf-6777-49b0-9aa2-e559abd58e07 }' -SID $UserProfile.SID
		Remove-RegistryKey -Key 'HKU\S-1-12-1-2783419563-1193993123-3302152632-1042603199\Software\Microsoft\Windows\CurrentVersion\SearchSettings\Dynamic\ { 0d319bdf-6777-49b0-9aa2-e559abd58e07 }\icons' -SID $UserProfile.SID

		#++++++++++++++++++NEWLY ADDED PART ENDS HERE++++++++++++++++++++++NEWLY ADDED PART ENDS HERE++++++++++++++++++++++NEWLY ADDED PART ENDS HERE++++++++++++++++++++++
		#++++++++++++++++++NEWLY ADDED PART ENDS HERE++++++++++++++++++++++NEWLY ADDED PART ENDS HERE++++++++++++++++++++++NEWLY ADDED PART ENDS HERE++++++++++++++++++++++
		#++++++++++++++++++NEWLY ADDED PART ENDS HERE++++++++++++++++++++++NEWLY ADDED PART ENDS HERE++++++++++++++++++++++NEWLY ADDED PART ENDS HERE++++++++++++++++++++++
		


        ## create shortcuts
		#New-Shortcut -Path "$envProgramData\Microsoft\Windows\Start Menu\My Shortcut.lnk" -TargetPath "$envWinDir\system32\notepad.exe" -IconLocation "$envWinDir\system32\notepad.exe" -Description 'Notepad' -WorkingDirectory "$envHomeDrive\$envHomePath"
		#New-Shortcut -Path "$envCommonDesktop\My Shortcut.lnk" -TargetPath "$envWinDir\system32\notepad.exe" -IconLocation "$envWinDir\system32\notepad.exe" -Description 'Notepad' -WorkingDirectory "$envHomeDrive\$envHomePath"
	    
        ## copy a file
        #Copy-File -Path "$dirSupportFiles\*.*" -Destination "$envTemp\tempfiles"

        ## start-/stop services
		#stop-Process -name "*Pulse*" -Force 
		#start-Service pulsesecureservice
		
        ## write registrykeys
		#Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Pulse Secure 9.1" -Name "NoRepair" -value "1" -Type DWord
		#Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Pulse Secure 9.1" -Name "NoRemove" -value "1" -Type DWord
		#Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Pulse Secure 9.1" -Name "NoModify" -value "1" -Type DWord
		
		## place active setup
        #Set-ActiveSetup -StubExePath "$envSystem32Directory\msiexec.exe" -Arguments "/fups $MSIProductCode /qn" -Description "$installName User Config" -Key $installName
		#Set-ActiveSetup -StubExePath "$envProgramFilesX86\Pulse Secure\Pulse\PSSetupClientInstaller.exe" -Arguments "/S" -Description "$installName Pulse Setup Client Config" -Key $installName"
		
		## Execute ScriptBlock which contains code to manipulate HKCU registry.
        #[scriptblock]$HKCURegistrySettings = {
            
            ##Delete  HKCU REG
        #    Remove-RegistryKey -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Pulse_Setup_Client' -SID $UserProfile.SID
        #    Remove-RegistryKey -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\PulseSecure_Host_Checker' -SID $UserProfile.SID
        #}
        #Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings $HKCURegistrySettings
		
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		#Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60
        #Show-InstallationWelcome -CloseApps 'outlook,act!' -PersistPrompt -BlockExecution

		## Show Progress Message (with the default message)
		#Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'


		# <Perform Uninstallation tasks here>
		
		# MSI
        Execute-MSI -Action Uninstall -Path $MSIProductCode -private:$installName
		
		# LEGACY
        # $cmdLine="$env:SystemDrive\PTC\Creo 3.0\help\creo_help_dma\bin\uninstall.exe"
        # if(Test-Path "$cmdLine")
        # {
        #     Execute-Process -Path "$cmdLine" -Parameters "-quiet"
        # }
		

		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>
        
		## set branding key status to uninstalled
		Set-Brandingkeys $DeploymentType
		
		#write Eventlog
        Write-ToEventLog "Application" "AveniqInstaller" "100" "$installName -- Removal completed successfully. -- $ExecuteResult. Detailed Information see LOGFILE" "Information"
		
		# Remove File
		#Remove-Folder -Path "$envWinDir\Downloaded Program Files"
		#Remove-EmptyFolder "$envProgramFiles\Microsoft"
		
		##Remove Registry
		#Remove-RegistryKey -Key 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Pulse Secure 9.1'
		
		# Remove File
		#Remove-File -Path 'C:\Windows\Downloaded Program Files\Temp.inf'
		
		#Set-ActiveSetup -Key $installName -PurgeActiveSetupKey


	}
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}

