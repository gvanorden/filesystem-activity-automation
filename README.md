#Powershell Module: File System Activity Automation

Generate Read, Write, Move, Rename, Owner Change, Permission Change and Delete events from a set random users.

Prerequisites -

Download and copy the FileSystemActivity folder into your PowerShell Modules directory: - C:\Windows\System32\WindowsPowerShell\v1.0\Modules

Your account needs to be a Local Administrator on: - The system this module is installed - The remote system(s) you desire to conduct activity

To generate events from a set of random users, you'll need: - Domain Admin rights OR - Create OU and User rights

Open PowerShell ISE in administrator mode and import the FileSystemActivity module - Import-Module FileSystemActivity -WarningAction SilentlyContinue

If successful, you are now ready to automate Windows File System activity events!

Referenced Functions: FS-Generate-ADUsers, FS-Generate-Activity

FUNCTION NAME: FS-Generate-ADUsers
FUNCTION DESCRIPTION: Creates random AD users. References text files in the Names folder of your FileSystemActivity module to do this.
FUNCTION OUTPUT: A list of PSCredential objects that will be used for randomized activity generation.

[OPTIONAL][string]    [Default: localhost]   -ComputerName     |   The remote system where activity will be generated.  The function will create new users in AD and add them to Local Administrators group on the -ComputerName specified.
[MANDATORY][string]                          -OUPath           |   The Organizational Unit path where your new users will be stored.  The function will create a new OU in this path called RandomUsers, where all new users will be stored.
[OPTIONAL][int]       [Default: 1]           -Count            |   The number of users to create. If this parameter is not specified, the default value is 1.
[OPTIONAL][switch]    [Default: $false]      -CreateNewUsers   |   A switch parameter that tells the function to create new random users each time it is run.

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

FUNCTION NAME: FS-Generate-Activity
FUNCTION DESCRIPTION: Triggers activity events on files and folders 
FUNCTION OUTPUT: A table with the following columns:
    [Time]            |   Date and time the event was triggered
    [Computer]        |   Name of the system in which activity events were conducted
    [Path]            |   The admin folder path where the file(s) and/or folders(s) were acted on
    [Type]            |   The object type that was acted on (File, Folder, Path)
    [Action]          |   The type of action that was committed (Created, Read, Updated, Renamed, Moved, Owner Changed, Permission Added, Permission[Level] Changed, Permission Removed, Deleted)
    [Action Object]   |   Information about the object that was acted on
    [Action By]       |   The user that conducted the action

[OPTIONAL][string]    [Default: localhost]             -ComputerName        | The name of target system to conduct activity
[OPTIONAL][string]    [Default: C:\Activity\Testing]   -FolderPath          | The path in which file(s)/folder(s) will be acted on
[OPTIONAL][string]    [Default: FolderTest]            -FolderName          | The base name of the folder to be acted on
[OPTIONAL][string]    [Default: FileTest.txt]          -FileName            | The base name of the file to be acted on
[OPTIONAL][array]     [Default: Current User]          -Credentials         | A list of PSCredentials that will be used to randomize activity
[OPTIONAL][int]       [Default: 1]                     -Count               | Will create or act on file(s)/folders(s) based on the specified value
[OPTIONAL][int]       [Default: 0]                     -Delay               | A wait period, in seconds, to delay actions on file(s) or folder(s)
[OPTIONAL][switch]    [Default: $true]                 -Create              | Creates a new file or folder
[OPTIONAL][switch]    [Default: $true]                 -Read                | Triggers a read event on a file
[OPTIONAL][switch]    [Default: $true]                 -Write               | Triggers a write event on a file
[OPTIONAL][switch]    [Default: $true]                 -Rename              | Triggers a rename event on a file or folder
[OPTIONAL][switch]    [Default: $true]                 -Move                | Triggers a move event on a file or folder
[OPTIONAL][switch]    [Default: $false]                -Delete              | Deletes a file or folder
[OPTIONAL][switch]    [Default: $true]                 -ChangeOwner         | Changes the owner of a file or folder
[OPTIONAL][switch]    [Default: $true]                 -AddPermission       | Adds a user to the permissions of a file or folder
[OPTIONAL][switch]    [Default: $true]                 -ChangePermission    | Changes the permission level of an existing user on a file or folder
[OPTIONAL][switch]    [Default: $true]                 -RemovePermission    | Remove a user from the permissions of a file or folder
