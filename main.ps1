Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xml.Linq

# 定义 XML 文件路径
$xmlFilePath = ".\config.xml"

# 加载并解析 XML 文件
[xml]$xmlContent = Get-Content $xmlFilePath
$items = $xmlContent.Items.Item

# 定义 XAML 文件路径
$xamlFilePath = ".\MainWindow.xaml"

# 读取 XAML 内容
$xamlContent = Get-Content $xamlFilePath -Raw

# 加载 XAML 内容
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
$window = [Windows.Markup.XamlReader]::Load($reader)

# 获取 StackPanel 控件
$stackPanel = $window.FindName("StackPanel")

# 获取 OutputTextBox 控件
$outputTextBox = $window.FindName("OutputTextBox")

# 动态生成复选框
foreach ($item in $items) {
    $checkBox = New-Object Windows.Controls.CheckBox
    $checkBox.Content = $item.name
    $checkBox.Tag = @{
        Source = $item.source
        Destination = $item.destination
        Operation = $item.operation
    }
    $stackPanel.Children.Add($checkBox)
}

# 获取按钮控件
$deployButton = $window.FindName("DeployButton")
$cancelButton = $window.FindName("CancelButton")

# 处理部署按钮点击事件
$deployButton.Add_Click({
    # 输出结果到 OutputTextBox
    $currentDateTime = Get-Date
    $outputTextBox.Dispatcher.Invoke([action]{
        $outputTextBox.AppendText("====================================`n")
        $outputTextBox.AppendText("$currentDateTime::QucikDeploy Start.`n")
    })

    $checkedItems = $stackPanel.Children | Where-Object { $_.IsChecked -eq $true }
    if ($checkedItems.Count -gt 0) {
        $details = $checkedItems | ForEach-Object {
            $command=""
            if ($_.Tag.Operation -eq "Expand-Archive") {
                #Expand-Archive -Path $zipPath -DestinationPath $destinationPath -Force
                $command="Expand-Archive -Path "+$_.Tag.Source+" -Destination "+ $_.Tag.Destination
            } elseif ($_.Tag.Operation -eq "Copy-Item") {
                #Copy-Item -Path "C:\oldfile.txt" -Destination "C:\\NewFolder\"
                $command="Copy-Item -Path "+$_.Tag.Source+" -Destination "+ $_.Tag.Destination
            } else {
                $command=""
                [System.Windows.MessageBox]::Show("未知操作！", "警告", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                continue
            }

            # 调试用
            #$outputTextBox.Dispatcher.Invoke([action]{
            #    $outputTextBox.AppendText("command::$command`n")
            #})

            # 启动一个新的 PowerShell 作业来执行命令
            $job = Start-Job -ScriptBlock {
                param($cmd)
                Invoke-Expression $cmd
            } -ArgumentList $command

            # 监控作业的输出并更新文本框
            while (-not $job.State -eq 'Completed' -and -not $job.State -eq 'Failed') {
                $output = Receive-Job -Job $job
                if ($output) {
                    $outputTextBox.Dispatcher.Invoke([action]{
                        $outputTextBox.AppendText("$output`n")
                    })
                }
                Start-Sleep -Milliseconds 100
            }

            # 获取最终的输出
            $finalOutput = Receive-Job -Job $job
            if ($finalOutput) {
                $outputTextBox.Dispatcher.Invoke([action]{
                    $outputTextBox.AppendText("$finalOutput`n")
                })
            }

            # 输出结果到 OutputTextBox
            $currentDateTime = Get-Date
            $outputTextBox.Dispatcher.Invoke([action]{
                $outputTextBox.AppendText("$currentDateTime::Deploy:"+$_.Tag.Content+" finished.`n")
            })

            # 删除作业
            if ($job.State -eq 'Completed' -or $job.State -eq 'Failed') {
                Remove-Job -Job $job
            }
        }
        #[System.Windows.MessageBox]::Show("部署详情:`n$($details -join "`n")", "部署", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } else {
        # 输出结果到 OutputTextBox
        $outputTextBox.Dispatcher.Invoke([action]{
            $outputTextBox.AppendText("未选择任何项!`n")
        })
        #[System.Windows.MessageBox]::Show("未选择任何项", "警告", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }
    # 输出结果到 OutputTextBox
    $currentDateTime = Get-Date
    $outputTextBox.Dispatcher.Invoke([action]{
        $outputTextBox.AppendText("$currentDateTime::QucikDeploy End.`n")
        $outputTextBox.AppendText("====================================`n")
    })
})

# 处理取消按钮点击事件
$cancelButton.Add_Click({
    $window.Close()
})

# 显示窗口
$null = $window.ShowDialog()