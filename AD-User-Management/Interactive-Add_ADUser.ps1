#Requires -Module ActiveDirectory
#Requires -Version 3.0

<#
.SYNONOPSIS
    Interactive Active Directory User Creation Tool
.DESCRIPTION
    A comprehensive PowerShell script for creating Active Directory users from CSV files.
    Features interactive file selection, dynamic column mapping, and robust error handling.
.PARAMETER None
    This script uses interactive prompts for all configuration.
.EXAMPLE
    .\Interactive-Add_ADUser.ps1
.NOTES
    Author: NewLouwa
    GitHub: https://github.com/NewLouwa
    Version: 1.0
    Last Modified: 2025
#>

#region Helper Functions

function Remove-Accents {
    <#
    .SYNOPSIS
        Removes accent characters from a string
    .DESCRIPTION
        Normalizes text by removing diacritical marks and special characters
    .PARAMETER text
        The input string to clean
    .RETURNS
        Cleaned string without accents
    #>
    param([string]$text)
    
    if ([string]::IsNullOrEmpty($text)) { return $text }
    
    # Normalize to decomposed form (NFD) for better character handling
    $normalizedText = $text.Normalize([Text.NormalizationForm]::FormD)
    
    # Remove all non-basic Latin characters (accents, special chars)
    return ($normalizedText -replace '[^\p{IsBasicLatin}]', '')
}

function New-RandomPassword {
    <#
    .SYNOPSIS
        Generates a random password meeting complexity requirements
    .DESCRIPTION
        Creates a secure random password with specified length and complexity options.
        Ensures at least one of each character type (uppercase, lowercase, digits, special).
    .PARAMETER length
        The desired length of the password (default: 12)
    .PARAMETER includeSpecial
        Whether to include special characters (default: true)
    .RETURNS
        A secure random password string meeting complexity requirements
    #>
    param(
        [int]$length = 12,
        [bool]$includeSpecial = $true
    )
    
    # Define character sets for password generation
    $charsets = @{
        UpperCase = [char[]](65..90)    # A-Z
        LowerCase = [char[]](97..122)   # a-z
        Digits = [char[]](48..57)       # 0-9
        Special = [char[]]"!@#$%^&*()_-+=<>?"
    }
    
    # Ensure at least one of each required character type
    $password = @(
        $charsets.UpperCase | Get-Random
        $charsets.LowerCase | Get-Random
        $charsets.Digits | Get-Random
    )
    
    # Add special character if requested
    if ($includeSpecial) {
        $password += $charsets.Special | Get-Random
    }
    
    # Create pool of all possible characters
    $allChars = @()
    $allChars += $charsets.UpperCase
    $allChars += $charsets.LowerCase
    $allChars += $charsets.Digits
    
    if ($includeSpecial) {
        $allChars += $charsets.Special
    }
    
    # Fill remaining length with random characters
    while ($password.Count -lt $length) {
        $password += $allChars | Get-Random
    }
    
    # Shuffle all characters for better randomness
    $password = $password | Get-Random -Count $password.Count
    return -join $password
}

#endregion

#region Main Function

function Import-ADUsers {
    [CmdletBinding()]
    param()
    
    # Display welcome banner
    Write-Host "`n===============================================" -ForegroundColor Cyan
    Write-Host "  ACTIVE DIRECTORY USER IMPORTATION TOOL" -ForegroundColor Cyan
    Write-Host "===============================================`n" -ForegroundColor Cyan
    
    #region Module Verification
    
    # Verify Active Directory module is loaded
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
    }
    catch {
        Write-Host "ERROR: Unable to load ActiveDirectory module." -ForegroundColor Red
        Write-Host "Please ensure RSAT tools are installed on this computer." -ForegroundColor Red
        return
    }
    
    #endregion
    
    #region CSV File Selection
    
    # Create file browser dialog for CSV selection
    Add-Type -AssemblyName System.Windows.Forms
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $FileBrowser.Title = "Select CSV file containing user data"
    $FileBrowser.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
    $FileBrowser.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    
    if ($FileBrowser.ShowDialog() -ne 'OK') {
        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
        return
    }
    
    $CSVFile = $FileBrowser.FileName
    
    # Verify file exists and is accessible
    if (-not (Test-Path -Path $CSVFile -PathType Leaf)) {
        Write-Host "ERROR: File '$CSVFile' does not exist or is not accessible." -ForegroundColor Red
        return
    }
    
    #endregion
    
    #region CSV Configuration
    
    # Detect CSV delimiter automatically by analyzing first line
    $firstLine = Get-Content -Path $CSVFile -TotalCount 1 -Encoding UTF8
    $possibleDelimiters = @(";", ",", "`t", "|")
    $detectedDelimiter = $null
    $maxColumnCount = 0
    
    foreach ($delimiter in $possibleDelimiters) {
        $columnCount = ($firstLine -split $delimiter).Count
        if ($columnCount -gt $maxColumnCount) {
            $maxColumnCount = $columnCount
            $detectedDelimiter = $delimiter
        }
    }
    
    # Get delimiter confirmation from user with default value
    $defaultDelimiter = $detectedDelimiter
    $delimiterInput = Read-Host "Enter CSV delimiter [$defaultDelimiter]"
    $delimiter = if ([string]::IsNullOrEmpty($delimiterInput)) { $defaultDelimiter } else { $delimiterInput }
    
    # Define available encoding options
    $encodingOptions = @{
        "1" = "UTF8"
        "2" = "Unicode"
        "3" = "UTF7"
        "4" = "UTF32"
        "5" = "ASCII"
        "6" = "BigEndianUnicode"
        "7" = "Default"
        "8" = "OEM"
    }
    
    # Display encoding options and get user selection
    Write-Host "`nSelect CSV file encoding:" -ForegroundColor Cyan
    foreach ($key in $encodingOptions.Keys | Sort-Object) {
        Write-Host "$key. $($encodingOptions[$key])"
    }
    
    $encodingChoice = Read-Host "`nChoose encoding [1]"
    if ([string]::IsNullOrEmpty($encodingChoice)) { $encodingChoice = "1" }
    $encodingName = $encodingOptions[$encodingChoice]
    
    if ([string]::IsNullOrEmpty($encodingName)) {
        Write-Host "Invalid choice. Using UTF8 by default." -ForegroundColor Yellow
        $encodingName = "UTF8"
    }
    
    # Create encoding object based on selection
    $encoding = switch ($encodingName) {
        "UTF8" { [System.Text.Encoding]::UTF8 }
        "Unicode" { [System.Text.Encoding]::Unicode }
        "UTF7" { [System.Text.Encoding]::UTF7 }
        "UTF32" { [System.Text.Encoding]::UTF32 }
        "ASCII" { [System.Text.Encoding]::ASCII }
        "BigEndianUnicode" { [System.Text.Encoding]::BigEndianUnicode }
        "Default" { [System.Text.Encoding]::Default }
        "OEM" { [System.Text.Encoding]::GetEncoding(850) }
    }
    
    # Import CSV with specified parameters
    try {
        $CSVData = Import-Csv -Path $CSVFile -Delimiter $delimiter -Encoding $encoding
    }
    catch {
        Write-Host "ERROR: Unable to import CSV file. Please verify delimiter and encoding." -ForegroundColor Red
        Write-Host "Error details: $_" -ForegroundColor Red
        return
    }
    
    # Verify data was imported successfully
    if ($CSVData.Count -eq 0) {
        Write-Host "WARNING: CSV file contains no data." -ForegroundColor Yellow
        $continue = Read-Host "Do you want to continue anyway? (Y/N)"
        if ($continue -ne "Y") {
            return
        }
    }
    
    #endregion
    
    #region AD Attribute Mapping
    
    # Get CSV column names for mapping
    $csvColumns = $CSVData[0].PSObject.Properties.Name
    
    Write-Host "`nColumns detected in CSV file:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $csvColumns.Count; $i++) {
        Write-Host "  $($i+1). $($csvColumns[$i])"
    }
    
    # Define AD attributes for mapping with required flags
    $adAttributes = @(
        @{Name="First Name"; ADAttribute="GivenName"; Required=$true},
        @{Name="Last Name"; ADAttribute="Surname"; Required=$true},
        @{Name="Display Name"; ADAttribute="DisplayName"; Required=$false},
        @{Name="Login (SAM Account Name)"; ADAttribute="SamAccountName"; Required=$true},
        @{Name="Email Address"; ADAttribute="EmailAddress"; Required=$false},
        @{Name="Title/Position"; ADAttribute="Title"; Required=$false},
        @{Name="Department"; ADAttribute="Department"; Required=$false},
        @{Name="Phone"; ADAttribute="OfficePhone"; Required=$false},
        @{Name="Mobile"; ADAttribute="MobilePhone"; Required=$false},
        @{Name="Company"; ADAttribute="Company"; Required=$false},
        @{Name="Office/Site"; ADAttribute="Office"; Required=$false},
        @{Name="Address"; ADAttribute="StreetAddress"; Required=$false},
        @{Name="City"; ADAttribute="City"; Required=$false},
        @{Name="State/Province"; ADAttribute="State"; Required=$false},
        @{Name="Postal Code"; ADAttribute="PostalCode"; Required=$false},
        @{Name="Country"; ADAttribute="Country"; Required=$false},
        @{Name="Description"; ADAttribute="Description"; Required=$false},
        @{Name="Web Page"; ADAttribute="HomePage"; Required=$false},
        @{Name="Employee ID"; ADAttribute="EmployeeID"; Required=$false},
        @{Name="Manager"; ADAttribute="Manager"; Required=$false}
    )
    
    # Initialize mapping dictionary and get required mappings
    $columnMapping = @{}
    $requiredMappings = $adAttributes | Where-Object { $_.Required -eq $true }
    
    Write-Host "`nMap CSV columns to Active Directory attributes" -ForegroundColor Cyan
    Write-Host "Attributes marked (*) are required" -ForegroundColor Yellow
    
    # Get user input for each attribute mapping
    foreach ($attribute in $adAttributes) {
        $requiredMark = if ($attribute.Required) { "*" } else { "" }
        
        Write-Host "`n$($attribute.Name)$requiredMark :" -ForegroundColor $(if ($attribute.Required) {"Yellow"} else {"Cyan"})
        for ($i = 0; $i -lt $csvColumns.Count; $i++) {
            Write-Host "  $($i+1). $($csvColumns[$i])"
        }
        Write-Host "  0. Skip this attribute"
        
        # Validate user input
        $validInput = $false
        do {
            $choice = Read-Host "Choose corresponding number (0-$($csvColumns.Count))"
            
            if ([string]::IsNullOrEmpty($choice)) {
                $choice = "0" # Skip by default
            }
            
            $choiceNum = 0
            if ([int32]::TryParse($choice, [ref]$choiceNum) -and $choiceNum -ge 0 -and $choiceNum -le $csvColumns.Count) {
                $validInput = $true
                
                if ($choiceNum -gt 0) {
                    $columnMapping[$attribute.ADAttribute] = $csvColumns[$choiceNum-1]
                }
            }
            else {
                Write-Host "Invalid input. Please enter a number between 0 and $($csvColumns.Count)." -ForegroundColor Red
            }
        } while (-not $validInput)
    }
    
    # Verify required mappings are present
    $missingRequiredMappings = $requiredMappings | Where-Object { -not $columnMapping.ContainsKey($_.ADAttribute) }
    if ($missingRequiredMappings.Count -gt 0) {
        Write-Host "`nERROR: Required attributes are not mapped:" -ForegroundColor Red
        foreach ($missing in $missingRequiredMappings) {
            Write-Host "  - $($missing.Name)" -ForegroundColor Red
        }
        
        $forceContinue = Read-Host "Do you want to continue anyway? (Y/N)"
        if ($forceContinue -ne "Y") {
            return
        }
    }
    
    # Verify mapped columns exist in CSV data
    foreach ($key in $columnMapping.Keys) {
        $colName = $columnMapping[$key]
        if (-not $CSVData[0].PSObject.Properties.Name.Contains($colName)) {
            Write-Host "WARNING: Column '$colName' mapped to '$key' does not exist in CSV!" -ForegroundColor Yellow
        }
    }
    
    #endregion
    
    #region User Creation Configuration
    
    # Get domain information for user creation
    try {
        $ADDomain = Get-ADDomain
        $Domaine = $ADDomain.DNSRoot
        $DomaineDN = $ADDomain.DistinguishedName
    }
    catch {
        Write-Host "ERROR: Unable to retrieve domain information." -ForegroundColor Red
        Write-Host "Details: $_" -ForegroundColor Red
        return
    }
    
    # Configure login name generation if not mapped
    Write-Host "`nConfigure login name generation:" -ForegroundColor Cyan
    if (-not $columnMapping.ContainsKey("SamAccountName")) {
        $loginOptions = @(
            "1. First letter of first name + last name (fname)",
            "2. First name + first letter of last name (firstl)",
            "3. First name.last name",
            "4. Last name.first name",
            "5. First name_last name",
            "6. Last name_first name",
            "7. Custom format..."
        )
        
        foreach ($option in $loginOptions) {
            Write-Host $option
        }
        
        $loginChoice = Read-Host "Choose an option [1]"
        if ([string]::IsNullOrEmpty($loginChoice)) { $loginChoice = "1" }
        
        $loginFormat = switch ($loginChoice) {
            "1" { "fname" }
            "2" { "firstl" }
            "3" { "first.last" }
            "4" { "last.first" }
            "5" { "first_last" }
            "6" { "last_first" }
            "7" { Read-Host "Enter custom format (use {first} and {last} as variables)" }
            default { "fname" }
        }
    }
    
    # Select target OU for user creation
    Write-Host "`nSelect OU for user creation:" -ForegroundColor Cyan
    $OUOptions = @(
        @{Name="Default OU (Domain Users)"; Path="CN=Users,$DomaineDN"},
        @{Name="Select existing OU"; Path=$null},
        @{Name="Enter OU path manually"; Path=$null}
    )
    
    foreach ($i in 1..$OUOptions.Count) {
        Write-Host "$i. $($OUOptions[$i-1].Name)"
    }
    
    $OUChoice = Read-Host "Choose an option [1]"
    if ([string]::IsNullOrEmpty($OUChoice)) { $OUChoice = "1" }
    
    switch ($OUChoice) {
        "1" {
            $OUPath = $OUOptions[0].Path
        }
        "2" {
            # List available OUs for selection
            $OUs = Get-ADOrganizationalUnit -Filter * | Select-Object -Property Name, DistinguishedName | Sort-Object -Property DistinguishedName
            Write-Host "`nAvailable OUs:"
            for ($i = 0; $i -lt $OUs.Count; $i++) {
                Write-Host "  $($i+1). $($OUs[$i].DistinguishedName)"
            }
            
            $OUIndex = Read-Host "Enter OU number"
            if ([int]::TryParse($OUIndex, [ref]$null) -and [int]$OUIndex -ge 1 -and [int]$OUIndex -le $OUs.Count) {
                $OUPath = $OUs[[int]$OUIndex-1].DistinguishedName
            }
            else {
                Write-Host "Invalid selection. Using default OU." -ForegroundColor Yellow
                $OUPath = $OUOptions[0].Path
            }
        }
        "3" {
            $OUPath = Read-Host "Enter complete OU path (ex: OU=MyOU,DC=domain,DC=local)"
            # Verify OU exists or create if needed
            try {
                Get-ADOrganizationalUnit -Identity $OUPath -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Host "Specified OU does not exist. Creating new OU..." -ForegroundColor Yellow
                try {
                    # Extract OU name and parent path
                    $OUName = ($OUPath -split ',')[0] -replace 'OU=',''
                    $ParentPath = $OUPath -replace "^OU=$OUName,", ''
                    New-ADOrganizationalUnit -Name $OUName -Path $ParentPath
                    Write-Host "OU created successfully." -ForegroundColor Green
                }
                catch {
                    Write-Host "Unable to create OU. Using default OU." -ForegroundColor Red
                    $OUPath = $OUOptions[0].Path
                }
            }
        }
        default {
            $OUPath = $OUOptions[0].Path
        }
    }
    
    # Configure password settings
    Write-Host "`nConfigure password settings:" -ForegroundColor Cyan
    $passwordOptions = @(
        "1. Same password for all users",
        "2. Random password for each user",
        "3. Use CSV column as password"
    )
    
    foreach ($option in $passwordOptions) {
        Write-Host $option
    }
    
    $passwordChoice = Read-Host "Choose an option [1]"
    if ([string]::IsNullOrEmpty($passwordChoice)) { $passwordChoice = "1" }
    
    $passwordType = switch ($passwordChoice) {
        "1" {
            $staticPassword = Read-Host "Enter password to use for all users" -AsSecureString
            "static"
        }
        "2" {
            $passwordLength = Read-Host "Enter password length [12]"
            if ([string]::IsNullOrEmpty($passwordLength)) { $passwordLength = 12 }
            $passwordLength = [int]$passwordLength
            $includeSpecialChars = (Read-Host "Include special characters? (Y/N) [Y]") -ne "N"
            "random"
        }
        "3" {
            Write-Host "`nSelect column containing passwords:"
            for ($i = 0; $i -lt $csvColumns.Count; $i++) {
                Write-Host "  $($i+1). $($csvColumns[$i])"
            }
            $passwordColumn = Read-Host "Enter column number"
            $passwordColumnName = $csvColumns[[int]$passwordColumn-1]
            "csv"
        }
        default { 
            $staticPassword = ConvertTo-SecureString "Welcome1!" -AsPlainText -Force
            "static" 
        }
    }
    
    # Configure additional user settings
    $forcePasswordChange = (Read-Host "Force password change at first logon? (Y/N) [Y]") -ne "N"
    $enableUsers = (Read-Host "Enable user accounts immediately? (Y/N) [Y]") -ne "N"
    $addToGroups = (Read-Host "Add users to groups? (Y/N) [N]") -eq "Y"
    
    # Initialize group mode with default value
    $groupMode = "static"
    
    # Configure group settings if enabled
    if ($addToGroups) {
        $groupOptions = @(
            "1. Use CSV column as group",
            "2. Add all users to specific group"
        )
        
        foreach ($option in $groupOptions) {
            Write-Host $option
        }
        
        $groupChoice = Read-Host "Choose an option [1]"
        if ([string]::IsNullOrEmpty($groupChoice)) { $groupChoice = "1" }
        
        switch ($groupChoice) {
            "1" {
                Write-Host "`nSelect column containing groups:"
                for ($i = 0; $i -lt $csvColumns.Count; $i++) {
                    Write-Host "  $($i+1). $($csvColumns[$i])"
                }
                $groupColumn = Read-Host "Enter column number"
                $groupColumnName = $csvColumns[[int]$groupColumn-1]
                $groupMode = "csv"
            }
            "2" {
                $staticGroup = Read-Host "Enter group name to add all users to"
                # Verify group exists or create if needed
                if (-not (Get-ADGroup -Filter "Name -eq '$staticGroup'" -ErrorAction SilentlyContinue)) {
                    $createGroup = Read-Host "Group '$staticGroup' does not exist. Create it? (Y/N)"
                    if ($createGroup -eq "Y") {
                        try {
                            New-ADGroup -Name $staticGroup -GroupScope Global -GroupCategory Security
                            Write-Host "Group '$staticGroup' created successfully." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Error creating group. Users will not be added to any group." -ForegroundColor Red
                            $addToGroups = $false
                        }
                    }
                    else {
                        $addToGroups = $false
                    }
                }
                $groupMode = "static"
            }
        }
    }
    
    #endregion
    
    #region User Processing
    
    # Display configuration summary
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "SUMMARY BEFORE USER CREATION" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    
    Write-Host "- CSV File: $CSVFile"
    Write-Host "- Number of users to process: $($CSVData.Count)"
    Write-Host "- Target OU: $OUPath"
    Write-Host "- Immediate activation: $enableUsers"
    Write-Host "- Force password change: $forcePasswordChange"
    
    Write-Host "`nMappings:"
    foreach ($key in $columnMapping.Keys) {
        Write-Host "  $key => $($columnMapping[$key])"
    }
    
    if (-not $columnMapping.ContainsKey("SamAccountName")) {
        Write-Host "- Login format: $loginFormat"
    }
    
    Write-Host "- Password type: $passwordType"
    
    if ($addToGroups) {
        if ($groupMode -eq "csv") {
            Write-Host "- Add to groups from column: $groupColumnName"
        }
        else {
            Write-Host "- Add all users to group: $staticGroup"
        }
    }
    
    # Get final confirmation
    $confirmation = Read-Host "`nConfirm user creation? (Y/N)"
    if ($confirmation -ne "Y") {
        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
        return
    }
    
    # Initialize report and counters
    $creationReport = @()
    $created = 0
    $skipped = 0
    $errors = 0
    $total = $CSVData.Count
    
    # Process each user
    for ($i = 0; $i -lt $total; $i++) {
        $user = $CSVData[$i]
        
        # Update progress bar
        $percentComplete = ($i / $total * 100)
        Write-Progress -Activity "Creating users" -Status "Processing: $($i+1)/$total" `
            -PercentComplete $percentComplete
        
        # Initialize user properties and report entry
        $userProperties = @{}
        $report = @{
            "Status" = "Not Processed"
            "Message" = ""
            "Login" = ""
            "Password" = ""
        }
        
        # Map CSV values to AD attributes
        foreach ($key in $columnMapping.Keys) {
            $columnName = $columnMapping[$key]
            $userProperties[$key] = $user.$columnName
        }
        
        # Handle SamAccountName generation if not mapped
        if (-not $columnMapping.ContainsKey("SamAccountName")) {
            # Validate required name fields
            if ([string]::IsNullOrEmpty($userProperties["GivenName"]) -or [string]::IsNullOrEmpty($userProperties["Surname"])) {
                Write-Host "ERROR: First name or last name missing for entry $($i+1)" -ForegroundColor Red
                $report["Status"] = "Error"
                $report["Message"] = "First name or last name missing"
                $errors++
                $creationReport += $report
                continue
            }
            
            # Clean names and generate login
            $firstName = Remove-Accents $userProperties["GivenName"]
            $lastName = Remove-Accents $userProperties["Surname"]
            
            # Generate login based on format
            $login = switch ($loginFormat) {
                "fname" { ($firstName.Substring(0,1) + $lastName).ToLower() }
                "firstl" { ($firstName + $lastName.Substring(0,1)).ToLower() }
                "first.last" { ($firstName + "." + $lastName).ToLower() }
                "last.first" { ($lastName + "." + $firstName).ToLower() }
                "first_last" { ($firstName + "_" + $lastName).ToLower() }
                "last_first" { ($lastName + "_" + $firstName).ToLower() }
                default { 
                    # Custom format with variable substitution
                    $format = $loginFormat -replace "{first}", $firstName -replace "{last}", $lastName
                    $format.ToLower()
                }
            }
            
            # Clean and validate login
            $login = $login -replace '[^a-zA-Z0-9]', ''
            if ($login.Length -gt 20) {
                $login = $login.Substring(0, 20)
            }
            
            # Handle duplicate logins
            $counter = 1
            $originalLogin = $login
            while (Get-ADUser -Filter "SamAccountName -eq '$login'" -ErrorAction SilentlyContinue) {
                $login = $originalLogin + $counter
                if ($login.Length -gt 20) {
                    $login = $originalLogin.Substring(0, 20 - $counter.ToString().Length) + $counter
                }
                $counter++
            }
            
            $userProperties["SamAccountName"] = $login
        }
        
        # Validate SamAccountName
        if ([string]::IsNullOrEmpty($userProperties["SamAccountName"])) {
            Write-Host "ERROR: Login (SamAccountName) missing for entry $($i+1)" -ForegroundColor Red
            $report["Status"] = "Error"
            $report["Message"] = "Login (SamAccountName) missing"
            $errors++
            $creationReport += $report
            continue
        }
        
        $login = $userProperties["SamAccountName"]
        $report["Login"] = $login
        
        # Check for existing user
        if (Get-ADUser -Filter "SamAccountName -eq '$login'" -ErrorAction SilentlyContinue) {
            Write-Host "WARNING: User '$login' already exists" -ForegroundColor Yellow
            $report["Status"] = "Skipped"
            $report["Message"] = "User already exists"
            $skipped++
            $creationReport += $report
            continue
        }
        
        # Set or generate password
        $userPassword = $null
        switch ($passwordType) {
            "static" {
                $userPassword = $staticPassword
                $report["Password"] = "Set by administrator"
            }
            "random" {
                $clearPassword = New-RandomPassword -length $passwordLength -includeSpecial $includeSpecialChars
                $userPassword = ConvertTo-SecureString $clearPassword -AsPlainText -Force
                $report["Password"] = $clearPassword
            }
            "csv" {
                $clearPassword = $user.$passwordColumnName
                if ([string]::IsNullOrWhiteSpace($clearPassword)) {
                    $clearPassword = "Welcome1!"
                    Write-Host "WARNING: Empty password in CSV for $login, using default password" -ForegroundColor Yellow
                }
                $userPassword = ConvertTo-SecureString $clearPassword -AsPlainText -Force
                $report["Password"] = $clearPassword
            }
        }
        
        # Set default values for required attributes
        if (-not $userProperties.ContainsKey("UserPrincipalName")) {
            $userProperties["UserPrincipalName"] = "$login@$Domaine"
        }
        
        if (-not $userProperties.ContainsKey("EmailAddress") -and (-not [string]::IsNullOrEmpty($userProperties["UserPrincipalName"]))) {
            $userProperties["EmailAddress"] = $userProperties["UserPrincipalName"]
        }
        
        # Set DisplayName with fallback options
        if (-not $userProperties.ContainsKey("DisplayName")) {
            if ($userProperties.ContainsKey("GivenName") -and $userProperties.ContainsKey("Surname")) {
                $userProperties["DisplayName"] = "$($userProperties["GivenName"]) $($userProperties["Surname"])"
            }
            elseif ($userProperties.ContainsKey("Name")) {
                $userProperties["DisplayName"] = $userProperties["Name"]
            }
            else {
                $userProperties["DisplayName"] = $login
            }
        }
        
        # Set Name (CN) with fallback
        if (-not $userProperties.ContainsKey("Name")) {
            $userProperties["Name"] = $userProperties["DisplayName"]
        }
        
        # Prepare parameters for New-ADUser
        $newUserParams = @{
            SamAccountName = $login
            AccountPassword = $userPassword
            Enabled = $enableUsers
            ChangePasswordAtLogon = $forcePasswordChange
            Path = $OUPath
            ErrorAction = "Stop"
        }
        
        # Add additional properties
        foreach ($key in $userProperties.Keys) {
            if ($key -ne "SamAccountName" -and -not [string]::IsNullOrEmpty($userProperties[$key])) {
                $newUserParams[$key] = $userProperties[$key]
            }
        }
        
        # Create user and handle group membership
        try {
            New-ADUser @newUserParams
            
            Write-Host "SUCCESS: User '$login' created successfully" -ForegroundColor Green
            $report["Status"] = "Created"
            $report["Message"] = "User created successfully"
            $created++
            
            # Add to groups if requested
            if ($addToGroups) {
                if ($groupMode -eq "csv") {
                    $groupName = $user.$groupColumnName
                    if (-not [string]::IsNullOrEmpty($groupName)) {
                        try {
                            # Verify and add to existing group
                            if (Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue) {
                                Add-ADGroupMember -Identity $groupName -Members $login -ErrorAction Stop
                                Write-Host "  -> Added to group '$groupName'" -ForegroundColor Green
                                $report["Message"] += "; Added to group '$groupName'"
                            }
                            else {
                                # Handle non-existent group
                                Write-Host "  -> Group '$groupName' does not exist." -ForegroundColor Yellow
                                $createGroup = Read-Host "     Create this group? (Y/N)"
                                if ($createGroup -eq "Y") {
                                    New-ADGroup -Name $groupName -GroupScope Global -GroupCategory Security -ErrorAction Stop
                                    Add-ADGroupMember -Identity $groupName -Members $login -ErrorAction Stop
                                    Write-Host "  -> Group '$groupName' created and user added" -ForegroundColor Green
                                    $report["Message"] += "; Group '$groupName' created and user added"
                                }
                                else {
                                    $report["Message"] += "; Not added to group (group does not exist)"
                                }
                            }
                        }
                        catch {
                            Write-Host "  -> Error adding to group '$groupName': $_" -ForegroundColor Red
                            $report["Message"] += "; Error adding to group"
                        }
                    }
                }
                else {
                    # Add to static group
                    try {
                        Add-ADGroupMember -Identity $staticGroup -Members $login -ErrorAction Stop
                        Write-Host "  -> Added to group '$staticGroup'" -ForegroundColor Green
                        $report["Message"] += "; Added to group '$staticGroup'"
                    }
                    catch {
                        Write-Host "  -> Error adding to group '$staticGroup': $_" -ForegroundColor Red
                        $report["Message"] += "; Error adding to group"
                    }
                }
            }
        }
        catch {
            Write-Host "ERROR: Unable to create user '$login': $_" -ForegroundColor Red
            $report["Status"] = "Error"
            $report["Message"] = "Error: $_"
            $errors++
        }
        
        # Add entry to report
        $creationReport += [PSCustomObject]$report
    }
    
    # Close progress bar
    Write-Progress -Activity "Creating users" -Completed
    
    #endregion
    
    #region Final Report
    
    # Display summary statistics
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "CREATION REPORT" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "- Users created: $created" -ForegroundColor Green
    Write-Host "- Users skipped: $skipped" -ForegroundColor Yellow
    Write-Host "- Errors: $errors" -ForegroundColor $(if ($errors -eq 0) { "Green" } else { "Red" })
    Write-Host "- Total processed: $total"
    
    # Generate and save CSV report
    $dateFormat = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportPath = [System.IO.Path]::GetDirectoryName($CSVFile) + "\AD_User_Creation_Report_$dateFormat.csv"
    
    $creationReport | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "`nReport saved to: $reportPath" -ForegroundColor Cyan
    
    # Offer to open report
    $openReport = Read-Host "Open report now? (Y/N)"
    if ($openReport -eq "Y") {
        Invoke-Item $reportPath
    }
    
    Write-Host "`nProcessing complete!" -ForegroundColor Green
    #endregion
}

#endregion

# Execute the main function
Import-ADUsers
