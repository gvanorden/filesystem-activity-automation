function Find-Module-Path (
    [switch] $Log
)
{
    $modulePaths = $env:PSModulePath.Split(";")

    foreach($path in $modulePaths)
    {
        $path = ($path).Replace("`"","")
        if($path.Substring($path.length - 1) -eq "\")
        {
            $path = $path.Substring(0, $path.length - 1)
        }
    
        $modulePath = "$path\FileSystemActivity"

        if(Test-Path $modulePath)
        {
            if ($Log) { return $modulePath + "\Activity-Log.txt" }
            else { return $modulePath }
            
        }
    }
}


function FSAC-Scrub-Path (
    [Parameter(Position=0,mandatory=$true)][string]$Path
)
{
    if($Path.Substring($Path.Length - 1) -eq '\')
    {
        $Path = $Path.Substring(0, $Path.Length - 1)
    }

    return $Path
}

function Set-Computer-Name (
    [string]$ComputerName
)
{
    if((!$ComputerName) -or ($ComputerName -eq 'localhost')) 
    {
        $ComputerName = $env:COMPUTERNAME
    }
    return $ComputerName
}

function FSAC-Close-Connections (
   [Parameter(Position=0,mandatory=$true)][string]$Path
)
{
    try {$d = NET USE $Path /DELETE } catch { }
}

function FSAC-Get-ItemName (
    [string]$FileName,
    [string]$FolderName
)
{
    if($FileName){$Name = $FileName}
    elseif($FolderName){$Name = $FolderName }
    
    return $Name
}

function FSAC-Get-ItemType (
    [string]$FileName,
    [string]$FolderName
)
{
  if($FileName) {$Type = "FILE"}
  elseif($FolderName) {$Type = "FOLDER"}

  return $Type
}

function FSAC-Set-Results(
    [string] $Time,
    [string] $Computer,
    [string] $Path,
    [string] $Type,
    [string] $Action,
    [string] $Object,
    [string] $User
)
{
    $res = '' | Select Time, Computer, Path, Type, Action, Object, User
    $res.Time = $Time; $res.Computer = $Computer; $res.Path = $Path; $res.Type = $Type; $res.Action = $Action; $res.Object = $Object; $res.User = $User;
    
    $res | Out-File -FilePath (Find-Module-Path -Log) -Append
    $res
}

function Get-Random-Item (
    [array]$ItemList
)
{
    $Item = $ItemList[(Get-Random -Minimum 0 -Maximum $ItemList.length)]
    return $Item
}

function Translate-PermissionType (
    [string]$permissionType
)
{
    if($permissionType -eq "ReadAndExecute") {$permissionType = "Read and Execute"}
    elseif($permissionType -eq "FullControl") {$permissionType = "Full Control"}
    
    return $permissionType
}

function FSAC-Get-Children (
    [string]$Computer,
    [string]$FolderPath
)
{
    $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$");

    $a = New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath
    $b = Get-ChildItem NewPSDrive:\ | ? {($_.Name -ne "MoveFile") -and ($_.Name -ne "MoveFolder")}
    $c = Remove-PSDrive -Name NewPSDrive

    FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue

    return $b
}

function FSAC-Get-DomainUsers (
    [string]$OUPath,
    [string]$Password,
    [int]$NewUserCount
)
{
    $res = '' | Select Path, Usernames, Message

    if(!$OUPath){$OUPath = (Get-ADDomain).DistinguishedName}; $NewOUPath = "OU=RandomUsers,$OUPath"

    if (!$Password)
    {
        if(Test-Path ((Find-Module-Path) + "\Stored.txt" ))
        {
            $pwd = Get-Content ((Find-Module-Path) + "\Stored.txt" ) | ConvertTo-SecureString
        }
        else
        {
            Read-Host -Prompt "Please, enter a password for the new user(s):" -AsSecureString | ConvertFrom-SecureString | Out-File ((Find-Module-Path) + "\Stored.txt" )
            $pwd = Get-Content ((Find-Module-Path) + "\Stored.txt" ) | ConvertTo-SecureString
        }
    }
    else
    {
        $pwd = ConvertTo-SecureString $Password -AsPlainText -Force
    }

    if($NewUserCount -gt 0)
    {
        $i = 0 
        do
        {
            $firstNames = (Get-Content ((Find-Module-Path) + "\Names\FirstNames.txt") | % {$_.Substring(0, 1) + $_.Substring(1).ToLower()}); $firstName = $firstNames[(Get-Random -Minimum 0 -Maximum $firstNames.length)]
            $lastNames = (Get-Content ((Find-Module-Path) + "\Names\LastNames.txt") | % {$_.Substring(0, 1) + $_.Substring(1).ToLower()}); $lastName = $lastNames[(Get-Random -Minimum 0 -Maximum $lastNames.length)]

            try
            {
                Get-ADUser "$firstName.$lastName"
            }
            catch
            {
                New-ADUser -Name "$firstName $lastName" -SamAccountName "$firstName.$lastName" -DisplayName "$firstName $lastName" -GivenName $lastName -Surname $lastName -UserPrincipalName ("$firstName.$lastName" + "@" + (Get-ADDomain).DNSRoot) -AccountPassword $pwd -PasswordNeverExpires $true -Path $NewOUPath -Enabled $true
            }

            $i++
        } while ($i -lt $NewUserCount)
    }

    $res.Path = $NewOUPath
    $res.Usernames = (Get-ADUser -Filter * -SearchBase $NewOUPath).SamAccountName
    if($NewUserCount -gt 0)
    {
        $res.Message = "Successfully created " + $NewUserCount + " new user(s) in $NewOUPath"
    }
    else
    {
        $res.Message = ""
    }

    $res
}

function FSAC-Add-LocalAdmins (
    [string]$Computer,
    [array]$Users
)
{
    $addedUsers = @()

    $adminGrp = [ADSI]"WinNT://$ComputerName/Administrators,group"
    $admins = (@($adminGrp.psbase.Invoke("Members")) | % {New-Object PSObject -Property @{Name =$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)}}).Name

    foreach($User in $Users)
    {
        if($admins -notcontains $User)
        {
            $domain = (Get-ADDomain).NetBIOSName
            $username = ([ADSI]"WinNT://$domain/$user,user").Path
            $adminGrp.Add($username)

            $addedUsers += $username
        }
    }

    if($addedUsers.Length -gt 0) { [string]$addedUsers.Length + " users have been added to Local Administrators on " + $Computer }
}

function FSAC-Get-Credentials (
    [array]$Users,
    [string]$Password,
    [int]$Count
)
{
    $credentials = @()

    if (!$Password)
    {
        if(Test-Path ((Find-Module-Path) + "\Stored.txt" ))
        {
            $pwd = Get-Content ((Find-Module-Path) + "\Stored.txt" ) | ConvertTo-SecureString
        }
        else
        {
            Read-Host -Prompt "Please, enter a password for the new user(s):" -AsSecureString | ConvertFrom-SecureString | Out-File ((Find-Module-Path) + "\Stored.txt" )
            $pwd = Get-Content ((Find-Module-Path) + "\Stored.txt" ) | ConvertTo-SecureString
        }
    }
    else
    {
        $pwd = ConvertTo-SecureString $Password -AsPlainText -Force
    }

    foreach($user in $Users)
    {
        $credentials += New-Object System.Management.Automation.PSCredential -ArgumentList $User, $pwd
    }
    
    $credentials | Select-Object -First $Count
}

function FSAC-Remove-UserList (
    [string] $User,
    [array] $Credentials
)
{
    if ($User)
    {
        Remove-ADUser -Identity $User -Confirm:$false
    }
    elseif ($Users)
    {
        foreach($User in $Users)
        {
            try
            {
                $Username = $User.UserName
            }
            catch
            {
                $Username = $User
            }

            Remove-ADUser -Identity $Username -Confirm:$false
        }
    }
}

function FSAC-Create-Path (
    [string]$ComputerName,
    [string]$FolderPath
)
{
    #$ComputerName = $env:COMPUTERNAME
    #$FolderPath = 'C:\Activity\Testing'

    $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")
    $RootPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")[0] + '$'
    $NewPath = $NetworkPath.Replace($rootPath, "")

    $a = New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $RootPath
    $b = New-Item -Path "NewPSDrive:$NewPath" -ItemType Directory -Force
    $c = Remove-PSDrive -Name NewPSDrive

    FSAC-Set-Results -Time (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') -Computer $ComputerName -Path $FolderPath -Type "PATH" -Action "CREATED" -Object $FolderPath -User $env:USERNAME
}

function FSAC-Create-Item (
    [Parameter(Position=0,mandatory=$true)][string]$ComputerName,
    [Parameter(Position=1,mandatory=$true)][string]$FolderPath,
    [string]$FileName, 
    [string]$FolderName, 
    [array]$Credentials
) 
{
    $res = '' | Select FileName, FolderName, Message

    #$FileName = 'FileTest.txt'
    #$FolderName = 'FolderTest'
    
    $ComputerName = Set-Computer-Name -ComputerName $ComputerName 
    $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")
    
    if(($FileName) -and (Test-Path $NetworkPath))
    {  
        $j = 0; $SplitFile = $FileName.Split(".")

        do
        {
            if($j -eq 0) {$nFileName = $FileName} else {$nFileName = $SplitFile[0] + $j + '.' + $SplitFile[1]}              
                
            $exists = Test-Path "$NetworkPath\$nFileName"
            if(!$exists)
            {
                $User = Get-Random-Item -ItemList $Credentials; $Username = $User.UserName
                $a = if($Username -eq $env:USERNAME){New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath} else {New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath -Credential $User}
                $b = New-Item -Path "NewPSDrive:\$nFileName" -ItemType File -Force
                $c = Remove-PSDrive -Name NewPSDrive

                FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue

                $res.FileName = $nFileName
                $res.Message = (FSAC-Set-Results -Time (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') -Computer $ComputerName -Path $FolderPath -Type "FILE" -Action "CREATED" -Object $nFileName -User $Username)
            }
            else
            {
                $j++
            }
        } while ($exists -eq $true)
    }
      
    if(($FolderName) -and (Test-Path $NetworkPath))
    {
        $User = Get-Random-Item -ItemList $Credentials; $Username = $User.UserName   
        if(($FolderName -eq "MoveFile") -or ($FolderName -eq "MoveFolder"))
        {
            
            $a = if($Username -eq $env:USERNAME){New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath} else {New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath -Credential $User}
            $b = New-Item -Path "NewPSDrive:\$FolderName" -ItemType Directory -Force
            $c = Remove-PSDrive -Name NewPSDrive

            FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue
        }
        else
        {
         
            $k = 0
            
            do
            {
                if($k -eq 0) {$nFolderName = $FolderName} else {$nFolderName = $FolderName + $k }
                
                $exists = Test-Path "$NetworkPath\$nFolderName"
                if(!$exists)
                {   
                    $a = if($Username -eq $env:USERNAME){New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath} else {New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath -Credential $User}
                    $b = New-Item -Path "NewPSDrive:\$nFolderName" -ItemType Directory -Force
                    $c = Remove-PSDrive -Name NewPSDrive
                    
                    FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue

                    $res.FolderName = $nFolderName
                    $res.Message = (FSAC-Set-Results -Time (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') -Computer $ComputerName -Path $FolderPath -Type "FOLDER" -Action "CREATED" -Object $nFolderName -User $Username)
                }
                else
                {
                    $k++
                }          
            } while ($exists -eq $true)
        }
    }
                           
    return $res
}

function FSAC-Read-File (
    [string]$ComputerName, 
    [Parameter(Position=1,mandatory=$true)][string]$FolderPath,
    [Parameter(Position=2,mandatory=$true)][string]$FileName,
    [array]$Credentials
)
{
    $User = Get-Random-Item -ItemList $Credentials; $Username = $User.UserName
    $ComputerName = Set-Computer-Name -ComputerName $ComputerName 
    $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")               
        
    do
    {   
        $testPath = Test-Path "$NetworkPath\$FileName"
        if($testPath)
        {   

            $a = if($Username -eq $env:USERNAME){New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath} else {New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath -Credential $User}   
            $b = Get-Content -Path "NewPSDrive:\$FileName" -Force
            $c = Remove-PSDrive -Name NewPSDrive

            FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue

            FSAC-Set-Results -Time (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') -Computer $ComputerName -Path "$FolderPath" -Type "FILE" -Action "READ" -Object $FileName -User $Username
        }
    } while (!$testPath)
}

function FSAC-Update-File (
    [Parameter(Position=0,mandatory=$true)][string] $ComputerName, 
    [Parameter(Position=1,mandatory=$true)][string] $FolderPath,
    [Parameter(Position=2,mandatory=$true)][string] $FileName,
    [Parameter(Position=3,mandatory=$true)][array] $Credentials,
    [string]$Content
)
{
    if (!$Content) {$Content = "Placeholder content for file update."}    
    $User = Get-Random-Item -ItemList $Credentials; $Username = $User.UserName
    $ComputerName = Set-Computer-Name -ComputerName $ComputerName 
    $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")
                    

    do
    {   
        $testPath = Test-Path "$NetworkPath\$FileName"
        if($testPath)
        {
            $a = if($Username -eq $env:USERNAME){New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath} else {New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath -Credential $User}
            $b = Add-Content -Path "NewPSDrive:\$FileName" -Value $Content -Force
            $c = Remove-PSDrive -Name NewPSDrive

            FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue

            FSAC-Set-Results -Time (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') -Computer $ComputerName -Path $FolderPath -Type "FILE" -Action "UPDATED" -Object $FileName -User $Username
        }
    } while (!$testPath)
}

function FSAC-Rename-Item (
    [Parameter(Position=0,mandatory=$true)][string]$ComputerName, 
    [Parameter(Position=1,mandatory=$true)][string]$FolderPath,
    [string] $FileName, 
    [string]$FolderName, 
    [array] $Credentials
)
{
    $paths = @(); $res = '' | Select AccessPath, AccessPathRename, FileName, FileRename, FolderName, FolderRename
    $ComputerName = Set-Computer-Name -ComputerName $ComputerName 
    $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")
    FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue

    if($FileName)
    {
        $res.AccessPath = "NewPSDrive:\$FileName"
        $res.AccessPathRename = "NewPSDrive:\RN$FileName"
        $res.FileName = $FileName
        $res.FileRename = "RN$FileName" 
        
        $paths += $res | Select AccessPath, AccessPathRename, FileName, FileRename
    }

    if($FolderName)
    {
        $res.AccessPath = "NewPSDrive:\$FolderName"
        $res.AccessPathRename = "NewPSDrive:\RN$FolderName"
        $res.FolderName = $FolderName
        $res.FolderRename = "RN$FolderName"
        
        $paths += $res | Select AccessPath, AccessPathRename, FolderName, FolderRename
    }
    
    foreach($path in $paths)
    {   
        $User = Get-Random-Item -ItemList $Credentials; $Username = $User.UserName

        try
        {
            $a = if($Username -eq $env:USERNAME){New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath} else {New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath -Credential $User}
        }
        catch
        {
            $a = New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath
        } 

        if($path.FileName)
        {
            $b = Rename-Item -Path $path.AccessPath -NewName $path.FileRename -Force
        }
        
        elseif($path.FolderName)
        {
            $b = Rename-Item -Path $path.AccessPath -NewName $path.FolderRename -Force
        }
        
        $c = Remove-PSDrive -Name NewPSDrive

        FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue

        $prevName = (FSAC-Get-ItemName -FileName $path.FileName -FolderName $path.FolderName)
        $nextName = (FSAC-Get-ItemName -FileName $path.FileRename -FolderName $path.FolderRename)

        FSAC-Set-Results -Time (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') -Computer $ComputerName -Path $FolderPath -Type (FSAC-Get-ItemType -FileName $path.FileName -FolderName $path.FolderName) -Action "RENAMED" -Object ($prevName + " => " + $nextName)  -User $Username

        do
        {
            if($path.FileName) {$renamePath = Test-Path ($NetworkPath + "\" + $path.FileRename) } 
            elseif($path.FolderName) {$renamePath = Test-Path ($NetworkPath + "\" + $path.FolderRename)}
            
            if($renamePath)
            {
                $User = Get-Random-Item -ItemList $Credentials; $Username = $User.UserName

                try
                {
                    $a = if($Username -eq $env:USERNAME){New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath} else {New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath -Credential $User}
                }
                catch
                {
                    $a = New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath
                }

                if($path.FileName) {$b = Rename-Item -Path $path.AccessPathRename -NewName $path.FileName -Force}
                elseif($path.FolderName){$b = Rename-Item -Path $path.AccessPathRename -NewName $path.FolderName -Force}
                $c = Remove-PSDrive -Name NewPSDrive

                FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue

                FSAC-Set-Results -Time (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') -Computer $ComputerName -Path $FolderPath -Type (FSAC-Get-ItemType -FileName $path.FileName -FolderName $path.FolderName) -Action "RENAMED BACK" -Object ($nextName + " => " + $prevName)  -User $Username
            }
        } while (!$renamePath)
    }                
}
 
function FSAC-Move-Item (
    [Parameter(Position=0,mandatory=$true)][string][string] $ComputerName,
    [Parameter(Position=1,mandatory=$true)][string] $FolderPath,
    [string] $FileName, 
    [string] $FolderName, 
    [array] $Credentials
)
{
    $paths = @(); $res = '' | Select Path1, Path2, PathTo1, PathTo2, MoveFrom1, MoveFrom2, MoveTo1, MoveTo2, FileName, FolderName
    $ComputerName = Set-Computer-Name -ComputerName $ComputerName
    $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")

    if(($FileName) -and (Test-Path "$NetworkPath\$FileName"))
    {

        if(!(Test-Path "$NetworkPath\MoveFile"))
        {
            $User = Get-Random-Item -ItemList $Credentials
            $c = FSAC-Create-Item -ComputerName $ComputerName -FolderPath $FolderPath -FolderName "MoveFile" -Credentials $Credentials
        }

        $res.Path1 =  "$FolderPath\$FileName"; $res.Path2 =  "$FolderPath\MoveFile\$FileName"
        $res.PathTo1 = "$FolderPath\MoveFile"; $res.PathTo2 = "$FolderPath\$FileName"
        $res.MoveFrom1 = "NewPSDrive:\$FileName"; $res.MoveFrom2 = "NewPSDrive:\MoveFile\$FileName" 
        $res.MoveTo1 = "NewPSDrive:\MoveFile"; $res.MoveTo2 = "NewPSDrive:\"
        $res.FileName = $FileName
        
        $paths += $res | Select Path1, Path2, PathTo1, PathTo2, MoveFrom1, MoveFrom2, MoveTo1, MoveTo2, FileName
    } 
    
    if(($FolderName) -and (Test-Path "$NetworkPath\$FolderName"))
    {
        if(!(Test-Path "$NetworkPath\MoveFolder"))
        {
            $User = Get-Random-Item -ItemList $Credentials
            $c = FSAC-Create-Item -ComputerName $ComputerName -FolderPath $FolderPath -FolderName "MoveFolder" -Credentials $Credentials
        }     

        $res.Path1 = "$FolderPath\$FolderName"; $res.Path2 = "$FolderPath\MoveFolder\$FolderName"
        $res.PathTo1 = "$FolderPath\MoveFolder"; $res.PathTo2 = "$FolderPath\$FolderName"
        $res.MoveFrom1 = "NewPSDrive:\$FolderName"; $res.MoveFrom2 = "NewPSDrive:\MoveFolder\$FolderName"
        $res.MoveTo1 = "NewPSDrive:\MoveFolder"; $res.MoveTo2 = "NewPSDrive:\"
        $res.FolderName = $FolderName
        
        $paths += $res | Select Path1, Path2, PathTo1, PathTo2, MoveFrom1, MoveFrom2, MoveTo1, MoveTo2, FolderName
    }

    foreach($path in $paths)
    {
        $User = Get-Random-Item -ItemList $Credentials; $Username = $User.UserName

        $a = if($Username -eq $env:USERNAME){New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath} else {New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath -Credential $User}
        $b = Move-Item -Path $path.MoveFrom1 -Destination $path.MoveTo1 -Force
        $c = Remove-PSDrive -Name NewPSDrive
          
        FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue

        FSAC-Set-Results -Time (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') -Computer $ComputerName -Path $path.Path1 -Type (FSAC-Get-ItemType -FileName $path.FileName -FolderName $path.FolderName) -Action "MOVED" -Object $path.Path2 -User $Username

        do
        {
            if($path.FileName) {$movePath = Test-Path "$NetworkPath\MoveFile\$FileName"}
            elseif($path.FolderName) {$movePath = Test-Path "$NetworkPath\MoveFolder\$FolderName"}

            if($movePath)
            {
                $User = Get-Random-Item -ItemList $Credentials; $Username = $User.UserName

                try
                {
                    $a = if($Username -eq $env:USERNAME){New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath} else {New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath -Credential $User}
                }
                catch
                {
                    $a = New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath
                } 

                $b = Move-Item -Path $path.MoveFrom2 -Destination $path.MoveTo2 -Force
                $c = Remove-PSDrive -Name NewPSDrive

                FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue

               FSAC-Set-Results -Time (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') -Computer $ComputerName -Path $path.Path2 -Type (FSAC-Get-ItemType -FileName $path.FileName -FolderName $path.FolderName) -Action "MOVED BACK" -Object $path.PathTo2 -User $Username
            }
        } while (!$movePath)
    }
}

function FSAC-Change-Owner (
    [Parameter(Position=0,mandatory=$true)][string]$ComputerName, 
    [Parameter(Position=1,mandatory=$true)][string]$FolderPath,
    [string]$FileName,
    [string]$FolderName,
    [array]$Credentials
)
{
    $paths = @(); $res = '' | Select Path, NetworkPath, AccessPath, FileName, FolderName
    $User = Get-Random-Item -ItemList $Credentials; $Username = $User.UserName
    $ComputerName = Set-Computer-Name -ComputerName $ComputerName 
    $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")

    if($FileName) {$res.Path = "$FolderPath\$FileName"; $res.NetworkPath = "$NetworkPath\$FileName"; $res.AccessPath = "NewPSDrive:\$FileName"; $res.FileName = $FileName; $paths += $res | Select Path, NetworkPath, AccessPath, FileName}
    if($FolderName) {$res.Path = "$FolderPath\$FolderName"; $res.NetworkPath = "$NetworkPath\$FolderName"; $res.AccessPath = "NewPSDrive:\$FolderName"; $res.FolderName = $FolderName; $paths += $res | Select Path, NetworkPath, AccessPath, FolderName}
    
    foreach($path in $paths)
    {
        if(Test-Path $path.NetworkPath)
        {      
            $acl = $null

            $a = if($Username -eq $env:USERNAME){New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath} else {New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath -Credential $User}
            $acl = (Get-Item $path.AccessPath).GetAccessControl('Access')
            
            $prevOwner = ((Get-Item $path.AccessPath).GetAccessControl('Owner').Owner).Split("\")[1]
            if($Credentials.Length -gt 1)
            {
                do{$OwnerName = (Get-Random-Item -ItemList $Credentials).UserName} while ($OwnerName -eq $prevOwner)
            }
            else
            {
                $OwnerName = $User.UserName
            }
            
            $nextOwner = New-Object System.Security.Principal.NTAccount($OwnerName)
            $acl.SetOwner($nextOwner)          
            Set-Acl -Path $path.AccessPath -AclObject $acl

            $b = Remove-PSDrive -Name NewPSDrive

            FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue
   
            FSAC-Set-Results -Time (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') -Computer $ComputerName -Path $path.Path -Type (FSAC-Get-ItemType -FileName $path.FileName -FolderName $path.FolderName) -Action "OWNER CHANGED" -Object ("$prevOwner => $nextOwner") -User $Username
        }
    }
}

function FSAC-Add-Permission (
    [Parameter(Position=0,mandatory=$true)][string] $ComputerName,
    [Parameter(Position=1,mandatory=$true)][string] $FolderPath,
    [string]$FileName,
    [string]$FolderName,
    [array] $Credentials
)
{
    $paths = @(); $res = '' | Select Path, AccessPath, FileName, FolderName
    $ComputerName = Set-Computer-Name -ComputerName $ComputerName 
    $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")

    $Permission = Get-Random-Item -ItemList "Read", "Write", "Modify", "ReadAndExecute", "FullControl"
    
    if(($FileName) -and (Test-Path "$NetworkPath\$FileName"))
    {
        $res.Path = "$FolderPath\$FileName"
        $res.AccessPath = "NewPSDrive:\$FileName"
        $res.FileName = $FileName; 
        
        $paths += $res | Select Path, AccessPath, FileName
    }

    if(($FolderName) -and (Test-Path "$NetworkPath\$FolderName"))
    {
        $res.Path = "$FolderPath\$FolderName"
        $res.AccessPath = "NewPSDrive:\$FolderName"
        $res.FolderName = $FolderName
        
        $paths += $res | Select Path, AccessPath, FolderName
    }

    foreach($path in $paths)
    {
        $acl = $null       

        $User = Get-Random-Item -ItemList $Credentials; $Username = $User.UserName; $addUser = (Get-Random-Item -ItemList $Credentials).UserName
        $a = if($Username -eq $env:USERNAME){New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath} else {New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath -Credential $User}
      
        $acl = (Get-Item $path.AccessPath).GetAccessControl('Access')
        $ace = $addUser, $Permission, "Allow"
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule $ace    
        $acl.SetAccessRule($rule)
        $acl | Set-Acl $path.AccessPath

        $b = Remove-PSDrive -Name NewPSDrive

        FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue
        
        FSAC-Set-Results -Time (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') -Computer $ComputerName -Path $path.Path -Type (FSAC-Get-ItemType -FileName $path.FileName -FolderName $path.FolderName) `
        -Action "PERMISSION ADDED" -Object ($addUser + " (" + (Translate-PermissionType $Permission) + ")") -User $Username
    }
}

function FSAC-Change-Permission (
    [Parameter(Position=0,mandatory=$true)][string] $ComputerName,
    [Parameter(Position=1,mandatory=$true)][string] $FolderPath,
    [string]$FileName,
    [string]$FolderName,
    [array]$Credentials
)
{
    $paths = @(); $res = '' | Select Path, AccessPath, FileName, FolderName
    $ComputerName = Set-Computer-Name -ComputerName $ComputerName 
    $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")
    FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue

    if(($FileName) -and (Test-Path "$NetworkPath\$FileName"))
    {
        $directFile = @(); $directFile += (Get-Item $NetworkPath\$FileName).GetAccessControl('Access').Access | ? {$_.isInherited -eq $false}
        
        if(!$directFile)
        {
            FSAC-Add-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials       
        }
        
        $res.Path = "$FolderPath\$FileName"
        $res.AccessPath = "NewPSDrive:\$FileName"
        $res.FileName = $FileName; 
        
        $paths += $res | Select Path, AccessPath, FileName
    }

    if(($FolderName) -and (Test-Path "$NetworkPath\$FolderName"))
    {
        $directFolder = @(); $directFolder += (Get-Item $NetworkPath\$FolderName).GetAccessControl('Access').Access | ? {$_.isInherited -eq $false}
        
        if(!$directFolder)
        {
            $changeFolder = FSAC-Add-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials       
        }
        
        $res.Path = "$FolderPath\$FolderName"
        $res.AccessPath = "NewPSDrive:\$FolderName"
        $res.FolderName = $FolderName
        
        $paths += $res | Select Path, AccessPath, FolderName
    }
    
    foreach($path in $paths)
    {
        $acl = $null
        $User = Get-Random-Item -ItemList $Credentials; $Username = $User.UserName;

        $a = if($Username -eq $env:USERNAME){New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath} else {New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath -Credential $User}
       
        $ChangeUser = @(); $ChangeUser += ((Get-Item $path.AccessPath).GetAccessControl('Access').Access | ? {$_.isInherited -eq $false})
        $ChangeUsername = $ChangeUser[0].IdentityReference.Value.Split("\")[1];
        $PermissionOne = ([string]($changeUser[0].FileSystemRights)).Replace(", Synchronize","");
            
        do {$PermissionTwo = Get-Random-Item -ItemList "Read", "Write", "Modify", "ReadAndExecute", "FullControl"} while ($PermissionTwo -eq $PermissionOne)
            

        $acl = (Get-Item $path.AccessPath).GetAccessControl('Access')
        $ace = $ChangeUsername, $PermissionTwo, "Allow"
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule $ace
        $acl.SetAccessRule($rule)
        $acl | Set-Acl $path.AccessPath  

        $b = Remove-PSDrive -Name NewPSDrive
        FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue

        FSAC-Set-Results -Time (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') -Computer $ComputerName -Path $path.Path -Type (FSAC-Get-ItemType -FileName $path.FileName -FolderName $path.FolderName) -Action "PERMISSION CHANGED" -Object ($ChangeUsername + " (" + (Translate-PermissionType $PermissionOne) + " => " + (Translate-PermissionType $PermissionTwo) + ")") -User $Username
    }
}

function FSAC-Remove-Permission (
    [Parameter(Position=0,mandatory=$true)][string] $ComputerName,
    [Parameter(Position=1,mandatory=$true)][string] $FolderPath,
    [string]$FileName,
    [string]$FolderName,
    [array] $Credentials
)
{
    $paths = @(); $res = '' | Select Path, AccessPath, Permission, FileName, FolderName

    $ComputerName = Set-Computer-Name -ComputerName $ComputerName 
    $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")

    if(($FileName) -and (Test-Path "$NetworkPath\$FileName"))
    {
        $directFile = @(); $directFile += (Get-Item "$NetworkPath\$FileName").GetAccessControl('Access').Access | ? {$_.isInherited -eq $false}
        
        if(!$directFile[0])
        {
            FSAC-Add-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials;
            $Permission = ((Get-Item "$NetworkPath\$FileName").GetAccessControl('Access').Access | ? {$_.isInherited -eq $false}).IdentityReference.Value    
        }
        else
        {
            $Permission = @(); $Permission += ((Get-Item "$NetworkPath\$FileName").GetAccessControl('Access').Access | ? {$_.isInherited -eq $false}).IdentityReference.Value
            if($Permission.Length -gt 1)
            {
                $Permission = $Permission[0]
            }
        }
        
        $res.Path = "$FolderPath\$FileName"
        $res.AccessPath = "NewPSDrive:\$FileName"
        $res.FileName = $FileName;
        $res.Permission = $Permission
        
        $paths += $res | Select Path, AccessPath, Permission, FileName
    }

    if(($FolderName) -and (Test-Path "$NetworkPath\$FolderName"))
    {
        $directFolder = @(); $directFolder += (Get-Item "$NetworkPath\$FolderName").GetAccessControl('Access').Access | ? {$_.isInherited -eq $false}

        if(!$directFolder[0])
        {
            FSAC-Add-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials;
            $Permission = ((Get-Item "$NetworkPath\$FolderName").GetAccessControl('Access').Access | ? {$_.isInherited -eq $false}).IdentityReference.Value
        }
        else
        {
            $Permission = @(); $Permission += ((Get-Item "$NetworkPath\$FolderName").GetAccessControl('Access').Access | ? {$_.isInherited -eq $false}).IdentityReference.Value
            if($Permission.Length -gt 1)
            {
                $Permission = $Permission[0]
            }
        }
        
        $res.Path = "$FolderPath\$FolderName"
        $res.AccessPath = "NewPSDrive:\$FolderName"
        $res.FolderName = $FolderName
        $res.Permission = $Permission
        
        $paths += $res | Select Path, AccessPath, Permission, FolderName
    }

    if($paths.Count -gt 0)
    {

        foreach($path in $paths)
        {
            $acl = $null
            $User = Get-Random-Item -ItemList $Credentials; $Username = $User.UserName;
            $a = if($Username -eq $env:USERNAME){New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath} else {New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath -Credential $User}       
      

            
            $RemoveUser = @(); $RemoveUser += (Get-Item $path.AccessPath).GetAccessControl('Access').Access | ? {$_.isInherited -eq $false}
            $RemoveUsername = $RemoveUser[0].IdentityReference.Value.Split("\")[1];
    
            $RemovePermission = @((Get-Item $path.AccessPath).GetAccessControl('Access').Access | ? {$_.isInherited -eq $false})
            if($RemovePermission.Length -gt 1)
            {
                $Remove = ((Get-Item $path.AccessPath).GetAccessControl('Access').Access | ? {$_.isInherited -eq $false})[0]
            }
            else
            {
                $Remove = (Get-Item $path.AccessPath).GetAccessControl('Access').Access | ? {$_.isInherited -eq $false}
            }

            $acl = (Get-Item $path.AccessPath).GetAccessControl('Access')
            $acl.RemoveAccessRuleAll($Remove)
            $acl | Set-Acl $path.AccessPath

            $b = Remove-PSDrive -Name NewPSDrive

            FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue
        
            FSAC-Set-Results -Time (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') -Computer $ComputerName -Path $path.Path -Type (FSAC-Get-ItemType -FileName $path.FileName -FolderName $path.FolderName) -Action "PERMISSION REMOVED" -Object $RemoveUsername -User $Username
        }
    }
}

function FSAC-Delete-Item (
    [Parameter(Position=0,mandatory=$true)][string]$ComputerName,
    [Parameter(Position=1,mandatory=$true)][string]$FolderPath,
    [string]$FileName,
    [string]$FolderName,
    [array]$Credentials
)
{
    $paths = @(); $res = '' | Select AccessPath, FileName, FolderName    
    $ComputerName = Set-Computer-Name -ComputerName $ComputerName 
    $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")

    if(($FileName) -and (Test-Path "$NetworkPath\$FileName"))
    {
        $res.AccessPath = "NewPSDrive:\$FileName"
        $res.FileName = $FileName
        
        $paths += $res | Select Path, AccessPath, FileName    
    }
    
    if(($FolderName) -and (Test-Path "$NetworkPath\$FolderName"))
    {
        $res.AccessPath = "NewPSDrive:\$FolderName"
        $res.FolderName = $FolderName
        
        $paths += $res | Select Path, AccessPath, FolderName
    }
        
    foreach($path in $paths)
    {
        $User = Get-Random-Item -ItemList $Credentials; $Username = $User.UserName

        $a = if($Username -eq $env:USERNAME){New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath} else {New-PSDrive -Name NewPSDrive -PSProvider FileSystem -Root $NetworkPath -Credential $User}          
        $b = Remove-Item -Path $path.AccessPath -Force -Confirm:$false
        $c = Remove-PSDrive -Name NewPSDrive
    
        FSAC-Close-Connections -Path $NetworkPath -ErrorAction SilentlyContinue
        
        $ItemType = FSAC-Get-ItemType -FileName $path.FileName -FolderName $path.FolderName
        $ItemName = FSAC-Get-ItemName -FileName $path.FileName -FolderName $path.FolderName

        FSAC-Set-Results -Time (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') -Computer $ComputerName -Path $FolderPath -Type $ItemType -Action "DELETED" -Object $ItemName -User $Username
    }
}

function FSAC-Get-Columns (
    $Results
)
{
    $time = @(); $computer = @(); $path = @(); $type = @(); $action = @(); $object = @(); $user = @()
    
    foreach($Result in $Results)
    {
        $time += $Result.Time.Length; $computer += $Result.Computer.Length; $path += $Result.Path.Length; $type += $Result.Type.Length; $action += $Result.Action.Length; $object += $Result.Object.Length; $user += $Result.User.Length
    }
    
    $width = (($time | Sort-Object -Desc)[0] + 10), (($computer | Sort-Object -Desc)[0] + 10), (($path | Sort-Object -Desc)[0] + 10), (($type | Sort-Object -Desc)[0] + 10), 
    (($action | Sort-Object -Desc)[0] + 10), (($object | Sort-Object -Desc)[0] + 10), (($user | Sort-Object -Desc)[0] + 10)
    
    $columns = @{Expression={$_.Time}; Label="Time"; Width = $width[0]}, 
    @{Expression={$_.Computer}; Label="Computer"; Width = $width[1]},
    @{Expression={$_.Path}; Label="Path"; Width = $width[2]},
    @{Expression={$_.Type}; Label="Type"; Width = $width[3]},
    @{Expression={$_.Action}; Label="Action"; Width = $width[4]},
    @{Expression={$_.Object}; Label="Action Object"; Width = $width[5]},
    @{Expression={$_.User}; Label="Action By"; Width = $width[6]}

    $columns
}

function FSAC-File-Operations (
    [string]$ComputerName,
    [string]$FolderPath,
    [string]$FileName,
    [array]$Operations,
    [array]$Credentials

)
{
    $results = @(); $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")
    
    if(!(Test-Path "$NetworkPath\$FileName") -or ($Operations -contains "Create") -or ($Operations -contains "Delete"))
    {
        $c = FSAC-Create-Item -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials; $results += $c.Message
        if($Operations -contains "Write"){$results += FSAC-Update-File -ComputerName $ComputerName -FolderPath $FolderPath -FileName $c.FileName -Credentials $Credentials}
        if($Operations -contains "Read"){$results += FSAC-Read-File -ComputerName $ComputerName -FolderPath $FolderPath -FileName $c.FileName -Credentials $Credentials}
        if($Operations -contains "Rename"){$results += FSAC-Rename-Item -ComputerName $ComputerName -FolderPath $FolderPath -FileName $c.FileName -Credentials $Credentials}
        if($Operations -contains "Move"){$results += FSAC-Move-Item -ComputerName $ComputerName -FolderPath $FolderPath -FileName $c.FileName -Credentials $Credentials}
        if($Operations -contains "ChangeOwner"){$results += FSAC-Change-Owner -ComputerName $ComputerName -FolderPath $FolderPath -FileName $c.FileName -Credentials $Credentials}
        if($Operations -contains "AddPermission"){$results += FSAC-Add-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FileName $c.FileName -Credentials $Credentials}
        if($Operations -contains "ChangePermission"){$results += FSAC-Change-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FileName $c.FileName -Credentials $Credentials}
        if($Operations -contains "RemovePermission"){$results += FSAC-Remove-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FileName $c.FileName -Credentials $Credentials}
        if($Operations -contains "Delete"){$results += FSAC-Delete-Item -ComputerName $ComputerName -FolderPath $FolderPath -FileName $c.FileName -Credentials $Credentials}     
    }
    else
    {   
        if($Operations -contains "Write"){$results += FSAC-Update-File -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials}
        if($Operations -contains "Read"){$results += FSAC-Read-File -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials} 
        if($Operations -contains "Rename"){$results += FSAC-Rename-Item -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials}
        if($Operations -contains "Move"){$results += FSAC-Move-Item -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials}
        if($Operations -contains "ChangeOwner"){$results += FSAC-Change-Owner -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials}
        if($Operations -contains "AddPermission"){$results += FSAC-Add-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials}
        if($Operations -contains "ChangePermission"){$results += FSAC-Change-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials}
        if($Operations -contains "RemovePermission"){$results += FSAC-Remove-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials}
        if($Operations -contains "Delete"){$results += FSAC-Delete-Item -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName-Credentials $Credentials}
    }

    $results
}

function FSAC-Folder-Operations (
    [string]$ComputerName,
    [string]$FolderPath,
    [string]$FolderName,
    [array]$Operations,
    [array]$Credentials
)
{
    $results = @(); $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")
    
    if(!(Test-Path "$NetworkPath\$FolderName") -or ($Operations -contains "Create") -or ($Operations -contains "Delete"))
    {
        $c = FSAC-Create-Item -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials; $results += $c.Message
        if($Operations -contains "Rename"){$results += FSAC-Rename-Item -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $c.FolderName -Credentials $Credentials}
        if($Operations -contains "Move"){$results += FSAC-Move-Item -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $c.FolderName -Credentials $Credentials}
        if($Operations -contains "ChangeOwner"){$results += FSAC-Change-Owner -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $c.FolderName -Credentials $Credentials}
        if($Operations -contains "AddPermission"){$results += FSAC-Add-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $c.FolderName -Credentials $Credentials}
        if($Operations -contains "ChangePermission"){$results += FSAC-Change-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $c.FolderName -Credentials $Credentials}
        if($Operations -contains "RemovePermission"){$results += FSAC-Remove-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $c.FolderName -Credentials $Credentials}
        if($Operations -contains "Delete"){$results += FSAC-Delete-Item -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $c.FolderName -Credentials $Credentials}
    }
    else
    {    
        if($Operations -contains "Rename"){$results += FSAC-Rename-Item -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials}
        if($Operations -contains "Move"){$results += FSAC-Move-Item -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials}
        if($Operations -contains "ChangeOwner"){$results += FSAC-Change-Owner -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials}
        if($Operations -contains "AddPermission"){$results += FSAC-Add-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials}
        if($Operations -contains "ChangePermission"){$results += FSAC-Change-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials}
        if($Operations -contains "RemovePermission"){$results += FSAC-Remove-Permission -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials}
        if($Operations -contains "Delete"){$results += FSAC-Delete-Item -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials}
    }
  
    $results
}

function FS-Generate-Activity (
    [string]$ComputerName,
    [string]$FolderPath,
    [string]$FolderName,
    [string]$FileName,
    [switch]$Create,
    [switch]$Read,
    [switch]$Write,
    [switch]$Rename,
    [switch]$Move,
    [switch]$Delete,
    [switch]$ChangeOwner,
    [switch]$AddPermission,
    [switch]$ChangePermission,
    [switch]$RemovePermission,
    [array]$Credentials,
    [int]$Count,
    [int]$Delay
)
{    
    $parameters = @(); $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")
    
    if((!$ComputerName) -or ($ComputerName -eq 'localhost')) { $ComputerName = $env:COMPUTERNAME }
    if(!$FolderPath){ $FolderPath = "C:\Activity\Testing" } else{ $FolderPath = FSAC-Scrub-Path $FolderPath }

    $NetworkPath = "\\$ComputerName\" + $FolderPath.Replace(":", "$")
    if(!(Test-Path $NetworkPath))
    {
        FSAC-Create-Path -ComputerName $ComputerName -FolderPath $FolderPath | Format-Table
    }

    if(!$Credentials){$Credentials = @(New-Object System.Management.Automation.PSCredential -ArgumentList $env:USERNAME, ('password123' | ConvertTo-SecureString -AsPlainText -Force))}
    
    $Operations = @("Create", "Read", "Write", "Rename", "Move", "ChangeOwner", "AddPermission", "ChangePermission", "RemovePermission", "Delete")
    
    foreach($parameter in $PSBoundParameters.GetEnumerator()) {if($Operations -contains $parameter.Key) { $parameters += $parameter.Key }}
    
    if($parameters.Length -eq 0) {$Operations =  @("Read", "Write", "Rename", "Move", "ChangeOwner", "AddPermission", "ChangePermission", "RemovePermission")}
    elseif(($parameters.Length -eq 1) -and ($Create)) {$Operations = @("Create")}
    elseif(($parameters.Length -eq 1) -and ($Delete)) {$Operations = @("Create", "Read", "Write", "Rename", "Move", "ChangeOwner", "AddPermission", "ChangePermission", "RemovePermission", "Delete")}
    elseif($parameters.Length -gt 0){$Operations = $parameters}

    $fileOperations = $Operations; $folderOperations = $Operations | ? {($_ -notcontains "Read") -and ($_ -notcontains "Write")}
    
    if($Count -gt 0)
    {
        if(($FileName) -and (!$FolderName))
        {
            Write-Host ("`nCreating and/or acting on $Count new file(s): " + ($fileOperations -Join ", "))
            
            $i = 0
            do
            {
                $files = @()
                
                if ($i -eq 0)
                {             
                    $files += FSAC-File-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials -Operations $fileOperations
                }
                else
                {
                    $NextFile = $FileName.Split('.')[0] + $i + '.' + $FileName.Split('.')[1]
                    $files += FSAC-File-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FileName $NextFile -Credentials $Credentials -Operations $fileOperations
                }
                         
                $files | Format-Table -Property (FSAC-Get-Columns -Results $files)

                if($Delay) {Start-Sleep -Seconds $Delay}
                    
                $i++
            } while ($i -lt $Count)             
        }

        elseif((!$FileName) -and ($FolderName)) 
        {
            Write-Host ("`nCreating and/or acting on $Count new folder(s): " + ($folderOperations -Join ", "))
            
            $i = 0
            do
            {
                $folders = @()
                
                if ($i -eq 0)
                {
                    $folders += FSAC-Folder-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials -Operations $folderOperations
                }
                else
                {
                    $NextFolder = $FolderName + $i
                    $folders += FSAC-Folder-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $NextFolder -Credentials $Credentials -Operations $folderOperations
                }
               
                $folders | Format-Table -Property (FSAC-Get-Columns -Results $folders)

                if($Delay) {Start-Sleep -Seconds $Delay}
                    
                $i++   
            } while ($i -lt $Count)
        }

        elseif(($FileName) -and ($FolderName))
        {   
            Write-Host ("`nCreating or acting on $Count file(s) in path - $FolderPath`:`n`n Creating $Count new file(s) ($FileName): " + ($fileOperations -Join ", ") + "`n Creating $Count new folder(s) ($FolderName): " + ($folderOperations -Join ", "))
            
            $i = 0
            do
            {   
                $results = @()
             
                if($i -eq 0)
                {
                    $results += FSAC-File-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials -Operations $fileOperations
                    $results += FSAC-Folder-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials -Operations $folderOperations
                }
                else
                {
                    $NextFile = $FileName.Split('.')[0] + $i + '.' + $FileName.Split('.')[1]; $NextFolder = $FolderName + $i
                                      
                    $results += FSAC-File-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FileName $NextFile -Credentials $Credentials -Operations $fileOperations
                    $results += FSAC-Folder-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $NextFolder -Credentials $Credentials -Operations $folderOperations
                }
                   
                $results | Format-Table -Property (FSAC-Get-Columns -Results $results)

                if($Delay) {Start-Sleep -Seconds $Delay}
                    
                $i++   
            } while ($i -lt $Count)
        }
        
        else
        {                
            $FileName = 'FileTest.txt'; $FolderName = 'FolderTest'; 

            Write-Host ("`nCreating $Count file(s) and folder(s) in path - $FolderPath`:`n`n    FileTest.txt: " + ($fileOperations -Join ", ") + "`n    FolderTest: " + ($folderOperations -Join ", "))
                    
            $i = 0
            do
            {   
		$results = @()
		$FileTest = Test-Path "$NetworkPath\$FileName"; $FolderTest = Test-Path "$NetworkPath\$FolderName"
                
                if(($i -eq 0) -and (!$FileTest) -and (!$FolderTest))
               	{
                    $results += FSAC-File-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials -Operations $fileOperations
                    $results += FSAC-Folder-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials -Operations $folderOperations
                }
                else
                {
		    $j = 1; $k = 1

		    do
		    {
		        $NextFileName = $FileName.Split('.')[0] + $j + '.' + $FileName.Split('.')[1]
		    	$FileTest = Test-Path "$NetworkPath\$NextFileName"; 
		
			if(!$FileTest)
			{
                    	    $results += FSAC-File-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FileName $NextFileName -Credentials $Credentials -Operations $fileOperations
			}
			else
			{
			    $j++
			}
		    } while ($FileTest)

		    do
		    {
		        $NextFolderName = $FolderName + $k
		    	$FolderTest = Test-Path "$NetworkPath\$NextFolderName"; 
		
			if(!$FolderTest)
			{
	                    $results += FSAC-Folder-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $NextFolderName -Credentials $Credentials -Operations $folderOperations
			}
			else
			{
			    $k++
			}
		    } while ($FolderTest)
                }
         
      		$results | Format-Table -Property (FSAC-Get-Columns -Results $results)
                if($Delay) {Start-Sleep -Seconds $Delay}
                
                $i++   
            } while ($i -lt $Count) 
        }
    }
    else
    {
        if(($FileName) -and (!$FolderName))
        {
            Write-Host ("Creating and/or acting on 1 file: " + ($fileOperations -Join ", "))
          
            $files = @()
                              
            $files += FSAC-File-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials -Operations $fileOperations
            
            $files | Format-Table -Property (FSAC-Get-Columns -Results $files)

            if($Delay) {Start-Sleep -Seconds $Delay}           
        }

        elseif((!$FileName) -and ($FolderName)) 
        {
            Write-Host ("Creating and/or acting on 1 folder: " + ($fileOperations -Join ", "))
    
            $folders = @()
                           
            $folders += FSAC-Folder-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials -Operations $folderOperations
            
            $folders | Format-Table -Property (FSAC-Get-Columns -Results $folders)

            if($Delay) {Start-Sleep -Seconds $Delay}
        }

        elseif(($FileName) -and ($FolderName))
        {   
            Write-Host ("Creating and/or acting on 1 file and folder: " + ($fileOperations -Join ", "))
         
            $results = @()
                                  
            $results += FSAC-File-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials -Operations $fileOperations
            $results += FSAC-Folder-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials -Operations $folderOperations
            
            $results | Format-Table -Property (FSAC-Get-Columns -Results $results)

            if($Delay) {Start-Sleep -Seconds $Delay}

            if($Delay) {Start-Sleep -Seconds $Delay}
        }

        elseif((!$FileName) -and (!$FolderName))
        {
            $children = @(); $children += FSAC-Get-Children -ComputerName $ComputerName -FolderPath $FolderPath
            if(($children[0] -ne $null) -and ($Operations -notcontains "Create") -and ($Operations -notcontains "Delete"))
            {
                $fileList = @(); $fileList += FSAC-Get-Children -ComputerName $ComputerName -FolderPath $FolderPath | ? {$_.PSIsContainer -eq $false}

                if($fileList[0] -ne $null) 
                {
                    Write-Host ("`n" + $fileList.Length + " valid file(s) will be acted on: " + ($fileOperations -Join ", "))

                    foreach($File in $fileList)
                    {
                        $files = @()
                        
                        $files += FSAC-File-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FileName $File.Name -Credentials $Credentials -Operations $fileOperations
                        
                        $files | Format-Table -Property (FSAC-Get-Columns -Results $files)
                            
                        if($Delay) {Start-Sleep -Seconds $Delay}                    
                    }
                }

                $folderList = @(); $folderList += FSAC-Get-Children -ComputerName $ComputerName -FolderPath $FolderPath | ? {$_.PSIsContainer -eq $true}

                if($folderList[0] -ne $null) 
                {
                    Write-Host ("`n" + $folderList.Length + " valid folder(s) will be acted on: " + ($folderOperations -Join ", "))

                    foreach($Folder in $folderList)
                    {
                        $folders = @()
                        
                        $folders += FSAC-Folder-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $Folder.Name -Credentials $Credentials -Operations $folderOperations
                        
                        $folders | Format-Table -Property (FSAC-Get-Columns -Results $folders)

                        if($Delay) {Start-Sleep -Seconds $Delay}
                    }               
                }
            }
            else
            {                
                $results = @(); $FolderName = 'FolderTest'; $FileName = 'FileTest.txt'

                Write-Host ("`nCreating or acting on 1 file and folder in path - $FolderPath`:`n`n    FileTest.txt: " + ($fileOperations -Join ", ") + "`n    FolderTest: " + ($folderOperations -Join ", "))
                                                                  
                $results += FSAC-File-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FileName $FileName -Credentials $Credentials -Operations $fileOperations
                $results += FSAC-Folder-Operations -ComputerName $ComputerName -FolderPath $FolderPath -FolderName $FolderName -Credentials $Credentials -Operations $folderOperations
                
                $results | Format-Table -Property (FSAC-Get-Columns -Results $results)

                if($Delay) {Start-Sleep -Seconds $Delay} 
            }
        }
    }
}

function FS-Generate-ADUsers (
    [Parameter(Position=0,mandatory=$true)][string]$ComputerName,
    [Parameter(Position=1,mandatory=$true)][string]$OUPath,
    [int]$Count,
    [switch]$CreateNewUsers
)
{
    $Credentials = @()
    if((!$Count) -or ($Count -eq 0)) {$Count = 1}
    if(!$ComputerName) {$ComputerName = $env:COMPUTERNAME}

    Import-Module (Find-Module-Path + "\Microsoft.ActiveDirectory.Management.dll") -WarningAction SilentlyContinue

    $NewOUPath = 'OU=RandomUsers,' + $OUPath

    try
    {
        $exists = Get-ADOrganizationalUnit $NewOUPath
    }
    catch
    {
        try
        {
            New-ADOrganizationalUnit -Name RandomUsers -Path $OUPath -ProtectedFromAccidentalDeletion $false
        }
        catch
        {
           $NewOUPath = $OUPath
        }
    }

    $currentUsernames = (Get-ADUser -Filter * -SearchBase $NewOUPath).SamAccountName
    
    if(($CreateNewUsers) -or (!$currentUsernames))
    {
        $newUsers = FSAC-Get-DomainUsers -OUPath $OUPath -NewUserCount $Count; $newUsers.Message
        $Usernames = $newUsers.Usernames
        FSAC-Add-LocalAdmins -Computer $ComputerName -Users $Usernames

        $Credentials += FSAC-Get-Credentials -Users $Usernames -Count $Count
    }
    else
    {
        $Credentials += FSAC-Get-Credentials -Users $currentUsernames -Count $Count
    }

    $Credentials
}