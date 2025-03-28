﻿function Invoke-TcpRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost",
        [Parameter(Mandatory = $true)]
        [String]$Port,
        [Parameter(Mandatory = $false)]
        [String]$Request = "",
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 10, #seconds,
        [Parameter(Mandatory = $false)]
        [Switch]$UseSSL,
        [Parameter(Mandatory = $false)]
        [Switch]$WriteOnly
    )
    $Response = $null
    try {
        $Client = [System.Net.Sockets.TcpClient]::new($Server, $Port)
        #$Client.LingerState = [System.Net.Sockets.LingerOption]::new($true, 0)

        if ($UseSSL) {
            $tcpStream = $Client.GetStream()
            $Stream = [System.Net.Security.SslStream]::new($tcpStream,$false,({$True} -as [Net.Security.RemoteCertificateValidationCallback]))
            $Stream.AuthenticateAsClient($Server)
        } else {
            $Stream = $Client.GetStream()
        }

        $Writer = [System.IO.StreamWriter]::new($Stream)
        if (-not $WriteOnly) {$Reader = [System.IO.StreamReader]::new($Stream)}
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000
        $Writer.AutoFlush = $true
        if ($Request) {$Writer.WriteLine($Request)}
        if (-not $WriteOnly -and $Reader.EndOfStream -eq $False) {$Response = $Reader.ReadLine()}
    }
    catch {
    }
    finally {
        if ($Client) {$Client.Close();$Client.Dispose()}
        if ($Reader) {$Reader.Dispose()}
        if ($Writer) {$Writer.Dispose()}
        if ($Stream) {$Stream.Dispose()}
        if ($tcpStream) {$tcpStream.Dispose()}
    }

    $Response
}

function Invoke-PingStratum {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $True)]
    [String]$Server,
    [Parameter(Mandatory = $True)]
    [Int]$Port,
    [Parameter(Mandatory = $False)]
    [String]$User="",
    [Parameter(Mandatory = $False)]
    [String]$Pass="x",
    [Parameter(Mandatory = $False)]
    [String]$Worker=$Session.Config.WorkerName,
    [Parameter(Mandatory = $False)]
    [int]$Timeout = 3,
    [Parameter(Mandatory = $False)]
    [bool]$WaitForResponse = $False,
    [Parameter(Mandatory = $False)]
    [ValidateSet("Stratum","EthProxy","Qtminer")]
    [string]$Method = "Stratum",
    [Parameter(Mandatory = $false)]
    [Switch]$UseSSL
)    
    $Request = if ($Method -eq "EthProxy") {"{`"id`": 1, `"method`": `"login`", `"params`": {`"login`": `"$($User)`", `"pass`": `"$($Pass)`", `"rigid`": `"$($Worker)`", `"agent`": `"RainbowMiner/$($Session.Version)`"}}"} elseif ($Method -eq "Qtminer") {"{`"id`":1, `"jsonrpc`":`"2.0`", `"method`":`"eth_login`", `"params`":[`"$($User)`",`"$($Pass)`"]}"} else {"{`"id`": 1, `"method`": `"mining.subscribe`", `"params`": [`"$($User)`"]}"}
    #"{`"id`":1, `"jsonrpc`":`"2.0`", `"method`":`"eth_submitLogin`", `"params`":[`"$($User)`"]}"
    
    try {
        if ($WaitForResponse) {
            $Result = Invoke-TcpRequest -Server $Server -Port $Port -Request $Request -Timeout $Timeout -UseSSL:$UseSSL
            if ($Result) {
                $Result = ConvertFrom-Json $Result -ErrorAction Stop
                if ($Result.id -eq 1 -and -not $Result.error) {$true}
            }
        } else {
            Invoke-TcpRequest -Server $Server -Port $Port -Request $Request -Timeout $Timeout -WriteOnly -UseSSL:$UseSSL > $null
            $true
        }
    } catch {}
}