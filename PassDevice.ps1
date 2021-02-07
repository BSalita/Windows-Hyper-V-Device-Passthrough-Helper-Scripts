# configurable parameters
$VM = 'Win-VM' # name of VM
$DeviceClass = 'Display'
$DeviceFriendlyName = 'NVIDIA GeForce GTX 1660 Ti'
$VMMemoryStartupBytes = 8GB
$VMAutomaticStopAction = 'TurnOff'
$VMGuestControlledCacheTypes = $true
$VMLowMemoryMappedIoSpace = 512MB
$VMHighMemoryMappedIoSpace = 8GB

Write-Host "VMName: $VM"
Write-Host "DeviceClass: $DeviceClass"
Write-Host "DeviceFriendlyName: $DeviceFriendlyName"
Write-Host "VMMemoryStartupBytes: $VMMemoryStartupBytes"
Write-Host "VMAutomaticStopAction: $VMAutomaticStopAction"
Write-Host "VMGuestControlledCacheTypes: $VMGuestControlledCacheTypes"
Write-Host "VMLowMemoryMappedIoSpace: $VMLowMemoryMappedIoSpace"
Write-Host "VMHighMemoryMappedIoSpace: $VMHighMemoryMappedIoSpace"

# get table of devices having class of $DeviceClass. autosize to prevent truncation of InstanceId
Write-Host "`nList of $DeviceClass devices"
Get-PnpDevice -class $DeviceClass | ft -AutoSize

# select the friendly name of the device you want to pass
Write-Host "Attempting to pass $DeviceFriendlyName"

# get InstanceId of device
$DeviceInstanceId = (Get-PnpDevice -FriendlyName $DeviceFriendlyName).InstanceId
Write-Host "`n$DeviceFriendlyName has InstanceId of $DeviceInstanceId"

# get everything before first &
$DeviceId = $DeviceInstanceId.split('&')[0]
Write-Host "`n$DeviceFriendlyName has Device ID of $DeviceId"

# get all devices that start with DeviceId
$DeviceGroup = Get-PnpDevice -present | where {$_.InstanceId.startswith($DeviceId) }
Write-Host "`nList of devices in group $DeviceId"
$DeviceGroup | ft -autosize

$DeviceGroupInstanceIds = $DeviceGroup.InstanceId
Write-Host "InstanceIDs of device group: $DeviceGroupInstanceIds`n"

$DeviceProperties = Get-PnpDeviceProperty -KeyName DEVPKEY_Device_LocationPaths -InstanceId $DeviceGroupInstanceIds
Write-Host "Device properties of group: $DeviceProperties`n"

$DeviceLocationPaths = $DeviceProperties.Data
Write-Host "LocationPaths of device group: $DeviceLocationPaths`n"

# Only want PCIROOT devices
$DeviceLocationPaths = $DeviceLocationPaths | Where-Object {$_.startswith('PCIROOT')}
Write-Host "LocationPaths of PCIROOT devices in group: $DeviceLocationPaths`n"

# disable all devices in group
Write-Host "Disabling: $DeviceGroupInstanceIds"
Disable-PnpDevice -InstanceId $DeviceGroupInstanceIds -Confirm:$false
Start-Sleep -Seconds 1 # fix some timing issue

# get InfNames matching InstanceId
$Infs = Get-WmiObject Win32_PnPSignedDriver | where-object {$_.DeviceId -eq $DeviceInstanceId} | select DeviceId, InfName
Write-Host "`nInfs: $Infs"

# get driver path for devices
$DevicePaths = Get-WindowsDriver -Online -All | where-object {$_.ClassName -eq $DeviceClass -And $_.Driver -eq $Infs.InfName} | select Driver, OriginalFileName, ProviderName, Date, Version
Write-Host "`nDriver paths: $DevicePaths"

# list of host dlls to copy into VM's C:\WINDOWS\System32
$DeviceDllPaths = (Get-WmiObject Win32_VideoController).InstalledDisplayDrivers.split(',') | Get-Unique
Write-Host "`nList of host dlls: $DeviceDllPaths"

# list of host directories in C:\WINDOWS\System32\DriverStore\FileRepository to copy to VM's HostDriverStore
$DeviceInfDirs = $DeviceDllPaths | ForEach-Object {($_.split('\\') | Select -first 6) -Join '\'} | Get-Unique
Write-Host "`nList of directories: $DeviceInfDirs"

Write-Host "`nSet StaticMemory, set MemoryStartupBytes to size, set AutomaticStopAction to TurnOff"
Set-VM -name $vm -StaticMemory -MemoryStartupBytes $VMMemoryStartupBytes -AutomaticStopAction $VMAutomaticStopAction

# Enhance GPU caching performance by setting write-combining
Write-Host "`nSet GuestControlledCacheTypes to True"
Set-VM $VM -GuestControlledCacheTypes $VMGuestControlledCacheTypes

Write-Host "`nSet LowMemoryMappedIoSpace to $VMLowMemoryMappedIoSpace and HighMemoryMappedIoSpace to $VMHighMemoryMappedIoSpace"
Set-VM $VM -LowMemoryMappedIoSpace $VMLowMemoryMappedIoSpace  -HighMemoryMappedIoSpace $VMHighMemoryMappedIoSpace

# dismount device from host
Write-Host "`nDismount devices from host"
$DeviceLocationPaths | foreach { Start-Sleep -Seconds 1 | Dismount-VMHostAssignableDevice -Force -LocationPath $_ }

# add device to VM
Write-Host "`nAdd devices to $VM"
$DeviceLocationPaths | foreach { Start-Sleep -Seconds 1 | Add-VMAssignableDevice -VMName $VM -LocationPath $_ }

# View connected device
Write-Host "`nList of devices assigned to $VM"
Get-VMAssignableDevice -VMName $VM

#Start-VM -VMName $VMf
