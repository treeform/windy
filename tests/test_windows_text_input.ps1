# Run from the repository root after:
# nim c -d:useCpu -o:tests/windows_text_fixture.exe tests/windows_text_fixture.nim
# Uses a separate UIA client process so provider calls cross the real COM boundary.
param([string]$Fixture = 'tests\windows_text_fixture.exe')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NativeTextTest {
    [DllImport("user32.dll")] public static extern IntPtr SendMessageW(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
}
'@
function Assert-Equal($Actual, $Expected, $Label) {
    if ($Actual -cne $Expected) { throw "$Label`: expected <$Expected>, got <$Actual>" }
}
function Get-Value {
    # A provider switch invalidates UIA's cached elements. Reacquire with a
    # bounded retry instead of treating a transient stale proxy as a failure.
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        try {
            $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
            $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, 'native fixture')
            $script:element = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
            if (!$script:element) { throw 'No active native editor found.' }
            $script:value = $script:element.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
            return $script:value.Current.Value
        } catch {
            $failure = $_
            Start-Sleep -Milliseconds 20
        }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw $failure
}
function Wait-Value([string]$Expected) {
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 20
        $actual = Get-Value
        # Check the application model too, not only the optimistic UIA mirror.
        try { $rendered = [IO.File]::ReadAllText($script:resultPath) }
        catch [IO.IOException] { continue }
        if ($actual -ceq $Expected -and $rendered -ceq $Expected) { return }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Expected <$Expected>, UIA <$actual>, application <$rendered>"
}
function Message([uint32]$Id, [long]$Wparam = 0, [long]$Lparam = 0) {
    [void][NativeTextTest]::SendMessageW($script:window, $Id, [IntPtr]$Wparam, [IntPtr]$Lparam)
}
function Select-All {
    $pattern = $script:element.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)
    $pattern.DocumentRange.Select()
    Start-Sleep -Milliseconds 50
}

$directory = Join-Path ([IO.Path]::GetTempPath()) ('windy-text-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($directory)
$modePath = Join-Path $directory 'mode.txt'
$resultPath = Join-Path $directory 'result.txt'
[IO.File]::WriteAllText($modePath, 'inactive')
$process = $null
try {
    $process = Start-Process -FilePath (Resolve-Path -LiteralPath $Fixture) -ArgumentList @(('"' + $modePath + '"'), ('"' + $resultPath + '"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $directory 'stdout.txt') -RedirectStandardError (Join-Path $directory 'stderr.txt')
    [void]$process.Handle
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 100
        $process.Refresh()
        $window = $process.MainWindowHandle
    } while ($window -eq [IntPtr]::Zero -and !$process.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if ($window -eq [IntPtr]::Zero) { throw 'Native fixture did not open.' }
    [void][NativeTextTest]::SetForegroundWindow($window)
    # Query before the first field is published to catch cached-host providers.
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($window)
    [void]$root.Current.Name
    [IO.File]::WriteAllText($modePath, 'editable')
    Start-Sleep -Milliseconds 200
    $initial = 'Hello ' + [char]::ConvertFromUtf32(0x1f30d) + ' world'
    Wait-Value $initial
    Assert-Equal $element.Current.ControlType ([System.Windows.Automation.ControlType]::Edit) 'Native edit role'
    Assert-Equal $element.Current.AutomationId 'native fixture' 'Field identity'
    # Background test runners are not always allowed to take foreground focus.
    $foreground = [NativeTextTest]::GetForegroundWindow() -eq $window
    Assert-Equal $element.Current.HasKeyboardFocus $foreground 'Field keyboard focus'
    if ($foreground) {
        Assert-Equal ([System.Windows.Automation.AutomationElement]::FocusedElement.Current.AutomationId) 'native fixture' 'UIA focused element'
    }
    $pattern = $element.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)
    Assert-Equal $pattern.DocumentRange.GetText(-1) $initial 'Document text'
    Assert-Equal $pattern.GetSelection()[0].GetText(-1) ([char]::ConvertFromUtf32(0x1f30d)) 'Surrogate selection'
    $found = $pattern.DocumentRange.FindText('WORLD', $false, $true)
    Assert-Equal $found.GetText(-1) 'world' 'Text search'
    $copy = $found.Clone()
    Assert-Equal $copy.Compare($found) $true 'Range clone'
    $found.Select()
    Message 0x0102 ([int][char]'!')
    Wait-Value ('Hello ' + [char]::ConvertFromUtf32(0x1f30d) + ' !')

    $replacement = 'Dictated ' + [char]::ConvertFromUtf32(0x1f680) + "`nSecond line"
    $value.SetValue($replacement)
    Wait-Value $replacement
    Assert-Equal $element.Current.Name 'Text input' 'Accessible label is not contents'
    Write-Output 'UIA discovery, value replacement, document ranges, selection and Unicode passed.'

    # Simulate a native paste and immediate clipboard restoration.
    Select-All
    # Snapshot all advertised formats before exercising the shared clipboard.
    $saved = New-Object System.Windows.Forms.DataObject
    $clipboard = [System.Windows.Forms.Clipboard]::GetDataObject()
    if ($clipboard) {
        foreach ($format in $clipboard.GetFormats($false)) {
            $data = $clipboard.GetData($format, $false)
            if ($null -ne $data) { $saved.SetData($format, $false, $data) }
        }
    }
    try {
        Set-Clipboard -Value "Native paste`r`nRestored immediately"
        Message 0x0302
        Set-Clipboard -Value 'restored clipboard'
        Wait-Value "Native paste`r`nRestored immediately"
        # Scan-code-less Ctrl+V must capture text synchronously on keydown.
        Select-All
        Set-Clipboard -Value 'Synthetic shortcut'
        Message 0x0100 0x11
        Message 0x0100 0x56
        Message 0x0101 0x56 0xc0000000
        Message 0x0101 0x11 0xc0000000
        Set-Clipboard -Value 'restored again'
        Wait-Value 'Synthetic shortcut'
    } finally { [System.Windows.Forms.Clipboard]::SetDataObject($saved, $true) }
    Write-Output 'Native paste and scan-code-less shortcuts passed.'

    Select-All
    Message 0x0102 0xd83d
    Message 0x0102 0xde80
    Wait-Value ([char]::ConvertFromUtf32(0x1f680))
    # An unpaired surrogate is discarded rather than making invalid UTF-8.
    Message 0x0102 0xd800
    Message 0x0102 ([int][char]'x')
    Wait-Value ([char]::ConvertFromUtf32(0x1f680) + 'x')
    Write-Output 'UTF-16 character injection passed.'

    $retained = $value
    $retainedRange = $element.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern).DocumentRange
    [IO.File]::WriteAllText($modePath, 'password')
    Start-Sleep -Milliseconds 250
    $failed = $false
    try { $retained.SetValue('must not enter password') } catch { $failed = $true }
    Assert-Equal $failed $true 'Stale provider mutation is rejected'
    $failed = $false
    try { [void]$retainedRange.GetText(-1) } catch { $failed = $true }
    Assert-Equal $failed $true 'Stale range cannot read secure contents'
    $element = [System.Windows.Automation.AutomationElement]::FromHandle($window)
    $editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)
    Assert-Equal ($element.FindAll([System.Windows.Automation.TreeScope]::Children, $editCondition).Count) 0 'Password has no exposed edit child'
    $available = $null
    Assert-Equal ($element.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$available)) $false 'Password has no exposed value'
    [IO.File]::WriteAllText($modePath, 'disabled')
    Start-Sleep -Milliseconds 200
    Message 0x0102 ([int][char]'z')
    Assert-Equal ([IO.File]::ReadAllText($resultPath)) ([char]::ConvertFromUtf32(0x1f680) + 'x') 'Disabled field ignores input'
    [IO.File]::WriteAllText($modePath, 'editable')
    Start-Sleep -Milliseconds 200
    [void](Get-Value)
    $value.SetValue('Available again')
    Wait-Value 'Available again'
    $retained = $value
    Message 0x0008
    $failed = $false
    try { $retained.SetValue('must not reach a blurred editor') } catch { $failed = $true }
    Assert-Equal $failed $true 'Focus loss invalidates the editor'
    [IO.File]::WriteAllText($modePath, 'single')
    Start-Sleep -Milliseconds 200
    [void](Get-Value)
    $value.SetValue('Single line')
    Wait-Value 'Single line'
    Message 0x0010
    if (!$process.WaitForExit(5000)) { throw 'Fixture did not close.' }
    Assert-Equal $process.ExitCode 0 'Fixture exit'
    $failed = $false
    try { $value.SetValue('cannot edit a closed window') } catch { $failed = $true }
    Assert-Equal $failed $true 'Destroyed window invalidates provider'
    Write-Output 'Secure fields, disabled fields, focus changes and provider lifetime passed.'
    Write-Output 'All Windows native text input tests passed.'
} catch {
    $stderr = Join-Path $directory 'stderr.txt'
    if (Test-Path -LiteralPath $stderr) {
        Write-Host (Get-Content -LiteralPath $stderr -Raw)
    }
    throw
} finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    # The unique test directory is the only recursive cleanup target.
    $resolved = [IO.Path]::GetFullPath($directory)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolved).StartsWith('windy-text-')) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
