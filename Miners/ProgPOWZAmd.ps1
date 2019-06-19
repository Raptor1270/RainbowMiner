﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$Path = ".\Bin\AMD-ProgPOWZ\progminer-zano-opencl.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.1.2-progminerzano/progminer-zano-win-1.1.2.7z"
$Port = "413{0:d2}"
$ManualURI = "https://github.com/hyle-team/zano/releases"
$DevFee = 0.0

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "progpowz"; Params = ""; ExtendInterval = 2} #ProgPOWZ
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD")
        Name      = $Name
        Path      = $UriCuda.Path | Select-Object -First 1
        Port      = $Miner_Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Session.DevicesByTypes.AMD | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name        = $Miner_Name
					DeviceName  = $Miner_Device.Name
					DeviceModel = $Miner_Model
					Path        = $Path
					Arguments   = "--api-port -$($Miner_Port) -P stratum$(if ($Pools.$Algorithm_Norm.SSL) {"s"})://$(Get-UrlEncode $Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {":$(Get-UrlEncode $Pools.$Algorithm_Norm.Pass)"})@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --opencl --cl-devices $($DeviceIDsAll) --exit $($_.Params)"
					HashRates   = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week }
					API         = "EthminerWrapper"
					Port        = $Miner_Port
					Uri         = $Uri
					DevFee      = $DevFee
					ManualUri   = $ManualUri
					ExtendInterval = $_.ExtendInterval
				}
			}
		}
    }
}