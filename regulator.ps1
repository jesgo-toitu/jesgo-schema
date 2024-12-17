<#
    JESGOスキーマの一括修正

    "type": "string"の値を対象として以下のルール
    --  空白文字（削除）
    --  半角カッコ（全角に変換）
    --  半角コロン（全角に変換）

	JESGOプロパティと以下の機能プロパティは対象外
    '$id', '$schema', '$ref', 'type', 'title', 'pattern', 'description', '$comment'
#>
Param (
    [Parameter(ValueFromPipeline = $True)][string]$Path,
    [switch]$CreateBackup
)

function regulate-values {
    Param (
        $data
    )

    # 返値のバッファ
    $outdata = $data
    $modified = $False

    if ($data -is [hashtable]) {
        $outdata = $data.Clone()

        foreach ($item in $data.getEnumerator()) {
            if ($item.key -like 'jesgo:*' -or
                $item.key -in '$id', '$schema', '$ref', 'type', 'title', 'pattern', 'description', '$comment') {
                # 改変処理は行わない対象
            } else {
                $recursive = regulate-values($item.value)
                if ($recursive.modified) {
                    $modified = $True
                    $outdata.($item.key) = $recursive.value
                }
            }
        }
    } elseif ($data -is [array]) {
        $outdata = $data.Clone()

        for($index = 0; $index -lt $data.length; $index++) {
            $recursive = regulate-values($data[$index])
            if ($recursive.modified) {
                $modified = $true
                $outdata[$index] = $recursive.value
            }
        }
    } elseif ($data -is [string]) {
        if ($data -match '[\(\): 　]') {
            $modified = $true
            $outdata = $data -replace ' ', '' -replace '　', '' -replace '\(', '（' -replace '\)', '）' -replace ':', '：'
        }
    }

    return ([PSCustomObject]@{
        modified = $modified
        value = $outdata
    })
}

#
# main
#
if ($Path) {
    $filepath = Get-Item -Path $path
} else {
    if ($_.GetType().Name -ne 'FileInfo') {
        throw 'エラー: パイプで入力された値はファイルではありません.'
    }
    $filepath = $_.FullName
}

if ($filepath.Extension.tolower() -ne '.json') {
    throw 'エラー: ファイルは json ファイルである必要があります.'
}

# JSONの取得
$json = (Get-Content $filepath | ConvertFrom-Json -AsHashtable)

# JSONのパースと書き換えを行う
$result = regulate-values($json)

# 書き換えが行われた場合ファイルを修正して保存する
if ($result.modified) {
    # バックアップ指示に対応
    if ($CreateBackup) {
        # Copy-Item -Path $filepath.fullName -Destination ($filepath.fullName + '~')
        write-host "create backup"
    }
    ConvertTo-Json -Depth 100 $($result.value) | Out-File -Path $($filepath.fullName) -Encoding UTF8
}
