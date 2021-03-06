#Install-Module -Name ExchangeOnlineManagement
#Connect-ExchangeOnline

#################################### Configuration Section ###################################################
$logFile = "MAL_All.log"
$outputFile = "MailboxAuditLog_All.csv"
[DateTime]$start = (Get-Date).AddDays(-90)
#[DateTime]$start = '06/30/2020 22:36:13'
[DateTime]$end = Get-Date
$resultSize = 1000
$intervalMinutes = 360
$retryCount = 3
Write-Output "[***] Retrieving Mailbox Audit logs from $($start) till $($end) [***]"
#################################### End Configuration Section ###################################################
[DateTime]$currentStart = $start
[DateTime]$currentEnd = $start
$currentTries = 0

 
Function Write-LogFile ([String]$Message)
{
    $final = [DateTime]::Now.ToString() + ":" + $Message
    $final | Out-File $logFile -Append
}
 
while ($true)
{
    $currentEnd = $currentStart.AddMinutes($intervalMinutes)
    if ($currentEnd -gt $end)
    {
        break
    }
    $currentTries = 0
    $sessionID = [DateTime]::Now.ToString().Replace('/', '_')
    Write-LogFile "INFO: Retrieving mailbox audit logs between $($currentStart) and $($currentEnd)"
    Write-Output "INFO: Retrieving mailbox audit logs between $($currentStart) and $($currentEnd)"
    $currentCount = 0
    while ($true)
    {
        [Array]$results = Search-MailboxAuditLog -StartDate $currentStart -EndDate $currentEnd -ShowDetails -IncludeInactiveMailbox -ResultSize $resultSize
        if ($results -eq $null -or $results.Count -eq 0)
        {
            #Retry if needed. This may be due to a temporary network glitch
            if ($currentTries -lt $retryCount)
            {
                $currentTries = $currentTries + 1
                Start-Sleep -Milliseconds 5
                continue
            }
            else
            {
                Write-LogFile "WARNING: Empty data set returned between $($currentStart) and $($currentEnd). Retry count reached. Moving forward!"
                Write-Output "WARNING: Empty data set returned between $($currentStart) and $($currentEnd). Retry count reached. Moving forward!"
                break
            }
        }
        $currentTotal = $results[0].ResultCount
        if ($currentTotal -gt 5000)
        {
            Write-LogFile "WARNING: $($currentTotal) total records match the search criteria. Some records may get missed. Consider reducing the time interval!"
            Write-Output "WARNING: $($currentTotal) total records match the search criteria. Some records may get missed. Consider reducing the time interval!"
        }
        $currentCount = $currentCount + $results.Count
        Write-LogFile "INFO: Retrieved $($currentCount) records out of the total $($currentTotal)"
        Write-Output "INFO: Retrieved $($currentCount) records out of the total $($currentTotal)"
        $results | epcsv $outputFile -NoTypeInformation -Append
        if ($currentTotal -eq $results[$results.Count - 1].ResultIndex)
        {
            $message = "INFO: Successfully retrieved $($currentTotal) records for the current time range. Moving on!"
            Write-LogFile $message
            Write-Output $message
            break
        }
    }
    $currentStart = $currentEnd
}
Remove-PSSession $Session