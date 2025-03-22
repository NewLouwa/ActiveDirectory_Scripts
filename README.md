# Interactive AD User Creation Tool

A powerful PowerShell script for interactively creating Active Directory users from CSV files.

## Features

- Interactive CSV file selection with file browser
- Automatic CSV delimiter detection
- Multiple encoding support (UTF8, Unicode, UTF7, UTF32, ASCII, etc.)
- Dynamic column mapping to AD attributes
- Comprehensive error handling
- Accent character handling
- Password policy compliance
- Detailed logging and reporting
- Support for all major AD attributes

## Prerequisites

- Windows PowerShell 3.0 or higher
- Active Directory PowerShell module (RSAT)
- Domain user with appropriate permissions to create AD users

## Installation

1. Clone or download this repository
2. Ensure you have the Active Directory PowerShell module installed
3. Run the script with appropriate permissions

## Usage

1. Run the script:
```powershell
.\Interactive-Add_ADUser.ps1
```

2. Follow the interactive prompts:
   - Select your CSV file
   - Confirm the CSV delimiter
   - Choose the file encoding
   - Map CSV columns to AD attributes
   - Configure user creation settings
   - Review and confirm the import

## CSV File Format

Your CSV file should contain columns that match the AD attributes you want to set. The script will help you map your CSV columns to the appropriate AD attributes.

Required AD attributes:
- GivenName (First Name)
- Surname (Last Name)
- SamAccountName (Login)

## Error Handling

The script includes comprehensive error handling for:
- File access issues
- CSV parsing errors
- AD connection problems
- User creation failures
- Password policy violations

## Logging

The script creates detailed logs of all operations, including:
- Successful user creations
- Failed operations
- Validation errors
- Configuration details

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 