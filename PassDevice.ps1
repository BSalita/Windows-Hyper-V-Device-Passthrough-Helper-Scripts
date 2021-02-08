# Helper script for passing through host device to VM. 
# Status WIP

# configure these parameters
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
Write-Host "`nList of $DeviceClass devices:"
Get-PnpDevice -class $DeviceClass -Present | ft -AutoSize

# select the friendly name of the device you want to pass
Write-Host "Attempting to pass $DeviceFriendlyName"

# get InstanceId of device
$DeviceInstanceId = (Get-PnpDevice -FriendlyName $DeviceFriendlyName).InstanceId
Write-Host "`n$DeviceFriendlyName has InstanceId of $DeviceInstanceId"

# get everything before first &
$DeviceId = $DeviceInstanceId.split('&')[0]
Write-Host "`n$DeviceFriendlyName has Device ID of $DeviceId"

# get all devices that start with DeviceId
Write-Host "`nList of all $DeviceClass devices in group ${DeviceId}:"
$DeviceGroup = Get-PnpDevice -Present | Where-Object {$_.InstanceId.startswith($DeviceId) }
$DeviceGroup | ft -autosize

# Only need to release devices with status of OK from host
Write-Host "List of transferable devices in group ${DeviceId}:"
$DeviceGroup = $DeviceGroup | Where-Object {$_.Status -EQ 'OK' }
$DeviceGroup | ft -autosize

if ($DeviceGroup.count -EQ 0)
{
	Write-Host "`nNo transferable devices available. Exiting."
	Exit
}

Write-Host "List of InstanceIDs of group:"
$DeviceGroupInstanceIds = $DeviceGroup.InstanceId
$DeviceGroupInstanceIds

Write-Host "`nList LocationPaths of group:"
$DeviceLocationPaths = $DeviceGroupInstanceIds | ForEach-Object { Get-PnpDeviceProperty -KeyName DEVPKEY_Device_LocationPaths -InstanceId $_ } | Select InstanceId, Data
$DeviceLocationPaths | ft -autosize

if ($DeviceGroupInstanceIds.count -NE $DeviceLocationPaths.count)
{
	Write-Error "`nCount of InstanceIDs doesn't match count of LocationPaths. Exiting."
	Exit
}

# Only want PCIROOT devices
Write-Host "List of LocationPaths of PCIROOT of group:"
$DeviceLocationPaths = $DeviceLocationPaths.Data | Where-Object {$_.startswith('PCIROOT')} | Get-Unique
$DeviceLocationPaths

# disable all devices in group
Write-Host "`nDisabling group:"
$DeviceGroupInstanceIds
Disable-PnpDevice -InstanceId $DeviceGroupInstanceIds -Confirm:$false

# get InfNames matching InstanceId
Write-Host "`nList of Infs of device drivers:"
$Infs = Get-WmiObject Win32_PnPSignedDriver | where-object {$_.DeviceId -eq $DeviceInstanceId} | select DeviceId, InfName
$Infs | ft -autosize

# get path of drivers
Write-Host "Retrieving list of Device driver paths ..."
$DevicePaths = Get-WindowsDriver -Online -All | where-object {$_.ClassName -eq $DeviceClass -And $_.Driver -eq $Infs.InfName} | select Driver, OriginalFileName, ProviderName, Date, Version
$DevicePaths | ft -autosize

# list of host dlls to copy into VM's C:\WINDOWS\System32
Write-Host "List of host dlls:"
$DeviceDllPaths = (Get-WmiObject Win32_VideoController).InstalledDisplayDrivers.split(',') | Get-Unique
$DeviceDllPaths

# list of host directories in C:\WINDOWS\System32\DriverStore\FileRepository to copy to VM's HostDriverStore
Write-Host "`nList of directories:"
$DeviceInfDirs = $DeviceDllPaths | ForEach-Object {($_.split('\\') | Select -first 6) -Join '\'} | Get-Unique
$DeviceInfDirs

Write-Host "`nSet StaticMemory, set MemoryStartupBytes to size, set AutomaticStopAction to TurnOff"
Set-VM -name $vm -StaticMemory -MemoryStartupBytes $VMMemoryStartupBytes -AutomaticStopAction $VMAutomaticStopAction

# Enhance GPU caching performance by setting write-combining
Write-Host "`nSet GuestControlledCacheTypes to True"
Set-VM $VM -GuestControlledCacheTypes $VMGuestControlledCacheTypes

Write-Host "`nSet LowMemoryMappedIoSpace to $VMLowMemoryMappedIoSpace and HighMemoryMappedIoSpace to $VMHighMemoryMappedIoSpace"
Set-VM $VM -LowMemoryMappedIoSpace $VMLowMemoryMappedIoSpace  -HighMemoryMappedIoSpace $VMHighMemoryMappedIoSpace

# dismount device from host
Write-Host "`nDismounting devices from host ..."
$DeviceLocationPaths | foreach { Dismount-VMHostAssignableDevice -Force -LocationPath $_ }

# add device to VM
Write-Host "`nAdding devices to $VM ..."
$DeviceLocationPaths | foreach { Add-VMAssignableDevice -VMName $VM -LocationPath $_ }

# View connected device
Write-Host "`nList of devices assigned to ${VM}:"
Get-VMAssignableDevice -VMName $VM

# Start VM
#Start-VM -VMName $VMf
