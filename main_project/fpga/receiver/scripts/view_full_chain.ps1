# 默认显示可复制执行的 ModelSim GUI 查看命令；-Launch 可以启动查看器。
# 该脚本只读取仿真结果，不重新仿真、不访问 FPGA 硬件。
[CmdletBinding()]
param(
    [ValidateSet(56000000)]
    [int]$Rate = 56000000,
    [ValidateSet('Full', 'Startup', 'Mixer', 'Baseband', 'FirstAM', 'FM88', 'FM108')]
    [string]$View = 'Full',
    [string]$Modelsim = 'D:\modeltech64_2020.4\win64',
    [switch]$Launch
)

$ErrorActionPreference = 'Stop'
$Workspace = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$Vsim = Join-Path $Modelsim 'vsim.exe'
$Wlf = Join-Path $Workspace ".harness\receiver\full_chain56\full_chain$Rate.wlf"
$DoFile = Join-Path $PSScriptRoot 'view_full_chain.do'
if ($View -in @('FM88', 'FM108')) {
    $DoFile = Join-Path $PSScriptRoot 'view_fm.do'
} elseif ($View -eq 'FirstAM') {
    $DoFile = Join-Path $PSScriptRoot 'view_first_am.do'
}
foreach ($InputPath in @($Vsim, $Wlf, $DoFile)) {
    if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
        throw "文件不存在：$InputPath。请先运行全链路仿真。"
    }
}

# Tcl 路径使用正斜杠，避免 Windows 反斜杠被 Tcl 当成转义字符。
$DoTclPath = $DoFile.Replace('\', '/')
$DoCommand = "do {$DoTclPath}"
switch ($View) {
    'Startup' { $DoCommand += '; wave zoom range 2229us 2350us' }
    'Mixer' { $DoCommand += '; wave zoom range 2600us 2602us' }
    'Baseband' { $DoCommand += '; wave zoom range 2600us 3500us' }
    'FirstAM' { $DoCommand += '; wave zoom range 2600us 2800us; WaveRestoreCursors {{Cursor 1} {2700 us} 0}; update' }
    'FM108' { $DoCommand += '; wave zoom range 11900us 12700us; WaveRestoreCursors {{Cursor 1} {12000 us} 0}; update' }
}
Write-Host "采样率 $Rate Hz 的已完成全链路波形："
Write-Host ('& "{0}" -view "{1}" -do "{2}"' -f $Vsim, $Wlf, $DoCommand)
if ($Launch) {
    # -Launch 是用户主动打开交互波形查看器，显示窗口供用户操作。
    $Arguments = '-view "{0}" -do "{1}"' -f $Wlf, $DoCommand
    Start-Process -FilePath $Vsim -ArgumentList $Arguments -WorkingDirectory $Workspace -WindowStyle Normal
}
