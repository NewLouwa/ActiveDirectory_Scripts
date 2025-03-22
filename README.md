# Active Directory & Windows Server Management Scripts

A comprehensive collection of PowerShell scripts for managing Active Directory and Windows Server environments. This repository contains various tools and utilities to automate common administrative tasks, enhance security, and improve efficiency in Windows Server management.

## Repository Structure

```
├── AD-User-Management/     # Active Directory user management scripts
│   ├── Interactive-Add_ADUser.ps1
│   └── [More scripts to be added]
├── AD-Group-Management/    # Active Directory group management scripts
├── AD-Computer-Management/ # Computer account management scripts
├── AD-Security/           # Security and compliance scripts
├── Server-Management/     # General Windows Server management scripts
└── Utilities/            # Helper functions and shared utilities
```

## Features

### Active Directory Management
- Interactive user creation with CSV import
- Bulk user management
- Group policy management
- Security auditing
- Account lifecycle management

### Windows Server Management
- Server configuration automation
- Service management
- Performance monitoring
- Backup and recovery
- Security hardening

## Prerequisites

- Windows Server 2012 R2 or later
- PowerShell 3.0 or later
- Active Directory PowerShell module
- Appropriate administrative privileges

## Installation

1. Clone this repository:
```powershell
git clone https://github.com/NewLouwa/ActiveDirectory_Scripts.git
```

2. Navigate to the desired script directory:
```powershell
cd ActiveDirectory_Scripts
```

3. Run the script with appropriate parameters:
```powershell
.\ScriptName.ps1
```

## Usage

Each script in this collection is designed to be self-contained and includes its own documentation. Please refer to the individual script files for specific usage instructions and examples.

### Example: Interactive AD User Creation

```powershell
.\AD-User-Management\Interactive-Add_ADUser.ps1
```

This script provides an interactive interface for creating Active Directory users from CSV files, with features including:
- Dynamic column mapping
- Automatic delimiter detection
- Multiple password options
- Group membership management
- Detailed reporting

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support, please open an issue in the GitHub repository or contact the maintainers.

## Disclaimer

These scripts are provided as-is without any warranty. Always test scripts in a non-production environment before using them in production.

## Author

[NewLouwa](https://github.com/NewLouwa)

## Acknowledgments

- Microsoft PowerShell Team
- Active Directory Community
- Windows Server Community 