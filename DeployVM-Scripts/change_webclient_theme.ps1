Function Set-VCSATheme {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]$vcsaOSuser,
        [Parameter(Mandatory=$true)]$vcsaOSpass,
        [Parameter(Mandatory=$true)]$VCSAVM
    )
    DynamicParam {
            # Set the dynamic parameters' name
            $ParameterName = 'Theme'
            
            # Create the dictionary 
            $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

            # Create the collection of attributes
            $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            
            # Create and set the parameters' attributes
            $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
            $ParameterAttribute.Mandatory = $true
            $ParameterAttribute.Position = 1

            # Add the attributes to the attributes collection
            $AttributeCollection.Add($ParameterAttribute)

            # Generate and set the ValidateSet 
            $folder = Get-item -path "/root/customize-vsphere-web-client-6.5"
            $themefolder = "$($(Get-Childitem -Directory $($folder.fullname)).fullname)"
            [System.Collections.ArrayList]$arrSet = Get-ChildItem -Path $themefolder -Directory | Select-Object -ExpandProperty Name
            $RestoreOption = $arrSet.Add("Default")
            $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)

            # Add the ValidateSet to the attributes collection
            $AttributeCollection.Add($ValidateSetAttribute)

            # Create and return the dynamic parameter
            $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
            $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
            return $RuntimeParameterDictionary
    }
   
   begin {
        # Bind the parameter to a friendly variable
        $theme = $PsBoundParameters[$ParameterName]
    }

    process {
        $VCVM = Get-VM $VCSAVM
        if ($theme -eq "Default"){
            Write-Verbose "Restoring original theme"
            $backupLoginFile = invoke-vmscript -vm $VCVM -GuestUser $vcsaOSuser -GuestPassword $vcsaOSpass -ScriptText "cp /usr/lib/vmware-sso/vmware-sts/webapps/websso/resources/css/login.css.themebak /usr/lib/vmware-sso/vmware-sts/webapps/websso/resources/css/login.css" -ScriptType Bash
            Write-Verbose $backupLoginFile
            $backupUnpentry = invoke-vmscript -vm $VCVM -GuestUser $vcsaOSuser -GuestPassword $vcsaOSpass -ScriptText "cp /usr/lib/vmware-sso/vmware-sts/webapps/websso/WEB-INF/views/unpentry.jsp.themebak /usr/lib/vmware-sso/vmware-sts/webapps/websso/WEB-INF/views/unpentry.jsp" -ScriptType Bash
            Write-Verbose $backupunpentry
            Write-Host "Theme restored to original" -ForegroundColor Green
            return
        }
        $folder = Get-item -path "/root/customize-vsphere-web-client-6.5"
        $themefolder = "$($(Get-Childitem -Directory $($folder.fullname)).fullname)"
        if (-Not (Test-Path $themefolder)) {
            Write-Warning "$VCVer Theme folder not found at $themefolder, run Get-VCSATheme -VCVer $vCVer to download the latest themes"
            Return
        }
        $UseTheme = $themefolder + "/$theme"
        
        $bakresponse = invoke-vmscript -vm $VCVM -GuestUser $vcsaOSuser -GuestPassword $vcsaOSpass -ScriptText "ls /usr/lib/vmware-sso/vmware-sts/webapps/websso/resources/css/login.css.themebak" -ScriptType Bash
        if ($bakresponse -match "No such file or directory") {
            Write-Verbose "No Theme backup found, backing up original theme"
            $backupLoginFile = invoke-vmscript -vm $VCVM -GuestUser $vcsaOSuser -GuestPassword $vcsaOSpass -ScriptText "cp /usr/lib/vmware-sso/vmware-sts/webapps/websso/resources/css/login.css /usr/lib/vmware-sso/vmware-sts/webapps/websso/resources/css/login.css.themebak" -ScriptType Bash
            Write-Verbose $backupLoginFile
            $backupUnpentry = invoke-vmscript -vm $VCVM -GuestUser $vcsaOSuser -GuestPassword $vcsaOSpass -ScriptText "cp /usr/lib/vmware-sso/vmware-sts/webapps/websso/WEB-INF/views/unpentry.jsp /usr/lib/vmware-sso/vmware-sts/webapps/websso/WEB-INF/views/unpentry.jsp.themebak" -ScriptType Bash
            Write-Verbose $backupunpentry
            Write-Verbose "Theme backup created, applying new theme"
        } Else {
            Write-Verbose "Theme backup already found, applying new theme"
        }
        Get-Item "$Usetheme/*.png", "$usetheme/*.jpg", "$usetheme/*.gif" | Where { $_.name -notlike "sample*"} | Foreach {
            write-verbose "Copying $($_.fullname) to /usr/lib/vmware-sso/vmware-sts/webapps/websso/resources/img/$($_.name)"
            $_ | Copy-VMGuestFile -LocalToGuest -VM $VCVM -Destination "/usr/lib/vmware-sso/vmware-sts/webapps/websso/resources/img/$($_.name)" -GuestUser $VCSAOSUser -GuestPassword $VCSAOSPass -Force
        }
        write-verbose "Copying $Usetheme/login.css to /usr/lib/vmware-sso/vmware-sts/webapps/websso/resources/css/login.css"
        Get-Item "$Usetheme/login.css" | Copy-VMGuestFile -LocalToGuest -VM $VCVM -Destination "/usr/lib/vmware-sso/vmware-sts/webapps/websso/resources/css/login.css" -GuestUser $VCSAOSUser -GuestPassword $VCSAOSPass -Force
        write-verbose "Copying $Usetheme/unpentry.jsp to /usr/lib/vmware-sso/vmware-sts/webapps/websso/WEB-INF/views/unpentry.jsp"
        Get-Item "$Usetheme/unpentry.jsp" | Copy-VMGuestFile -LocalToGuest -VM $VCVM -Destination "/usr/lib/vmware-sso/vmware-sts/webapps/websso/WEB-INF/views/unpentry.jsp" -GuestUser $VCSAOSUser -GuestPassword $VCSAOSPass -Force
        Write-Host "Theme Uploaded!" -ForegroundColor Green
    }
}

$DeployLogFile = "/root/script.log"

. /root/config.ps1

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-File -Append -LiteralPath $DeployLogFile

Connect-VIServer -Server $VI_SERVER -User $VI_USERNAME -password $VI_PASSWORD | Out-File -Append -LiteralPath $DeployLogFile

Set-VCSATheme -Theme $VCSA_WEBCLIENT_THEME_NAME `
	-VCSAVM "Embedded-vCenter-Server-Appliance" `
    	-VCSAOSUser "root" `
    	-VCSAOSPass $VCSA_ROOT_PASSWORD `
    	-Verbose

Disconnect-VIServer * -confirm:$false | Out-File -Append -LiteralPath $DeployLogFile
