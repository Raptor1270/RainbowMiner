﻿using module ..\Include.psm1

class Luk : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest -Server $Server -Port $this.Port -ReadToEnd $Timeout -ErrorAction Stop -Quiet
            if (-not $Response) {throw}
            $Data = $Response -replace 'LOG:' | ConvertFrom-StringData
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return @("", $Response)
        }

        $HashRate_Name  = $this.Algorithm[0]        
        $HashRate_Value = [double]$Data.hash_rate

        $Accepted_Shares = [int64]$Data.num_shares_accepted
        $Rejected_Shares = [int64]$Data.num_shares_rejected

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData([PSCustomObject]@{
            Raw      = $Response
            HashRate = $HashRate
            Device   = @()
        })

        $this.CleanupMinerData()

        return @("", $Data | ConvertTo-Json -Compress)
    }
}