# Windows kurulum / açılış / kaldırma duman testi (GitHub Actions windows-latest).
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force logs, out\screens-windows | Out-Null
$R = 'logs\windows-smoke.txt'
Set-Content $R ''
function Log($m) { Write-Host $m; Add-Content $R $m }

function Shot($name) {
  Add-Type -AssemblyName System.Windows.Forms, System.Drawing
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
  $bmp.Save("out\screens-windows\$name.png")
  $g.Dispose(); $bmp.Dispose()
}

$setup = Get-ChildItem out\*-Setup.exe | Select-Object -First 1
Log "== Kurulum dosyası: $($setup.Name) ($([math]::Round($setup.Length/1MB,1)) MB)"

# 1) Sessiz kurulum
$p = Start-Process -FilePath $setup.FullName -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/CURRENTUSER','/DIR=C:\WTInstall' -Wait -PassThru
Log "Kurulum çıkış kodu: $($p.ExitCode)"
if (Test-Path C:\WTInstall\WORLDTRACK.exe) { Log 'KURULUM: BAŞARILI (WORLDTRACK.exe mevcut)' } else { Log 'KURULUM: BAŞARISIZ' }
$lnk = Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs" -Recurse -Filter 'WORLDTRACK*.lnk' -ErrorAction SilentlyContinue
if ($lnk) { Log "Başlat menüsü kısayolu: $($lnk[0].Name)" } else { Log 'Başlat menüsü kısayolu bulunamadı' }

# 2) Açılış
$app = Start-Process -FilePath C:\WTInstall\WORLDTRACK.exe -PassThru
Start-Sleep -Seconds 20
$alive = Get-Process -Id $app.Id -ErrorAction SilentlyContinue
if ($alive -and -not $alive.HasExited) { Log "AÇILIŞ: BAŞARILI (süreç çalışıyor, bellek $([math]::Round($alive.WorkingSet64/1MB)) MB)" } else { Log 'AÇILIŞ: BAŞARISIZ' }
Shot 'w01_kurulu_uygulama'
$db = Join-Path $env:APPDATA 'Furkan Baykal\WORLDTRACK\worldtrack.db'
if (Test-Path $db) { Log "Veritabanı oluşturuldu: $db ($([math]::Round((Get-Item $db).Length/1MB,1)) MB)" } else { Log "Veritabanı bulunamadı: $db" }
Stop-Process -Id $app.Id -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 3) Yeniden açılış (kalıcı veritabanıyla)
$app = Start-Process -FilePath C:\WTInstall\WORLDTRACK.exe -PassThru
Start-Sleep -Seconds 12
if (Get-Process -Id $app.Id -ErrorAction SilentlyContinue) { Log 'YENİDEN AÇILIŞ: BAŞARILI' } else { Log 'YENİDEN AÇILIŞ: BAŞARISIZ' }
Stop-Process -Id $app.Id -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 4) Kaldırma
$un = Start-Process -FilePath C:\WTInstall\unins000.exe -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait -PassThru
Start-Sleep -Seconds 3
if (-not (Test-Path C:\WTInstall\WORLDTRACK.exe)) { Log "KALDIRMA: BAŞARILI (çıkış kodu $($un.ExitCode))" } else { Log 'KALDIRMA: BAŞARISIZ' }
if (Test-Path $db) { Log 'Kişisel veriler kaldırmadan sonra korunuyor (beklenen davranış).' }

# 5) Taşınabilir sürüm
$zip = Get-ChildItem out\*-Portable.zip | Select-Object -First 1
Expand-Archive $zip.FullName -DestinationPath C:\WTPortable -Force
$exe = Get-ChildItem C:\WTPortable -Recurse -Filter WORLDTRACK.exe | Select-Object -First 1
$app = Start-Process -FilePath $exe.FullName -PassThru
Start-Sleep -Seconds 20
if (Get-Process -Id $app.Id -ErrorAction SilentlyContinue) { Log 'TAŞINABİLİR AÇILIŞ: BAŞARILI' } else { Log 'TAŞINABİLİR AÇILIŞ: BAŞARISIZ' }
Shot 'w02_tasinabilir'
$pdb = Join-Path $exe.DirectoryName 'WORLDTRACK-Veri\worldtrack.db'
if (Test-Path $pdb) { Log "Taşınabilir veri klasörü exe yanında: BAŞARILI" } else { Log "Taşınabilir veri klasörü bulunamadı: $pdb" }
Stop-Process -Id $app.Id -Force -ErrorAction SilentlyContinue
exit 0
