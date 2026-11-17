# Compare provided Read codes with legally restricted codes

# Provided codes list
$providedCodes = @(
'133..','1331','1332','1333','1334','1335','1336','1337','1338','1339','133a.','133A.','133A0','133b.','133B.','133c.','133C.','133d.','133D.','133D1','133D2','133D3','133e.','133E.','133f.','133F.','133g.','133G.','133h.','133H.','133i.','133I.','133J.','133K.','133L.','133M.','133N.','133P.','133Q.','133R.','133S.','133T.','133V.','133W.','133X.','133Y.','133Z.','13H9.','13HQ.','13I71','13N5.','1415','14X..','1543','15431','15432','15433','15434','15435','15436','15437','1543Z','1J3..','43C..','43C1.','43C2.','43C3.','43C4.','43CZ.','43d5.','43h2.','43U..','43U0.','43U1.','43U2.','43U3.','43U4.','43U5.','43U6.','43U7.','43U8.','43U9.','43W7.','43W8.','43WK.','4J34.','62b..','65P7.','65P8.','65Q9.','65QA.','65VE.','67I2.','6827','6832','6992','7E06D','7E070','7E071','7E084','7E085','7E086','7E0A.','7E0A0','7E0A1','7E0A2','7E0A3','7E0A4','7E0A5','7E0A6','7E0A7','7E0Ay','7E0Az','7E1F2','8C8..','8C81.','8C82.','8C83.','8C84.','8C85.','8C8Z.','8CAE.','8H7W.','8M6..','956..','9561','9562','9563','956Z.','9Ea..','9Ea0.','9Ea1.','9Ea2.','9Ea3.','9Ea4.','9U...','9U0..','9U1..','9U2..','9U3..','9U4..','9U5..','9U6..','9U7..','9U8..','9U9..','A780.','A7812','A788.','A7880','A7881','A7882','A7883','A7884','A7885','A7886','A788U','A788V','A788W','A788X','A788y','A788z','A789.','A7890','A7891','A7892','A7893','A7894','A7895','A7896','A7897','A7898','A7899','A789A','A789X','A78A.','A78A3','A78AW','A78AX','A9...','A90..','A900.','A901.','A902.','A903.','A904.','A9040','A9041','A9042','A904z','A905.','A9050','A9051','A9052','A9053','A905z','A906.','A907.','A90z.','A91..','A910.','A911.','A912.','A9120','A9121','A9122','A9123','A912z','A913.','A9130','A9131','A9132','A9133','A9134','A9135','A913z','A914.','A915.','A9150','A9151','A9152','A915z','A916.','A9160','A9161','A916z','A917.','A918.','A9180','A9181','A918z','A919.','A91X.','A92..','A920.','A92z.','A93..','A930.','A931.','A932.','A9320','A9321','A9322','A9323','A9324','A932z','A93y.','A93y0','A93y1','A93yz','A93z.','A94..','A940.','A941.','A942.','A943.','A94y.','A94y0','A94y1','A94y2','A94y3','A94y4','A94y5','A94y6','A94yz','A94z.','A95..','A950.','A951.','A952.','A953.','A954.','A955.','A956.','A957.','A9570','A9571','A9572','A957z','A95y.','A95z.','A96..','A97..','A970.','A971.','A97z.','A98..','A980.','A9800','A9801','A9802','A980z','A981.','A9810','A9811','A9812','A9813','A9814','A9815','A9816','A9817','A981z','A982.','A9820','A9821','A9822','A982z','A983.','A9830','A9831','A9832','A9833','A9834','A9835','A9836','A9837','A983z','A984.','A9840','A9841','A9842','A9843','A984z','A985.','A9850','A9851','A9852','A9853','A985z','A986.','A987.','A9870','A9871','A987z','A98y.','A98y0','A98y1','A98y2','A98y3','A98y4','A98y5','A98y6','A98yy','A98yz','A98z.','A99..','A990.','A991.','A9910','A9911','A992.','A993.','A994.','A995.','A99y.','A99z.','A9-KC','A9y..','A9z..','AyuC4','Eu024','L05..','L050.','L0500','L0501','L0502','L0503','L0504','L0505','L0506','L050w','L050x','L050y','L050z','L051.','L0510','L0511','L0512','L0513','L0514','L0515','L0516','L0517','L051w','L051x','L051y','L051z','L052.','L0520','L0521','L0522','L0523','L0524','L0525','L0526','L052w','L052x','L052y','L052z','L05z.','L06..','L060.','L0600','L0601','L0602','L0603','L0604','L0605','L0606','L060w','L060x','L060y','L060z','L061.','L0610','L0611','L0612','L0613','L0614','L0615','L0616','L061w','L061x','L061y','L061z','L062.','L0620','L0621','L0622','L0623','L0624','L0625','L0626','L062w','L062x','L062y','L062z','L06z.','L172.','L1720','L1721','L1722','L1723','L1724','L172z','R109.','SN55.','SN571','T776.','TL7..','TLx4.','ZV016','ZV018','ZV019','ZV01A','ZV028','ZV19B','ZV19C','ZV19D','ZV19E','ZV19F','ZV19G','ZV19H','ZV19J','ZV19K','ZV26.','ZV260','ZV261','ZV262','ZV263','ZV264','ZV265','ZV266','ZV267','ZV268','ZV26y','ZV26z','ZV4F9','ZV4G4','ZV4G5','ZV4J4','ZV4J5','ZV612','ZV625','ZV6D4','ZV737','ZV745'
)

# Extract Read codes from legally restricted files
$legalPath = "O:\GitHub\snomed-database-loader\Legally Restricted Codes"
$legalCodes = @()

Get-ChildItem -Path $legalPath -Filter "*_RCT_*.txt" | ForEach-Object {
    Write-Host "Processing: $($_.Name)"
    $content = Get-Content $_.FullName
    for ($i = 1; $i -lt $content.Length; $i++) {
        $fields = $content[$i] -split "`t"
        if ($fields.Length -ge 4 -and $fields[3] -ne '') {
            $legalCodes += $fields[3]
        }
    }
}

$uniqueLegalCodes = $legalCodes | Sort-Object -Unique

Write-Host "`n=========================================="
Write-Host "PROVIDED LIST: $($providedCodes.Count) codes"
Write-Host "LEGALLY RESTRICTED FILES: $($uniqueLegalCodes.Count) unique codes"
Write-Host "==========================================`n"

# Do comparisons
$inBoth = $providedCodes | Where-Object { $uniqueLegalCodes -contains $_ }
$onlyInProvided = $providedCodes | Where-Object { $uniqueLegalCodes -notcontains $_ }
$onlyInLegal = $uniqueLegalCodes | Where-Object { $providedCodes -notcontains $_ }

Write-Host "CODES IN BOTH LISTS: $($inBoth.Count)" -ForegroundColor Green
Write-Host "CODES ONLY IN PROVIDED LIST: $($onlyInProvided.Count)" -ForegroundColor Magenta
Write-Host "CODES ONLY IN LEGALLY RESTRICTED FILES: $($onlyInLegal.Count)" -ForegroundColor Yellow

Write-Host "`n=== CODES IN BOTH LISTS (first 50): ===" -ForegroundColor Green
$inBoth | Select-Object -First 50

Write-Host "`n=== CODES ONLY IN PROVIDED LIST (all): ===" -ForegroundColor Magenta
$onlyInProvided

Write-Host "`n=== CODES ONLY IN LEGALLY RESTRICTED FILES (first 50): ===" -ForegroundColor Yellow
$onlyInLegal | Select-Object -First 50

# Summary statistics by category
Write-Host "`n=== BREAKDOWN BY CODE PREFIX ===" -ForegroundColor Cyan
Write-Host "`nIn Provided List:"
$providedCodes | Group-Object { $_.Substring(0, [Math]::Min(2, $_.Length)) } | Sort-Object Count -Descending | Select-Object -First 10 | Format-Table Name, Count

Write-Host "`nIn Legally Restricted Files:"
$uniqueLegalCodes | Group-Object { $_.Substring(0, [Math]::Min(2, $_.Length)) } | Sort-Object Count -Descending | Select-Object -First 10 | Format-Table Name, Count
