# Helper script for unpassing device currently assigned to VM returning device to host.
# Status: WIP

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
Get-PnpDevice -class $DeviceClass | ft -AutoSize

# select the friendly name of the device you want to pass
Write-Host "Attempting to unpass $DeviceFriendlyName"

# get InstanceId of device
$DeviceInstanceId = (Get-PnpDevice -FriendlyName $DeviceFriendlyName).InstanceId
Write-Host "`n$DeviceFriendlyName has InstanceId of $DeviceInstanceId"

# get everything before first &
$DeviceId = $DeviceInstanceId.split('&')[0]
Write-Host "`n$DeviceFriendlyName has Device ID of $DeviceId"

# Devices already assigned to VM
Write-Host "`nList of all devices assigned to $VM"
$AssignableDevices = Get-VMAssignableDevice -VMName $VM
$AssignableDevices | ft -autosize

# get all devices that start with DeviceId
Write-Host "`nList of all $DeviceClass devices in group ${DeviceId}:"
$DeviceGroup = Get-PnpDevice | Where-Object {$_.InstanceId.startswith($DeviceId) }
$DeviceGroup | ft -autosize

# Only need to release devices with status of OK from host
Write-Host "List of transferable devices in group ${DeviceId}:"
$DeviceGroup = $DeviceGroup | Where-Object {$_.Status -EQ 'Unknown' -And $_.InstanceId.Insert(3,'P') -in $AssignableDevices.InstanceId }
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

# Remove device from VM
Write-Host "`nRemoving devices from $VM"
$DeviceLocationPaths | foreach { Remove-VMAssignableDevice -VMName $VM -LocationPath $_ }

# Remount device to Host
Write-Host "`nMounting devices to host"
$DeviceLocationPaths | foreach { Mount-VMHostAssignableDevice -LocationPath $_ }

# enable all devices in group
Write-Host "`nEnabling devices on host:"
$DeviceGroupInstanceIds
Enable-PnpDevice -InstanceId $DeviceGroupInstanceIds -Confirm:$false
