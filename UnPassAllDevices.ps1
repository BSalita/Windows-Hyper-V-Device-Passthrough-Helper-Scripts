# Help script for unpassing all assigned devices in VM returning them to host.
# Only processes devices which are in a disabled state.
# Status: WIP

# configure these parameters
$VM = 'Win-VM' # name of VM
Write-Host "All devices assigned to $VM will be returned to host"

# Remove all devices from a single VM
Remove-VMAssignableDevice -VMName $VM -Verbose

# Return all devices to host
Get-VMHostAssignableDevice | Mount-VmHostAssignableDevice -Verbose

# Enable devices currently disable ($_.Problem -eq 22).
Get-PnpDevice | Where-Object {$_.Problem -eq 22} | Enable-PnpDevice -Confirm:$false
