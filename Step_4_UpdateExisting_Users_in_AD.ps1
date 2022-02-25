Param (
    [Parameter(Mandatory=$true)]
    [string]$DWB_ActiveEmployees_output_CSV
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
    if([System.String]::IsNullOrWhiteSpace($str))
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

function Disable-ADFS_User ($DarwinBox_Unique_Id,$lastWorkingDate)
{
    Write-Output ""
    Write-Log "Checking if the user exists in ADFS or not"
    
    ## Check if the user exists in AD based on darwinBox unique user ID filter
    $AD_User = get-aduser -filter {extensionAttribute15 -eq $DarwinBox_Unique_Id}

    ## If user found in ADFS
    if ($AD_User -ne $null)
    {
        Write-Log "Founded user with DarwinBox unique user Id set to $DarwinBox_Unique_Id"

        $ADFS_Date = Format-LastWorkingDate -input_Date $lastWorkingDate

        ## Filter users based on last working date from darwinBox
        if ($(Get-Date) -gt $($ADFS_Date.AddDays(+1)))
        {        
            Write-Log "Disabling account for the existing user with DarwinBox unique user Id set to $DarwinBox_Unique_Id"
                  
            ## Disable the user and Update lastworking date extension attribute
            Set-ADUser -Identity $AD_User.samAccountName -Enabled $false -Replace @{'extensionAttribute14'= $lastWorkingDate}

            Write-Log "Account DISABLED successfully."
        }
        else
        {
            Write-Log "Skipping the disable operation for the existing user with DarwinBox unique user Id set to $DarwinBox_Unique_Id"
        }
    }
    else
    {
        Write-Log "User with DarwinBox unique user Id set to $DarwinBox_Unique_Id NOT FOUND in ADFS"
    }
}

function Disable-AzureAD_User ($DarwinBox_Unique_Id,$lastWorkingDate)
{

    Write-Output ""
    Write-Log "Checking if the user exists in Azure AD or not"

    ## Check if the user exists in AD based on employeeId filter
    $AzAD_User = Get-AzureADUser -All $True | Where-Object `
                    { `
                        $_.extensionProperty.extension_a5dbd68e85c0469f91aa5e908a20b136_DarwinBox_UniqueID -eq "$DarwinBox_Unique_Id" `
                    } | Select-Object *

    ## If user found in Azure AD
    if ($AzAD_User -ne $null)
    {
        Write-Log "Founded user with DarwinBox unique user Id set to $DarwinBox_Unique_Id"

        $AzAD_Date = Format-LastWorkingDate -input_Date $lastWorkingDate

        ## Filter users based on last working date from darwinBox
        if ($(Get-Date) -gt $($AzAD_Date.AddDays(+45)))
        {
            Write-Log "Disabling account for the existing user with DarwinBox unique user Id set to $DarwinBox_Unique_Id"
                        
            ## Update details for the existing user by disabling the account
            Set-AzureADUser -ObjectId $AzAD_User.ObjectId -AccountEnabled $false

            ## Update lastworking date extension attribute
            Validate-ExtensionProperty -ext_Name "LastWorkingDate" -ext_Value $lastWorkingDate `
                                       -userObjectId $AzAD_User.ObjectId -appName 'Azure_AD_Connect'

            Write-Log "Account DISABLED successfully."
        }
        else
        {
            Write-Log "Skipping the disable operation for the existing user with DarwinBox unique user Id set to $DarwinBox_Unique_Id"
        }
    }
    else
    {
        Write-Log "USER with DarwinBox unique user Id set to $DarwinBox_Unique_Id NOT FOUND in AZURE AD"
    }
}



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
if(Test-Path $DWB_ActiveEmployees_output_CSV -PathType Leaf)
{
    ## Step 1 - Read DarwinBox employees details from Active Employees output CSV
        Write-Output ""
        Write-Log "Reading DarwinBox employees info from Active Employees output CSV file "
        $Active_Emp_output = @(Import-Csv $DWB_ActiveEmployees_output_CSV)


        Write-Output ""
        Write-Log "======================================================================================="
       

       if($Active_Emp_output -ne $null)
       {
            foreach($DWB_Info in $Pending_Emp_output)
            {
                try
                {
                    Write-Output ""
                    Write-Log "DarwinBox Employee Id for User - $($DWB_Info.employee_id)"

                    #region Map Variables

                    ## Map the variables between ADFS and DarwinBox
                    ##$ADFS_CostCenter = $AzureAD_extension_CostCenter = $DWB_Info.department_cost_center
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

                    #region Update

                    #region Update ADFS user

                    Write-Output ""
                    Write-Log "Checking if the user exists in ADFS or not"

                    $AD_EmpUser  = get-aduser -filter {employeeID -like $ADFS_EmployeeID}


                    ## Build extension attributes for update
                    $ext_Attributes = @{ 
                                    'extensionAttribute12' = $(ToNullIfWhiteSpace -str $ADFS_extensionAttribute12)
                                    'extensionAttribute13' = $(ToNullIfWhiteSpace -str $ADFS_extensionAttribute13)
                                    'extensionAttribute14' = $(ToNullIfWhiteSpace -str $ADFS_extensionAttribute14)
                                    'extensionAttribute15' = $(ToNullIfWhiteSpace -str $ADFS_extensionAttribute15)
                                    'CostCenter' = $(ToNullIfWhiteSpace -str $ADFS_CostCenter)
                                    'EmploymentStatus' = $(ToNullIfWhiteSpace -str $ADFS_EmploymentStatus)
                                    'locationType' = $(ToNullIfWhiteSpace -str $ADFS_locationType)
                                }


                    if($AD_EmpUser -ne $null)
                    {
                            Write-Log "User with DarwinBox employee user Id $ADFS_EmployeeID set to  already exists"

                            $DWB_Date = Format-LastWorkingDate -input_Date $ADFS_Modified
                            $DWB_Date

                            ## Filter users based on last modified date from darwinBox as one day before
                            if ($DWB_Date -gt (Get-Date).AddHours(-25))
                            {
                                Write-Log "Updating details for the existing user with employee ID $ADFS_EmployeeID"

                                $ADFS_args_update = @{   
	                                Company = $(ToNullIfWhiteSpace -str $ADFS_Company)
                                    Department = $(ToNullIfWhiteSpace -str $ADFS_Department)
                                    EmployeeID = $(ToNullIfWhiteSpace -str $ADFS_EmployeeID)
                                    Enabled = $true
                                    GivenName = $(ToNullIfWhiteSpace -str $ADFS_GivenName)
                                    Identity = $AD_EmpUser.SamAccountName
                                    Surname = $(LastToNullIfWhiteSpace -str $ADFS_sn)
                                    Title = $(ToNullIfWhiteSpace -str $ADFS_Title)
                                    SamAccountName = $AD_User.SamAccountName
                                    DisplayName = $("$ADFS_GivenName" + " " + "$ADFS_sn")
                                }

                                ## Check if the manager property returned from DarwinBox is not null
                                $mgr = $(ToNullIfWhiteSpace -str $ADFS_manager_uniqueID)

                                if ($mgr_1 -ne 'null')
                                {
                                    $found = Validate-ADFS_UserManager -manager_empID $ADFS_manager_uniqueID
                                    Write-Log "manager info $found"
                                    if ($found -ne $null)
                                    {         
                                        $ADFS_args_create.Add("Manager","$found")     
                                    }                         
                                }


                                ## Update details for the existing use0r
                                Set-ADUser @ADFS_args_update -Replace $ext_Attributes

                                Write-Log "User details updated successfully"
                            }
                            else
                            {
                                Write-Log "Update operation will be skipped for the existing user with employee ID $ADFS_EmployeeID as it wasn't modified a day before."
                            }
                    }
                    else
                    {
                        Write-Log "This employee ID $ADFS_EmployeeID is are not exists"
                        Write-Log "User with DarwinBox employee id  Id set to $ADFS_EmployeeID not exists"
                    }




                }
                catch
                {
                    Write-Log "The error are come for Update  employee $ADFS_extensionAttribute15"
                    Write-Log "The error are come for Update  employee $($SAM.NewSAM)"
                    Write-Log "The error of $($Error[0].Exception)"
                }
            }

       }
       else
       {
            Write-Log "The output CSV file for Active Employees CONTAINS NO RECORDS." -Level Warn
       }

}
else
{
    Write-Log "Active Employees Output CSV file NOT FOUND at ." -Level Error
}


