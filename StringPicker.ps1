param(
    [Parameter(Mandatory)]
    [string]$first_String,
    [Parameter(Mandatory)]
    [string]$second_String,
    [int32]$NumberOfCoinFlips = 10000
)
<# Loop through the strings, iterate the winner #>
for (${i} = 0; ${i} -lt $NumberOfCoinFlips; ${i}++) {
    $answer = ($first_String, $second_String | get-random)
    if($answer -eq $first_String){
        $first_Str_ctr++
    } else {
        $second_Str_ctr++
    }    
}

<# Check which counter is greater #>
if($first_Str_ctr -gt $second_Str_ctr){
    $diff = $first_Str_ctr - $second_Str_ctr
    Write-Host "Winner is - $first_String, by $diff points"
} else {
    $diff = $second_Str_ctr - $first_Str_ctr
    Write-Host "Winner is - $second_String, by $diff points"
}
