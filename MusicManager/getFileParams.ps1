$Dir = $args[0]
$File = $args[1]

$objFolder = (New-Object -ComObject Shell.Application).Namespace("$Dir")
$Length = $objFolder.GetDetailsOf($objFolder.ParseName($File), 27)

echo $Length