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
Get-PnpDevice -class $DeviceClass | ft -AutoSize

Write-Host "Attempting to pass $DeviceFriendlyName"

# get InstanceId of $DeviceFriendlyName
$DeviceInstanceId = (Get-PnpDevice -FriendlyName $DeviceFriendlyName).InstanceId
Write-Host "`n$DeviceFriendlyName has InstanceId of $DeviceInstanceId"

# get everything before first &
$DeviceId = $DeviceInstanceId.split('&')[0]
Write-Host "`n$DeviceFriendlyName has Device ID of $DeviceId"

# get all devices that start with DeviceId. Were assuming they form an IOMMU group and must be grouped.
$DeviceGroup = Get-PnpDevice | where {$_.InstanceId.startswith($DeviceId) }
Write-Host "`nList of devices in group $DeviceId"
$DeviceGroup | ft -autosize

$DeviceGroupInstanceIds = $DeviceGroup.InstanceId
Write-Host "InstanceIDs of device group: $DeviceGroupInstanceIds`n"

$DeviceLocationPaths = (Get-PnpDeviceProperty -KeyName DEVPKEY_Device_LocationPaths -InstanceId $DeviceGroupInstanceIds).Data
Write-Host "LocationPaths of device group: $DeviceLocationPaths`n"

# View connected device
Write-Host "List of devices assigned to $VM"
Get-VMAssignableDevice -VMName $VM

# Remove device from VM
Write-Host "`nRemoving devices from $VM"
$DeviceLocationPaths | foreach { Start-Sleep -Seconds 1 | Remove-VMAssignableDevice -VMName $VM -LocationPath $_ }

# Remount device to Host
Write-Host "`nMounting devices to host"
$DeviceLocationPaths | foreach { Start-Sleep -Seconds 1 | Mount-VMHostAssignableDevice -LocationPath $_ }
Start-Sleep -Seconds 1

# enable all devices in group
Write-Host "`nEnabling devices on host: $DeviceGroupInstanceIds"
Enable-PnpDevice -InstanceId $DeviceGroupInstanceIds -Confirm:$false
Start-Sleep -Seconds 1

# Alternative implementations using all devices intstead of individual items

# Remove all devices from a single VM
# Remove-VMAssignableDevice -VMName $VM -Verbose
# Start-Sleep -Seconds 1

# Return all to host
# Get-VMHostAssignableDevice | Mount-VmHostAssignableDevice -Verbose
# Start-Sleep -Seconds 1

# Enable it in devmgmt.msc
# Get-PnpDevice -PresentOnly | Enable-PnpDevice -Confirm:$false -Verbose
# Start-Sleep -Seconds 1
