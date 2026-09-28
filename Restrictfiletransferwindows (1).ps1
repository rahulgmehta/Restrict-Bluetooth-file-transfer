# PowerShell script to disable Bluetooth file transfer while allowing other Bluetooth devices
# Requires: PowerShell 3.0 or later
# Run as: SYSTEM account

# Target list of allowed Bluetooth service UUIDs (excluding file transfer services)
# Add or remove UUIDs as needed for your environment.
$TargetServicesAllowedList = @(
    "{0000111E-0000-1000-8000-00805F9B34FB}",  # Generic Audio
    "{00001203-0000-1000-8000-00805F9B34FB}",  # Audio Sink
    "{00001108-0000-1000-8000-00805F9B34FB}",  # Headset AG
    "{00001200-0000-1000-8000-00805F9B34FB}",  # Audio Source
    "{0000110B-0000-1000-8000-00805F9B34FB}",  # Handsfree
    "{0000110C-0000-1000-8000-00805F9B34FB}",  # Handsfree Audio Gateway
    "{0000110E-0000-1000-8000-00805F9B34FB}",  # AV Remote Control Target
    "{0000110F-0000-1000-8000-00805F9B34FB}",  # AV Remote Control Controller
    "{00001124-0000-1000-8000-00805F9B34FB}",  # AV Remote Control
    "{00001801-0000-1000-8000-00805F9B34FB}",  # Generic Attribute Profile
    "{00001812-0000-1000-8000-00805F9B34FB}",  # Human Interface Device
    "{00001800-0000-1000-8000-00805F9B34FB}",  # Generic Access Profile
    "{0000180A-0000-1000-8000-00805F9B34FB}",  # Device Information
    "{00001813-0000-1000-8000-00805F9B34FB}"   # Battery Service
)

# Convert the array to a semicolon-separated string
$TargetServicesAllowedListString = $TargetServicesAllowedList -join ";"

# Get the current ServicesAllowedList
try {
    $CurrentServicesAllowedList = (Get-CimInstance -Namespace 'root\cimv2\mdm\dmmap' -Query 'Select * from MDM_Policy_Result01_Bluetooth02').ServicesAllowedList
}
catch {
    Write-Warning "Unable to retrieve current Bluetooth policy.  Assuming no policy exists."
    $CurrentServicesAllowedList = $null
}

# Determine Compliance
if ($CurrentServicesAllowedList -ne $TargetServicesAllowedListString) {
    $Compliance = "Non-compliant"
}
else {
    $Compliance = "Compliant"
}

Write-Host "Current Bluetooth ServicesAllowedList: $($CurrentServicesAllowedList)"
Write-Host "Target Bluetooth ServicesAllowedList: $($TargetServicesAllowedListString)"
Write-Host "Compliance Status: $($Compliance)"

#Remediation
if ($Compliance -eq "Non-compliant") {
    Write-Host "Applying Bluetooth file transfer restriction..."

    # Get the Bluetooth policy instance
    try {
        $BluetoothPolicy = Get-CimInstance -Namespace 'root\cimv2\mdm\dmmap' -Query 'Select * from MDM_Policy_Config01_Bluetooth02'
    }
    catch {
        Write-Warning "Bluetooth policy does not exist. Creating a new policy."
        $BluetoothPolicy = $null
    }

    # Apply the policy
    try {
        if ($BluetoothPolicy) {
            $Result = Set-CimInstance -InputObject $BluetoothPolicy -Property @{
                ParentID            = "./Vendor/MSFT/Policy/Config"
                InstanceID          = "Bluetooth"
                ServicesAllowedList = $TargetServicesAllowedListString
            }
            Write-Host "Bluetooth policy updated successfully."
        }
        else {
            $Result = New-CimInstance -Namespace 'root\cimv2\mdm\dmmap' -ClassName 'MDM_Policy_Config01_Bluetooth02' -Property @{
                ParentID            = "./Vendor/MSFT/Policy/Config"
                InstanceID          = "Bluetooth"
                ServicesAllowedList = $TargetServicesAllowedListString
            }
            Write-Host "Bluetooth policy created successfully."
        }

        Write-Host "Remediation completed with ReturnValue: $($Result.ReturnValue)"
    }
    catch {
        Write-Error "Failed to apply Bluetooth policy: $($_.Exception.Message)"
        exit 1  # Exit with an error code
    }

    # Verify Compliance Again (Double Check)
    try {
        $CurrentServicesAllowedList = (Get-CimInstance -Namespace 'root\cimv2\mdm\dmmap' -Query 'Select * from MDM_Policy_Result01_Bluetooth02').ServicesAllowedList
    }
    catch {
        Write-Warning "Unable to retrieve current Bluetooth policy for verification."
        $CurrentServicesAllowedList = $null
    }

    if ($CurrentServicesAllowedList -ne $TargetServicesAllowedListString) {
        Write-Warning "Remediation failed.  Bluetooth ServicesAllowedList is not set correctly."
        exit 1
    }
    else {
        Write-Host "Remediation successfully verified."
    }
}
else {
    Write-Host "Bluetooth file transfer is already restricted."
}

exit 0  # Exit with a success code

