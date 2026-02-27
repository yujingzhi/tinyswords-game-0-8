$godot = (Get-Command godot -ErrorAction SilentlyContinue)
if ($null -eq $godot) {
	Write-Error "未找到 godot 可执行文件，请先把 Godot 加入 PATH"
	exit 1
}
$projectRoot = Resolve-Path "$PSScriptRoot\.."
& $godot.Source --headless --check-only --path $projectRoot
