Param (
    [Parameter(Mandatory=$true)]
    [string]$DWB_InactiveEmployees_output_CSV,
   
)

#region FUNCTIONS

function Write-Log 
{ 
    [CmdletBinding()] 
    [OutputType([int])] 
    Param ( 
        # The string to be written to the log.
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,
 
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true, Position=3)]
        [ValidateSet("Error","Warn","Info")]
        [string]$Level="Info",

        [Parameter(Mandatory=$false)]
        [string]$LogFileName="Disable_ExistingUsers_in_AD"
    ) 
 
    $date = Get-Date -Format "ddMMyyyy"
    $subdate = Get-Date -Format "hhmmss_tt"
    $Path = "$PSScriptRoot\..\Logs\$date\$($LogFileName)_Log.txt"
 
    # If attempting to write to a log file in a folder/path that doesn't exist to create the file include path. 
    if (!(Test-Path $Path)) { 
        Write-Verbose "Creating $Path."
		$NewLogFile = New-Item $Path -Force -ItemType File 
    }

    $Message = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") $($Level): $Message"

    # Write message to console.
    Write-Output $Message

    # Write message to file.
    Write-Output $Message | Out-File -FilePath $Path -Append -Encoding ascii

    #Write-Host "The log file is saved at $Path" -ForegroundColor Green  
}

Write-Output ""




function Format-LastWorkingDate ($input_Date)
{
    $fullDate = $input_Date -split '-'
    Write-Host "$fullDate"
    $MonthName = $($fullDate)[1]
    [int]$day = $($fullDate[0])
    [int]$yr = "$($fullDate[2])"
    switch ($MonthName)
    {
        'Jan' {[int]$MonthNum = 01}
        'Feb' {[int]$MonthNum = 02}
        'Mar' {[int]$MonthNum = 03}
        'Apr' {[int]$MonthNum = 04}
        'May' {[int]$MonthNum = 05}
        'Jun' {[int]$MonthNum = 06}
        'Jul' {[int]$MonthNum = 07}
        'Aug' {[int]$MonthNum = 08}
        'Sep' {[int]$MonthNum = 09}
        'Oct' {[int]$MonthNum = 10}
        'Nov' {[int]$MonthNum = 11}
        'Dec' {[int]$MonthNum = 12}
    }

    if ($($fullDate[2]).length -eq 2)
    {
        [int]$yr = "20$($fullDate[2])"
    }

    return $(get-date -day $day -month $MonthNum -year $yr)
}

function Disable-ADFS_User ($DarwinBox_Unique_Id,$lastWorkingDate)
{
    Write-Output ""
    Write-Log "Checking if the user exists in ADFS or not"
    
    ## Check if the user exists in AD based on darwinBox unique user ID filter
    $AD_User = get-aduser -filter {extensionAttribute15 -eq $DWB_Info}

    ## If user found in ADFS
    if ($AD_User -ne $null)
    {
        Write-Log "Founded user with DarwinBox unique user Id set to $DWB_Infod"

        $ADFS_Date = Format-LastWorkingDate -input_Date $lastWorkingDate

        ## Filter users based on last working date from darwinBox
        if ($(Get-Date) -gt $($ADFS_Date.AddDays(+45)))
        {        
            Write-Log "Disabling account for the existing user with DarwinBox unique user Id set to  $DWB_Infod"
                  
            ## Disable the user and Update lastworking date extension attribute
            Set-ADUser -Identity $AD_User.samAccountName -Enabled $false -Replace @{'extensionAttribute14'= $lastWorkingDate}

            Write-Log "Account DISABLED successfully."
        }
        else
        {
            Write-Log "Skipping the disable operation for the existing user with DarwinBox unique user Id set to  $DWB_Infod"
        }
    }
    else
    {
        Write-Log "User with DarwinBox unique user Id set to  $DWB_Infod NOT FOUND in ADFS"
    }
}



#endregion

######################################################################################################

Write-Log "Script Execution Logs Start`n"

Write-Output ""
Write-Log "****************************************************************************************************"

Validate-ModuleDependencies

#region Connect to AzureAD using Service Principal



Write-Output ""
Write-Log "---------------------------------------------------------------------------"

#endregion

#region Execution

## Check if the Inactive Employees output CSV file exists
if (Test-Path $DWB_InactiveEmployees_output_CSV -PathType Leaf)
{    
    ## Check if the company domain input CSV file exists
   
        ## Step 1 - Read DarwinBox employees details from Inactive Employees CSV output
        Write-Output ""
        Write-Log "Reading Inactive DarwinBox employees info from output CSV file"
        $inactive_Emp_output = Import-Csv $DWB_InactiveEmployees_output_CSV
        
        ## Step 2 - Read the details for company and domain Info
        Write-Output ""
        Write-Log "Reading Domain and Company info from CSV file"
        $Domain_Info = Import-Csv $company_Domain_CSV

        Write-Output ""
        Write-Log "======================================================================================="

        if ($inactive_Emp_output -ne $null)
        {
            ## Step 3 - Loop through the Inactive Employees CSV output and Disable the users 1 day after the last working date 
            foreach ($DWB_Info in $inactive_Emp_output)
            {  
                try
                {
                    
                    Write-Output ""
                    Write-Log "DarwinBox Unique Id for User - $($DWB_Info.user_unique_id)"
                                         
                    #region Disable User in respective domain

                    Write-Output ""
                    Write-Log "Determining the domain type from the group company name"

                    ## Check whether domain is ADFS or Azure
                    $Domain_Type = ($Domain_Info | ?{$_.GroupCompany -eq $DWB_Info.group_company}).DomainType

                    ## Determine the user based on domain type
                      Write-Log "Domain Type - ADFS"
                        #Disable-ADFS_User -DarwinBox_Unique_Id $DWB_Info. -lastWorkingDate $DWB_Info.date_of_exit
                        if(flag == "Yes")
                        {
                            if ($AD_User -ne $null)
       {
        Write-Log "Founded user with DarwinBox unique user Id set to  $DWB_Info"

        $ADFS_Date = Format-LastWorkingDate -input_Date $lastWorkingDate

        ## Filter users based on last working date from darwinBox
        if ($(Get-Date) -gt $($ADFS_Date.AddDays(+45)))
        {        
            Write-Log "Disabling account for the existing user with DarwinBox unique user Id set to $DWB_Info"
                  
            ## Disable the user and Update lastworking date extension attribute
            Set-ADUser -Identity $AD_User.samAccountName -Enabled $false -Replace @{'extensionAttribute14'= $lastWorkingDate}

            Write-Log "Account DISABLED successfully."
        }

        ##Date of leaving will be updated in the AD 
                        #get-adcomputer -ldapfilter "(&(objectCategory=computer)(objectClass=computer)(useraccountcontrol:1.2.840.113556.1.4.803:=2))"|select Name, enabled


                        ## User account should be moved to a different intermediate OU

                        Get-ADUser -filter {Enabled -eq $False} -SearchBase 'OUDISTINGUISHEDNAME' -properties DisplayName, WhenChanged | Sort-Object DisplayName | Select-Object DisplayName, whenChanged
                         
                        # Changing password to something complex 

                        Add-Type -AssemblyName System.Web


                          # Generate random password
                        [System.Web.Security.Membership]::GeneratePassword(8,2)

                        }
                        else
                        {
                            if ($(Get-Date) -gt $($ADFS_Date.AddDays(+1)))
                             Write-Log "Disabling account for the existing user with DarwinBox unique user Id set to  $DWB_Info"
                  
            ## Disable the user and Update lastworking date extension attribute
            Set-ADUser -Identity $AD_User.samAccountName -Enabled $false -Replace @{'extensionAttribute14'= $lastWorkingDate}

            Write-Log "Account DISABLED successfully."
                        }
                        ##All group memberships should be removed for that account
                        $AzAD_Date = Format-LastWorkingDate -input_Date $lastWorkingDate
                        $SearchBase = "OU=Disabled Users,DC=contoso,DC=com"
                        $Users = Get-ADUser -filter * -SearchBase $SearchBase -Properties MemberOf
                        $ExcludeUsers =@("SM_82786dfdc96642ed9","SM_516a93b689334db1a")
                        $Users = $Users | where-Object { $ExcludeUsers -notcontains $_.samaccountname }
                        ForEach($User in $Users){
                        $User.MemberOf | Remove-ADGroupMember -Member $User -Confirm:$false
}
                        
                       


                      

                        ##Date of leaving will be updated in the AD 
                        get-adcomputer -ldapfilter "(&(objectCategory=computer)(objectClass=computer)(useraccountcontrol:1.2.840.113556.1.4.803:=2))"|select Name, enabled


                        ## User account should be moved to a different intermediate OU

                        Get-ADUser -filter {Enabled -eq $False} -SearchBase 'OUDISTINGUISHEDNAME' -properties DisplayName, WhenChanged | Sort-Object DisplayName | Select-Object DisplayName, whenChanged


                        ## Based on the forwarding email mentioned in the API, the emails from the disabled user will be forwarded to this user
                        
                        Set-Mailbox <Mailbox> -ForwardingAddress <Destination Recipient E-mail address>


                        
                                                                or


Set-Mailbox <Mailbox> -ForwardingsmtpAddress <Destination Recipient E-mail address>


                    ##  A week before the last working day, the max recipient number would be changed to 50 for those employees 


• In case the application finds users with invalid manager ID/email, an email alert is triggered to the IT & HR SPOC  

                    Write-Output ""
                    Write-Log "======================================================================================="

                    #endregion
                }
                catch
                {
                  Write-Log "Error for following employee $($DWB_Info.user_unique_id)"  
                }          
                
            }
        }
        else
        {
            Write-Log "The output CSV file for Inactive Employees CONTAINS NO RECORDS." -Level Warn
        }
    
    
}
else
{
    Write-Log "Inactive Employees Output CSV file NOT FOUND." -Level Error
}

Write-Output ""
Write-Output ""
Write-Log "****************************************************************************************************"
Write-Output ""
Write-Output ""

Write-Log "Script Execution Logs End `n`n"

#endregion

##################