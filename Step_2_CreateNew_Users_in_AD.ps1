Param (
    [Parameter(Mandatory=$true)]
    [string]$DWB_admin_Email,
    [Parameter(Mandatory=$true)]
    [string]$DWB_secret,
    [Parameter(Mandatory=$true)]
    [string]$DWB_UID,
    [Parameter(Mandatory=$true)]
    [string]$DWB_PendingEmployees_output_CSV,
    [Parameter(Mandatory=$true)]
    [string]$Monitor_Users_output_CSV,
    [Parameter(Mandatory=$true)]
    $newUser_Pwd
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
        [string]$LogFileName="Create_Or_Update_Users_in_AD"
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
    Write-Output $Message | Out-File -FilePath $Path -Append -Encoding ascii -Force

    #Write-Host "The log file is saved at $Path" -ForegroundColor Green  
}


function ToNullIfWhiteSpace ($str)
{
	if ([System.String]::IsNullOrWhiteSpace($str)) 
    {
		$str = 'null'
	}	
	return $str
}


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


function Validate-ModuleDependencies
{
    ## Check if  AD PowerShell module is installed. ##
    ## If not, install all modules/dependencies required for successful execution of the script. ##

    Write-Output ""
    Write-Log "Validating module dependencies for the script..."

    #-- Check & Install the ActiveDirectory module --#
    if ((Get-Module -Name "ActiveDirectory" -ListAvailable) -eq $null)
    {
        Write-Log "Installing module ActiveDirectory"
        Install-Module -Name "ActiveDirectory" -AllowClobber -Force
    }
    ## Check & Install the Msonline Module
    if ((Get-Module -Name "ActiveDirectory" -ListAvailable) -eq $null))
    {
        Find-Module -Name MSOnline | Install-Module -Force
    }
    #-- Import the module to use in the script --#
    Import-Module -Name "ActiveDirectory"
    Import-Module MSOnline


    Write-Log "All dependencies validated successfully. Proceeding with the other steps..."
    Write-Output ""
    Write-Log "---------------------------------------------------------------------------"
    Write-Output ""
}


function Validate-ADFS_SamAccountName ($samaccountName,$Name)
{
    $final_sam = $samaccountName
    
    $new_name = $Name

    $random_number = ( Get-Random -Minimum 0 -Maximum 99999 ).ToString('00000')
    
    $sam_check = get-aduser -filter { samAccountName -eq $samaccountName }
    

    if ($sam_check -ne $null)
    {
        $final_sam = $($samaccountName.Substring( 0, $samaccountName.Length - $($random_number.ToString().Length))) + "$random_number"
        $new_name = $Name + "$random_number"
        
    }

    $op_obj = New-Object psobject
    $op_obj | Add-Member -MemberType NoteProperty -Name "NewName" -Value $new_name
    $op_obj | Add-Member -MemberType NoteProperty -Name "NewSAM" -Value $final_sam

    return $op_obj
}

function Validate-Email_Address($Name)

{
    $domain = "@1eQ.com"
    $name = $Name

    $email = "$name$domain"
    Get-AdUser -Filter "email -like 'Shanza'"

    return $email
}

function Validate-ADFS_UserManager ($manager_empID)
{
    $mgr_Identity = $null
    $mgr_info  = get-aduser -filter {employeeID -eq $manager_empID}

    if ($mgr_info -ne $null)
    {
        $mgr_Identity = $mgr_info

    }

    return $mgr_Identity
}

####function for assing the licenses
#function Assign-License
#{
 #   Import-Module MSOnline
  #  $Credential = Get-Credential
   # Connect-MsolService -Crendential $Credential

#}


############################end function licenses


######## Function for update email id in darwin box
function Update-Employee_MailAddress
{
    [CmdletBinding()] 
    Param (
        ## DarwinBox admin Email
        [Parameter(Mandatory=$true)]
        [string]$admin_Email,
        ## DarwinBox secret Key
        [Parameter(Mandatory=$true)]
        [string]$secretKey,
        ## DarwinBox UID
        [Parameter(Mandatory=$true)]
        [string]$UID,
        ## Unique ID of the DarwinBox user
        [Parameter(Mandatory=$true)]
        [string]$employee_id,
        ## Employee ID of the user
        [Parameter(Mandatory=$true)]
        [string]$employee_Email
    )

    try 
    {
        ## Get current epoch timestamp in seconds
        $timestamp = [long] (Get-Date -Date ((Get-Date).ToUniversalTime()) -UFormat %s)

        ## Generate hash
        $mixedString = $admin_Email + $secretKey + $timestamp
        $computedHash = Get-StringHash -inputString $mixedString

        ## Request headers
        $req_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $req_headers.Add("Content-Type", "application/json")

        ## Request body
        $req_body = @"
        {
            "Uid":"$UID",
            "hash":"$computedHash",
            "timestamp":"$timestamp",
            "employee_id":"$employee_id",
            "email_id":"$employee_Email"
        }
"@

        ## API call to get all employees
        $api_URL = "https:///UpdateEmployeeDetails/update"
        $response = Invoke-RestMethod -Uri $api_URL -Method POST -Headers $req_headers -Body $req_body
        return $response
    }
    catch
    {        
        $err_msg = "Error while updating DarwinBox employee with Employee Id - $employee_id `n Error Message : $_"
        Write-Log $err_msg      
    }
}

#####################end function 


#endregion

######################################################################################################

Write-Log "Script Execution Logs Start`n"

Write-Output ""
Write-Log "****************************************************************************************************"



Write-Output ""
Write-Log "---------------------------------------------------------------------------"

#endregion

#region Execution

## Check if the Active Employees output CSV file exists
if (Test-Path $DWB_PendingEmployees_output_CSV -PathType Leaf)
{
    ## Step 1 - Read DarwinBox employees details from Pending Employees output CSV
        Write-Output ""
        Write-Log "Reading DarwinBox employees info from Pending Employees output CSV file "
        $Pending_Emp_output = @(Import-Csv $DWB_PendingEmployees_output_CSV)


        Write-Output ""
        Write-Log "======================================================================================="
        

        if($Pending_Emp_output -ne $null)
        {
            foreach($DWB_Info in $Pending_Emp_output)
            {
                try
                {
                Write-Output ""
                Write-Log "DarwinBox Employee Id for User - $($DWB_Info.employee_id)"

                #region Map Variables

                ## Map the variables between ADFS and DarwinBox
               
                $ADFS_Company =  $DWB_Info.group_company
                $ADFS_Department = $DWB_Info.department_name
                $ADFS_EmployeeID = $DWB_Info.employee_id
                $ADFS_EmploymentStatus = $DWB_Info.employee_type
                $ADFS_CN = $DWB_Info.full_name
                $ADFS_locationType = $DWB_Info.location_type
                $ADFS_Manager = $DWB_Info.direct_manager_name
                $ADFS_GivenName = $DWB_Info.first_name
                $ADFS_sn = $DWB_Info.last_name
                $ADFS_Title = $DWB_Info.designation_name
                $ADFS_extensionAttribute12 = $DWB_Info.business_unit
                $ADFS_extensionAttribute13 = $DWB_Info.date_of_joining
                $ADFS_extensionAttribute14 = $DWB_Info.date_of_exit
                ##$ADFS_extensionAttribute15 = $DWB_Info.user_unique_id
                $ADFS_Modified = $DWB_Info.latest_modified_any_attribute
                $ADFS_samaccountname =  $DWB_Info.first_name_last_name
                $ADFS_manager_uniqueID = $DWB_Info.direct_manager_employee_id
                $ADFS_gender = $DWB_Info.gender
                $AD_User = $DWB_Info.users
                $ADFS_Date = $lastWorkingDate.disabled_users
                $DWB_InactiveEmployees_output_CSV=$DWB_Info.inactive_employees
                $inactive_Emp_output=$DWB_Info.inactive_users
                $ADFS_disable_users = $DWB_Info.disable_users


                #region Create

                #region Create ADFS user

                 Write-Output ""
                 Write-Log "Checking if the user exists in ADFS or not"

                 $AD_EmpUser  = get-aduser -filter {employeeID -like $ADFS_EmployeeID}

                 $SAM_temp = "$ADFS_GivenName$ADFS_sn" -replace ' ',''
                 $SAM = $SAM_temp[0..19] -join ''
                 Write-Log "working $SAM"
                 $SAM = Validate-ADFS_SamAccountName -samaccountName $SAM -Name $ADFS_CN

                 $Email_temp = "$ADFS_GivenName.$ADFS_sn" -replace ' ',''
                 $Email = Validate-Email_Address -Name $Email_temp

                 ### To set password
                 #$PasswordProfile=New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
                 #$PasswordProfile.Password="<user account password>"
                 #New-AzureADUser -DisplayName "<display name>" -GivenName "<first name>" -SurName "<last name>" -UserPrincipalName <sign-in name> -UsageLocation <ISO 3166-1 alpha-2 country code> -MailNickName <mailbox name> -PasswordProfile $PasswordProfile -AccountEnabled $true
                 #############
                 if($AD_EmpUser -eq $null)
                 {
                    Write-Log "account name $($SAM.NewSAM)"

                    $ADFS_args_create = @{
                        Company = $(ToNullIfWhiteSpace -str $ADFS_Company)
                        Department = $(ToNullIfWhiteSpace -str $ADFS_Department)
                        EmployeeID = $(ToNullIfWhiteSpace -str $ADFS_EmployeeID)
                        Enable = $true
                        Name = $SAM.NewName
                        GiveName = $(ToNullIfWhiteSpace -str $ADFS_GivenName)
                        Surname = $(ToNullIfWhiteSpace -str $ADFS_sn)
                        Title = $(ToNullIfWhiteSpace -str $ADFS_Title)
                        SamAccountName = $SAM.NewSAM
                        Mail = $Email
                        Path = ''
                        DiplayName = $("$ADFS_GivenName" + " " + "$ADFS_sn")
                        OtherAtrributes = @{
                             'extensionAttribute12' = $(ToNullIfWhiteSpace -str $ADFS_extensionAttribute12)
                             'extensionAttribute13' = $(ToNullIfWhiteSpace -str $ADFS_extensionAttribute13)
                             'extensionAttribute14' = $(ToNullIfWhiteSpace -str $ADFS_extensionAttribute14)
                            # 'extensionAttribute15' = $(ToNullIfWhiteSpace -str $ADFS_extensionAttribute15)
                             'CostCenter' = $(ToNullIfWhiteSpace -str $ADFS_CostCenter)
                             'EmploymentStatus' = $(ToNullIfWhiteSpace -str $ADFS_EmploymentStatus)
                             'locationType' = $(ToNullIfWhiteSpace -str $ADFS_locationType)
                        }

                    }

                    ## Check if the manager property returned from DarwinBox is not null
                    $mgr_1 = $(ToNullIfWhiteSpace -str $ADFS_manager_uniqueID)
                                
                    if ($mgr_1 -ne 'null')
                    {
                      $found = Validate-ADFS_UserManager -manager_empID $ADFS_manager_uniqueID
                       Write-Log "manager info $found"
                       if ($found -ne $null)
                       {         
                            $ADFS_args_create.Add("Manager","$found")     
                       }                         
                    }

                    New-ADUser @ADFS_args_create

                    ## logic for security groups 

                    if($ADFS_gender -eq 'Female')
                    {
                        Write-Log ""
                        Add-AdGroupMember -Identity groupname -Members Samaccountanme

                    }
                    else
                    {
                        
                    }

                    ############# END THE LOGIC FOR SECURITY GROUPs

                    

                    ### updating the email id in darwin box

                      ## Update mail address for the user in DarwinBox
                        Write-Log "################################"
                        Write-Log "Update mail address for the user in DarwinBox"
                        $ADFS_updateResult = Update-Employee_MailAddress -admin_Email $DWB_admin_Email -UID $DWB_UID `
                                                                    -secretKey $DWB_secret -employee_id $ADFS_EmployeeID`
                                                                    -employee_Email $Email

                        if ($ADFS_updateResult.message -eq "Employee Data Updated Successfully")
                        {
                            Write-Log "Mail address has been updated in DarwinBox for the user with Employee ID $ADFS_EmployeeID"
                        }
                        else
                        {
                            Write-Log "Email Update operation failed for the ADFS user with employee ID $ADFS_EmployeeID with the ERROR message - $ADFS_updateResult"
                        }
                        Write-Log "###############################################"
                                        

                    ############################## end the update email 


                    #### #################################### Assign the  M365 E3 license
                    try
                    {
                        Write-Log "Assign the  M365 E3 license  for the employee Id $ADFS_EmployeeID"
                        $user_ad = get-aduser -filter {employeeID -eq $ADFS_EmployeeID}
                        $UPN = $password_user.UserPrincipalName
                        $Assign_license = Set-MsolUserLicense -UserPrincipalName $UPN -AddLicenses "litwareinc:ENTERPRISEPACK"
                        Write-Log "Assign the  M365 E3 license  for the employee Id $ADFS_EmployeeID are successfully"
                    } 
                    catch 
                    {
                   
                        Write-Log "Assign the M365 E3 license operation failed for the user with employee ID $ADFS_EmployeeID with the ERROR message - $Assign_license"
                    }
       

                    ########################################## end Assign the license

                  }
                    
                 else
                 {
                    Write-Log "This employee is already exits $($AD_EmpUser.SamAccountName)"
                    Write-Log "User with DarwinBox employee id  Id set to $ADFS_EmployeeID already exists"
                 }  
            
            }
            catch
            {
                Write-Log "The error are come for new  employee $ADFS_extensionAttribute15"
                Write-Log "The error are come for new  employee $($SAM.NewSAM)"
                Write-Log "The error of $($Error[0].Exception)"
             }
          }
        }
        else
        {
            Write-Log "The output CSV file for Pending Employees CONTAINS NO RECORDS." -Level Warn
        }



}
else
{
    Write-Log "Pending Employees Output CSV file NOT FOUND at ." -Level Error
}