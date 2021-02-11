net stop wuauserv

$tempfolders = @( "C:\Windows\Temp\*",
                  "C:\Windows\Prefetch\*",
                  "C:\Users\*\Appdata\Local\Temp\*",
                  "C:\Windows\SoftwareDistribution\Downloads\*" )

Remove-Item $tempfolders -force -recurse

Optimize-Volume -DriveLetter C -Defrag
