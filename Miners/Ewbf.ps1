﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\Equihash-EWBF\miner.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.6-ewbf/EWBF.Equihash.miner.v0.6.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4466962.0"
$Port = "311{0:d2}"
$DevFee = 0.0
$Cuda = "8.0"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Equihash965";  MinMemGB = 2.5; Params = "--algo 96_5"}  #Equihash 96,5
    [PSCustomObject]@{MainAlgorithm = "Equihash1445"; MinMemGB = 2; Params = "--algo 144_5"} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "Equihash1927"; MinMemGB = 2.5; Params = "--algo 192_7"} #Equihash 192,7
    [PSCustomObject]@{MainAlgorithm = "Equihash2109"; MinMemGB = 0.5; Params = "--algo 210_9"} #Equihash 210,9 (beta)
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}

$Session.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        #$MinerCoin_Params = ""
        #if ($Algorithm_Norm -eq "Equihash24x5") {
        #    if ($Pools.$Algorithm_Norm.CoinSymbol) {$MinerCoin_Params = $Coins."$($Pools.$Algorithm_Norm.CoinSymbol)"}
        #    elseif ($Pools.$Algorithm_Norm.CoinName) {$MinerCoin_Params = $Coins."$($Pools.$Algorithm_Norm.CoinName)"}
        #} elseif ($Algorithm_Norm -eq "Equihash24x7") {
        #    $MinerCoin_Params = $Coins.ZER
        #}
        #if ($MinerCoin_Params -eq "") {$MinerCoin_Params = $Coins.default}

        $MinMemGB = $_.MinMemGB        
        $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1gb)}
        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

        $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '
        
        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "--api 127.0.0.1:$($Miner_Port) --cuda_devices $($DeviceIDsAll) --server $($Pools.$Algorithm_Norm.Host) --port $($Pool_Port) --fee 0 --eexit 1 --user $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" --pass $($Pools.$Algorithm_Norm.Pass)"})$(if ($MainAlgorithm_Norm -eq "Equihash24x5") {" --pers $(Get-EquihashCoinPers $Pools.$Algorithm_Norm.CoinSymbol -Default "auto")"}) $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week)}
                API = "DSTM"
                Port = $Miner_Port
                DevFee = $DevFee
                Uri = $Uri
                ExtendInterval = 2
                ManualUri = $ManualUri
            }
        }
    }
}