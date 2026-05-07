$files = 'lib/l10n/app_en.arb','lib/l10n/app_zh.arb','lib/l10n/app_de.arb'
foreach($f in $files){
  $obj = Get-Content -Raw $f | ConvertFrom-Json
  if(-not ($obj.PSObject.Properties.Name -contains 'recipeDetailAllLabel')){
    $obj | Add-Member -NotePropertyName recipeDetailAllLabel -NotePropertyValue 'All'
  }
  ($obj | ConvertTo-Json -Depth 20) | Set-Content -Path $f -Encoding UTF8
}
