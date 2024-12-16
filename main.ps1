Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xml.Linq

# ���� XML �ļ�·��
$xmlFilePath = ".\config.xml"

# ���ز����� XML �ļ�
[xml]$xmlContent = Get-Content $xmlFilePath
$items = $xmlContent.Items.Item

# ���� XAML �ļ�·��
$xamlFilePath = ".\MainWindow.xaml"

# ��ȡ XAML ����
$xamlContent = Get-Content $xamlFilePath -Raw

# ���� XAML ����
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
$window = [Windows.Markup.XamlReader]::Load($reader)

# ��ȡ StackPanel �ؼ�
$stackPanel = $window.FindName("StackPanel")

# ��ȡ OutputTextBox �ؼ�
$outputTextBox = $window.FindName("OutputTextBox")

# ��̬���ɸ�ѡ��
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

# ��ȡ��ť�ؼ�
$deployButton = $window.FindName("DeployButton")
$cancelButton = $window.FindName("CancelButton")

# ������ť����¼�
$deployButton.Add_Click({
    # �������� OutputTextBox
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
                [System.Windows.MessageBox]::Show("δ֪������", "����", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                continue
            }

            # ������
            #$outputTextBox.Dispatcher.Invoke([action]{
            #    $outputTextBox.AppendText("command::$command`n")
            #})

            # ����һ���µ� PowerShell ��ҵ��ִ������
            $job = Start-Job -ScriptBlock {
                param($cmd)
                Invoke-Expression $cmd
            } -ArgumentList $command

            # �����ҵ������������ı���
            while (-not $job.State -eq 'Completed' -and -not $job.State -eq 'Failed') {
                $output = Receive-Job -Job $job
                if ($output) {
                    $outputTextBox.Dispatcher.Invoke([action]{
                        $outputTextBox.AppendText("$output`n")
                    })
                }
                Start-Sleep -Milliseconds 100
            }

            # ��ȡ���յ����
            $finalOutput = Receive-Job -Job $job
            if ($finalOutput) {
                $outputTextBox.Dispatcher.Invoke([action]{
                    $outputTextBox.AppendText("$finalOutput`n")
                })
            }

            # �������� OutputTextBox
            $currentDateTime = Get-Date
            $outputTextBox.Dispatcher.Invoke([action]{
                $outputTextBox.AppendText("$currentDateTime::Deploy:"+$_.Tag.Content+" finished.`n")
            })

            # ɾ����ҵ
            if ($job.State -eq 'Completed' -or $job.State -eq 'Failed') {
                Remove-Job -Job $job
            }
        }
        #[System.Windows.MessageBox]::Show("��������:`n$($details -join "`n")", "����", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } else {
        # �������� OutputTextBox
        $outputTextBox.Dispatcher.Invoke([action]{
            $outputTextBox.AppendText("δѡ���κ���!`n")
        })
        #[System.Windows.MessageBox]::Show("δѡ���κ���", "����", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }
    # �������� OutputTextBox
    $currentDateTime = Get-Date
    $outputTextBox.Dispatcher.Invoke([action]{
        $outputTextBox.AppendText("$currentDateTime::QucikDeploy End.`n")
        $outputTextBox.AppendText("====================================`n")
    })
})

# ����ȡ����ť����¼�
$cancelButton.Add_Click({
    $window.Close()
})

# ��ʾ����
$null = $window.ShowDialog()