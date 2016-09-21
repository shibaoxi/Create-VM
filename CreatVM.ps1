#作者：史宝玺 | 版本： V1.0 | 修改日期： 2016.2.22 | 说明：创建脚本 
#作者：史宝玺 | 版本： V1.1 | 修改日期： 2016.2.22 | 说明：增加虚拟机名称判断功能【66-71】 
#作者：史宝玺 | 版本： V1.2 | 修改日期： 2016.2.23 | 说明：修复VMName 为数组类型，创建虚拟机报错 


param(
	[ValidateNotNullOrEmpty()]
	[String]$UnattendedContent,
#虚拟机存放路径，根据实际需求定义
    [ValidateNotNullOrEmpty()]
	[String]$VMlocation='D:\Labvm',
    [ValidateNotNullOrEmpty()]
	[String]$NewVMGeneration=2,
#虚拟交换机定义
    [ValidateNotNullOrEmpty()]
	[String]$VMSwitch1='lan',
    [ValidateNotNullOrEmpty()]
	[String]$VMswitch2='labinside',
	[ValidateNotNullOrEmpty()]
	[String]$Edition = 'CORESYSTEMSERVER_INSTALL',
    [ValidateNotNullOrEmpty()]
    [String]$CacheFolder,		
    [ValidateNotNullOrEmpty()]
    [String]$VHDLocation='D:\temp',
	[ValidateNotNullOrEmpty()]
	[String]$Timezone = 'China Standard Time',
    [ValidateNotNullOrEmpty()]
	[String]$WorkFolder ="C:\temp"
)

$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent();
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID);

# Get the security principal for the administrator role
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator;

# Check to see if we are currently running as an administrator
if ($myWindowsPrincipal.IsInRole($adminRole)) {
    # We are running as an administrator, so change the title and background colour to indicate this
    $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)";

    } else {
    # We are not running as an administrator, so relaunch as administrator

    # Create a new process object that starts PowerShell
    $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";

    # Specify the current script path and name as a parameter with added scope and support for scripts with spaces in it's path
    $newProcess.Arguments = "& '" + $script:MyInvocation.MyCommand.Path + "'"

    # Indicate that the process should be elevated
    $newProcess.Verb = "runas";

    # Start the new process
    [System.Diagnostics.Process]::Start($newProcess) | Out-Null;

    # Exit from the current, unelevated, process
    Exit;
    }

#$Credential=$myWindowsID.Name
#Set-Item WSMan:\localhost\Client\TrustedHosts 192.168.5.10
#Enter-PSSession -ComputerName 192.168.5.10 -Credential $Credential

#输入基础信息
$getname=(Get-VM).VMName
[array]$VMName=Read-Host("请输入虚拟机名称") 
while($VMName -iin $getname ) {
Write-Verbose -Message "虚拟机名称已存在" -Verbose
[array]$VMName=Read-Host("请重新输入虚拟机名称") 
}
[string]$VMName=$VMName
[int64]$VMMemory=Read-Host("请输入内存大小，默认单位为GB")
$VMMemory=$VMMemory*1gb
$VMProcessor=Read-Host("请输入处理器数量")
$AdministratorPassword=Read-Host("请输入所创建虚拟机的管理密码")
$RegisteredOwner=Read-Host("请输入注册者信息")
$RegisteredCorporation=Read-Host("公司名称")

#创建临时文件夹
New-Item $WorkFolder -ItemType Directory
New-Item $VHDLocation -ItemType Directory

# 挂载磁盘文件
Copy-Item D:\VHD\Winserver2016TP4_CN.vhdx $VHDLocation
Rename-Item -Path $VHDLocation\* -NewName "$VMName.vhdx"
Mount-WindowsImage -ImagePath $VHDLocation\$VMName.vhdx -Index 1 -Path I:
# Apply Unattended File
If (($UnattendedContent -eq $null) -or ($UnattendedContent -eq '')) {
# For some reason applying computername in the Offline Servicing Phase doesn't work
# So it can be applied in the Specialize phase...

$UnattendedContent = [String] @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <servicing></servicing>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>$VMName</ComputerName>
<ProductKey>JGNV3-YDJ66-HJMJP-KVRXG-PDGDH</ProductKey>
        </component>
 </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <SkipUserOOBE>true</SkipUserOOBE>
            </OOBE>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$AdministratorPassword</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
            <TimeZone>$TimeZone</TimeZone>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserLocale>zh_CN</UserLocale>
            <SystemLocale>zh_CN</SystemLocale>
            <UILanguage>zh_CN</UILanguage>
            <InputLocale>0409:00000409</InputLocale>
        </component>
    </settings>
</unattend>

"@
}

Write-Verbose -Message "Assigning Unattended.XML file to $VMName.vhdx" -Verbose
$UnattendFile = Join-Path -Path $WorkFolder -ChildPath 'Unattend.xml'
Set-Content -Path $UnattendFile -Value $UnattendedContent
Use-WindowsUnattend -Path I: –UnattendPath $UnattendFile
$null = Copy-Item -Path $UnattendFile -Destination "I:\windows\panther"
#卸载磁盘镜像
Dismount-WindowsImage -Path I: -Save

#创建虚拟机
New-VM -Name $VMName -Generation 2 -MemoryStartupBytes $VMMemory -SwitchName $VMswitch1 -Path $VMLocation -NoVHD 
New-Item "$VMLocation\$VMName\Virtual Hard Disks" -ItemType directory
Copy-Item "$VHDLocation\$VMName.vhdx" -Destination "$VMLocation\$VMName\Virtual Hard Disks"
Add-VMHardDiskDrive -VMName $VMName -Path "$VMLocation\$VMName\Virtual Hard Disks\$VMName.vhdx" 
Set-VMProcessor -VMName $VMName -Count $VMProcessor
Add-VMNetworkAdapter -VMName $VMName  -SwitchName $VMswitch2
#判断是否需要创建数据磁盘
$Prompt=Read-Host "是否需要添加数据磁盘?，默认是127GB（Y|N）"
if($Prompt -like "y")
{
 New-VHD -Path "$VMLocation\$VMName\Virtual Hard Disks\$VMName Data.vhdx" -SizeBytes 127GB -Dynamic
 Add-VMHardDiskDrive -VMName $VMName -Path "$VMLocation\$VMName\Virtual Hard Disks\$VMName Data.vhdx"
}

#删除临时文件
Remove-Item $VHDLocation -Recurse
Remove-Item $WorkFolder -Recurse


#（可选）是否启用嵌套虚拟化
Write-Host "是否启用$VMName 嵌套虚拟化技术（嵌套虚拟化技术可使你的虚拟机里面启用虚拟化技术）?" -ForegroundColor Yellow
$input=Read-Host "输入Y是启用，输入N是不启用（Y|N）"
if($input -like "y"){



#
# Get Vm Information
#

$vm = Get-VM -Name $VMName

$vmInfo = New-Object PSObject
    
# VM info
Add-Member -InputObject $vmInfo NoteProperty -Name "ExposeVirtualizationExtensions" -Value $false
Add-Member -InputObject $vmInfo NoteProperty -Name "DynamicMemoryEnabled" -Value $vm.DynamicMemoryEnabled
Add-Member -InputObject $vmInfo NoteProperty -Name "SnapshotEnabled" -Value $false
Add-Member -InputObject $vmInfo NoteProperty -Name "State" -Value $vm.State
Add-Member -InputObject $vmInfo NoteProperty -Name "MacAddressSpoofing" -Value ((Get-VmNetworkAdapter -VmName $vmName).MacAddressSpoofing)
Add-Member -InputObject $vmInfo NoteProperty -Name "MemorySize" -Value (Get-VMMemory -VmName $vmName).Startup


# is nested enabled on this VM?
$vmInfo.ExposeVirtualizationExtensions = (Get-VMProcessor -VM $vm).ExposeVirtualizationExtensions

Write-Host "This script will set the following for $vmName in order to enable nesting:"
    
$prompt = $false;

# Output text for proposed actions
if ($vmInfo.State -eq 'Saved') {
    Write-Host "\tSaved state will be removed"
    $prompt = $true
}
if ($vmInfo.State -ne 'Off' -or $vmInfo.State -eq 'Saved') {
    Write-Host "Vm State:" $vmInfo.State
    Write-Host "    $vmName will be turned off"
    $prompt = $true         
}
if ($vmInfo.ExposeVirtualizationExtensions -eq $false) {
    Write-Host "    Virtualization extensions will be enabled"
    $prompt = $true
}
if ($vmInfo.DynamicMemoryEnabled -eq $true) {
    Write-Host "    Dynamic memory will be disabled"
    $prompt = $true
}
if($vmInfo.MacAddressSpoofing -eq 'Off'){
    Write-Host "    Optionally enable mac address spoofing"
    $prompt = $true
}
if($vmInfo.MemorySize -lt $4GB) {
    Write-Host "    Optionally set vm memory to 4GB"
    $prompt = $true
}

if(-not $prompt) {
    Write-Host "    None, vm is already setup for nesting"
    
}

Write-Host "Input Y to accept or N to cancel:" -NoNewline

$char = Read-Host

while(-not ($char.StartsWith('Y') -or $char.StartsWith('N'))) {
    Write-Host "Invalid Input, Y or N" 
    $char = Read-Host
}


if($char.StartsWith('Y')) {
    if ($vmInfo.State -eq 'Saved') {
        Remove-VMSavedState -VMName $vmName
    }
    if ($vmInfo.State -ne 'Off' -or $vmInfo.State -eq 'Saved') {
        Stop-VM -VMName $vmName
    }
    if ($vmInfo.ExposeVirtualizationExtensions -eq $false) {
        Set-VMProcessor -VMName $vmName -ExposeVirtualizationExtensions $true
    }
    if ($vmInfo.DynamicMemoryEnabled -eq $true) {
        Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $false
    }

    # Optionally turn on mac spoofing
    if($vmInfo.MacAddressSpoofing -eq 'Off') {
        Write-Host "Mac Address Spoofing isn't enabled (nested guests won't have network)." -ForegroundColor Yellow 
        Write-Host "Would you like to enable MAC address spoofing? (Y/N)" -NoNewline
        $input = Read-Host

        if($input -eq 'Y') {
            Set-VMNetworkAdapter -VMName $vmName -MacAddressSpoofing on
        }
        else {
            Write-Host "Not enabling Mac address spoofing."
        }

    }

    if($vmInfo.MemorySize -lt $4GB) {
        Write-Host "VM memory is set less than 4GB, without 4GB or more, you may not be able to start VMs." -ForegroundColor Yellow
        Write-Host "Would you like to set Vm memory to 4GB? (Y/N)" -NoNewline
        $input = Read-Host 

        if($input -eq 'Y') {
            Set-VMMemory -VMName $vmName -StartupBytes $4GB
        }
        else {
            Write-Host "Not setting Vm Memory to 4GB."
        }
    }
    
}

if($char.StartsWith('N')) {
    Write-Host "Exiting..."
    
}

Write-Host 'Invalid input'



}

#检查是否已经启用嵌套虚拟化
$vm = Get-VM -Name $VMName
$vmInfo = New-Object PSObject   
# VM info
Add-Member -InputObject $vmInfo NoteProperty -Name "ExposeVirtualizationExtensions" -Value $false
Add-Member -InputObject $vmInfo NoteProperty -Name "DynamicMemoryEnabled" -Value $vm.DynamicMemoryEnabled
Add-Member -InputObject $vmInfo NoteProperty -Name "SnapshotEnabled" -Value $false
Add-Member -InputObject $vmInfo NoteProperty -Name "State" -Value $vm.State
Add-Member -InputObject $vmInfo NoteProperty -Name "MacAddressSpoofing" -Value ((Get-VmNetworkAdapter -VmName $vmName).MacAddressSpoofing)
Add-Member -InputObject $vmInfo NoteProperty -Name "MemorySize" -Value (Get-VMMemory -VmName $vmName).Startup
# is nested enabled on this VM?
$vmInfo.ExposeVirtualizationExtensions = (Get-VMProcessor -VM $vm).ExposeVirtualizationExtensions

$prompt = $false;
# Output text for proposed actions
if ($vmInfo.State -eq 'Saved') {
    Write-Host "\tSaved state will be removed"
    $prompt = $true
}
if ($vmInfo.State -ne 'Off' -or $vmInfo.State -eq 'Saved') {
    Write-Host "Vm State:" $vmInfo.State
    Write-Host "    $vmName will be turned off"
    $prompt = $true         
}
if ($vmInfo.ExposeVirtualizationExtensions -eq $false) {
    Write-Host "    Virtualization extensions will be enabled"
    $prompt = $true
}
if ($vmInfo.DynamicMemoryEnabled -eq $true) {
    Write-Host "    Dynamic memory will be disabled"
    $prompt = $true
}
if($vmInfo.MacAddressSpoofing -eq 'Off'){
    Write-Host "    Optionally enable mac address spoofing"
    $prompt = $true
}
if($vmInfo.MemorySize -lt $4GB) {
    Write-Host "    Optionally set vm memory to 4GB"
    $prompt = $true
}

if(-not $prompt) {
    Write-Verbose -Message "嵌套虚拟化已启用，正在初始化$VMName ..." -Verbose
    Write-Host "此过程需要几分钟时间..." -ForegroundColor Green
    Start-VM -VMName $VMName
    

do{$vmip=(Get-VMNetworkAdapter -VMName $VMName |select IPAddresses).IPAddresses
}
until($vmip -ne $Null)
$vmip=(Get-VMNetworkAdapter -VMName $VMName  |select IPAddresses).IPAddresses[0]

Write-Host "$VMName 已创建完成，请使用远程桌面连接到$vmip" -ForegroundColor Yellow
}

else{
      Write-Verbose -Message "未启用嵌套虚拟化，正在初始化$VMName ..." -Verbose
       Write-Host "此过程需要几分钟时间..." -ForegroundColor Green
      Start-VM -VMName $VMName
      do{$vmip=(Get-VMNetworkAdapter -VMName $VMName  |select IPAddresses).IPAddresses
         }
      until($vmip -ne $Null)
      $vmip=(Get-VMNetworkAdapter -VMName $VMName  |select IPAddresses).IPAddresses[0]


Write-Host "$VMName 已创建完成，请使用远程桌面连接到$vmip" 
}   


