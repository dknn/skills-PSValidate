function Invoke-HeuristicChecks {
    param(
        [System.Collections.Generic.List[object]]$Findings,
        [string]$File,
        [string[]]$Lines
    )

    foreach ($lineNumber in Get-LineNumbers -Lines $Lines -Pattern ([regex]'Rename-Item\b.*-NewName\s+("[A-Za-z]:\\|''[A-Za-z]:\\|\$\w*(Path|Dir|File|FullName|Target))')) {
        Add-Finding -Sink $Findings -File $File -Severity 'Warning' -Rule 'rename-item-newname-path' -Message 'Rename-Item -NewName appears to receive a full path instead of a leaf name.' -Line $lineNumber
    }

    foreach ($countFinding in Get-UnwrappedCommandCountFindings -Lines $Lines) {
        Add-Finding -Sink $Findings -File $File -Severity 'Error' -Rule 'unwrapped-command-count' -Message "Variable '$($countFinding.Variable)' is assigned from unwrapped command output on line $($countFinding.AssignmentLine) and later uses .Count. Wrap the assignment in @(...)." -Line $countFinding.Line
    }
}
