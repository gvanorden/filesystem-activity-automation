
<##
The following commands will generate activity:
     - On your local system
     - In a predefined path (C:\Activity\Testing)
     - Using the account you are logged in as
##>

# If no folders or files exist in C:\Activity\Testing, 1 new file and folder will be created in this path and all activity events will be triggered on each object.
 Both of the following commands will behave identically:
    FS-Generate-Activity
    FS-Generate-Activity -Read -Write -Rename -Move -ChangeOwner -AddPermission -ChangePermission -RemovePermission

# If you would like to conduct all events and delete the folder or file that was acted on, both of the following commands will behave identically:
    FS-Generate-Activity -Delete
    FS-Generate-Activity -Create -Read -Write -Rename -Move -ChangeOwner -AddPermission -ChangePermission -RemovePermission -Delete

# To act on multiple files and folders, specify the -Count parameter.  This will either create and/or act on existing files dependant on the -Count specified:
    FS-Generate-Activity -Count 2
    
# To add a delay between acting on files/folder, use the -Delay parameter
    FS-Generate-Activity -Count 2 -Delay 5

# To create a set of files before acting on them further, run a command with the -Count and -Create parameters first.
    FS-Generate-Activity -Count 10 -Create

<##
The following commands will generate activity:
     - On a remote system (REMOTEHOST01)
     - In a user-defined path (C:\MyActivity\TestCases)
     - On user-defined files and/or folders (TestFile.txt, TestFolder)
     - Using a preconfigured list of credentials ($Credentials)
##>

# Creates and/or performs all activity events on 1 file (TestFile.txt) in path C:\MyActivity\TestCases of the target system (REMOTEHOST01):
    FS-Generate-Activity -ComputerName 'REMOTEHOST01' -FolderPath 'C:\MyActivity\TestCases' -FileName 'TestFile.txt' -Credentials $Credentials -Read -Write -ChangeOwner

# Creates and/or performs rename, move and change permission events on 3 folders (TestFolder, TestFolder1, TestFolder2):
    FS-Generate-Activity -ComputerName 'REMOTEHOST01' -FolderPath 'C:\MyActivity\TestCases' -FolderName 'TestFolder' -Credentials $Credentials -Count 3 -Rename -Move -ChangePermission

# Create and/or performs all activity events on 1 file () and 1 folder:
    FS-Generate-Activity -ComputerName 'REMOTEHOST01' -FolderPath 'C:\MyActivity\TestCases' -FileName 'TestFile.txt' -FolderName 'FolderActivity' -Credentials $Credentials

# Perform all activity events on each file and folder in path C:\MyActivity\TestCases.  If no file system objects exist, it will create 1 new file and 1 new folder using a predetermined naming convention:
    FS-Generate-Activity -ComputerName 'REMOTEHOST01' -FolderPath 'C:\MyActivity\TestCases'

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

#Example of using the FS-Generate-ADUsers function to create and use random Active Directory accounts for activity generation:

Import-Module FileSystemActivity -WarningAction SilentlyContinue

$Credentials = FS-Generate-ADUsers -ComputerName "REMOTECOMP1" -OUPath "OU=Sandbox,DC=DOMAIN,DC=com" -Count 10

FS-Generate-Activity -Count 5 -Create -Credentials $Credentials
FS-Generate-Activity -Credentials $Credentials