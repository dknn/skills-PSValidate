function Invoke-EncodingChecks {
    param(
        [System.Collections.Generic.List[object]]$Findings,
        [string]$File,
        [string[]]$Lines,
        [byte[]]$Bytes,
        [string]$Text,
        [string]$ExpectedBom,
        [bool]$WarnOnDanishLetters
    )

    # ---------- Byte / encoding checks (raw-bytes territory) ----------

    $hasUtf8Bom = $Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF
    if ($hasUtf8Bom) {
        Add-Finding -Sink $Findings -File $File -Severity 'Warning' -Rule 'utf8-bom-present' -Message 'File starts with a UTF-8 BOM.'
    }
    elseif ($ExpectedBom -eq 'Present') {
        Add-Finding -Sink $Findings -File $File -Severity 'Warning' -Rule 'utf8-bom-missing' -Message 'File does not start with a UTF-8 BOM, but one was expected.'
    }

    if ($hasUtf8Bom -and $ExpectedBom -eq 'Absent') {
        Add-Finding -Sink $Findings -File $File -Severity 'Warning' -Rule 'utf8-bom-unexpected' -Message 'File starts with a UTF-8 BOM, but no BOM was expected.'
    }

    if ($Bytes -contains 0) {
        Add-Finding -Sink $Findings -File $File -Severity 'Error' -Rule 'null-byte' -Message 'File contains null bytes and may be UTF-16 or otherwise corrupted.'
    }

    $hasCrLf = $Text.Contains("`r`n")
    $normalized = $Text.Replace("`r`n", '')
    $hasBareLf = $normalized.Contains("`n")
    if ($hasCrLf -and $hasBareLf) {
        Add-Finding -Sink $Findings -File $File -Severity 'Warning' -Rule 'mixed-line-endings' -Message 'File mixes CRLF and LF line endings.'
    }

    # ---------- Character checks (copy-paste corruption) ----------

    $characterRules = @(
        @{ Pattern = $smartQuotePattern; Rule = 'smart-quotes'; Severity = 'Error'; Message = 'Smart quotes or guillemets found.' },
        @{ Pattern = $nbspPattern; Rule = 'nbsp'; Severity = 'Error'; Message = 'Non-breaking space found.' },
        @{ Pattern = $unicodePunctuationPattern; Rule = 'unicode-punctuation'; Severity = 'Warning'; Message = 'Non-ASCII punctuation found.' }
    )

    foreach ($rule in $characterRules) {
        foreach ($lineNumber in Get-LineNumbers -Lines $Lines -Pattern $rule.Pattern) {
            Add-Finding -Sink $Findings -File $File -Severity $rule.Severity -Rule $rule.Rule -Message $rule.Message -Line $lineNumber
        }
    }

    foreach ($lineNumber in Get-LineNumbers -Lines $Lines -Pattern $danishMojibakePattern) {
        Add-Finding -Sink $Findings -File $File -Severity 'Error' -Rule 'danish-mojibake' -Message 'Text looks like mojibake for Danish letters, such as mojibake ae/oe/aa sequences.' -Line $lineNumber
    }

    if ($WarnOnDanishLetters) {
        foreach ($lineNumber in Get-LineNumbers -Lines $Lines -Pattern $danishPattern) {
            Add-Finding -Sink $Findings -File $File -Severity 'Warning' -Rule 'danish-letters' -Message 'Raw Danish letters found. Verify that the file is intentionally non-ASCII and encoded correctly.' -Line $lineNumber
        }
    }
}
