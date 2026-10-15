# =====================================================================
#  Scottimizer 2  -  UI layer  (dark, modern, rounded, gradient accents)
#  The background (colour / gradient / photo) and accent are applied at
#  runtime by Personalize.ps1, so BgHost / ScrimHost and the dynamic
#  Accent resources are the hooks for that.
# =====================================================================

$script:XamlText = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="Scottimizer 2" Width="1250" Height="830" MinWidth="1040" MinHeight="660"
        WindowStartupLocation="CenterScreen" WindowStyle="None"
        AllowsTransparency="True" Background="Transparent"
        ResizeMode="CanResize" FontFamily="Segoe UI" UseLayoutRounding="True"
        SnapsToDevicePixels="True" TextOptions.TextFormattingMode="Display">
  <shell:WindowChrome.WindowChrome>
    <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6" CornerRadius="16"
                        GlassFrameThickness="0" UseAeroCaptionButtons="False"/>
  </shell:WindowChrome.WindowChrome>

  <Window.Resources>

    <!-- ===== accent brushes (replaced at runtime) ===== -->
    <SolidColorBrush x:Key="Accent" Color="#7C5CFF"/>
    <LinearGradientBrush x:Key="AccentGradient" StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#7C5CFF" Offset="0"/>
      <GradientStop Color="#4F8CFF" Offset="1"/>
    </LinearGradientBrush>

    <!-- ===== ScrollBar ===== -->
    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="10"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Grid Background="Transparent">
              <Track x:Name="PART_Track" IsDirectionReversed="True">
                <Track.Thumb>
                  <Thumb>
                    <Thumb.Template>
                      <ControlTemplate TargetType="Thumb">
                        <Border Background="#2B3547" CornerRadius="5" Margin="2,1,2,1"/>
                      </ControlTemplate>
                    </Thumb.Template>
                  </Thumb>
                </Track.Thumb>
                <Track.IncreaseRepeatButton>
                  <RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/>
                </Track.IncreaseRepeatButton>
                <Track.DecreaseRepeatButton>
                  <RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/>
                </Track.DecreaseRepeatButton>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ===== Slider ===== -->
    <Style TargetType="Slider">
      <Setter Property="Height" Value="26"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Slider">
            <Grid VerticalAlignment="Center">
              <Border Height="6" CornerRadius="3" Background="#243044" VerticalAlignment="Center"/>
              <Track x:Name="PART_Track">
                <Track.DecreaseRepeatButton>
                  <RepeatButton Command="Slider.DecreaseLarge" Focusable="False">
                    <RepeatButton.Template>
                      <ControlTemplate TargetType="RepeatButton">
                        <Border Height="6" CornerRadius="3" Background="{DynamicResource Accent}" VerticalAlignment="Center"/>
                      </ControlTemplate>
                    </RepeatButton.Template>
                  </RepeatButton>
                </Track.DecreaseRepeatButton>
                <Track.IncreaseRepeatButton>
                  <RepeatButton Command="Slider.IncreaseLarge" Focusable="False">
                    <RepeatButton.Template>
                      <ControlTemplate TargetType="RepeatButton"><Border Background="Transparent"/></ControlTemplate>
                    </RepeatButton.Template>
                  </RepeatButton>
                </Track.IncreaseRepeatButton>
                <Track.Thumb>
                  <Thumb Width="18" Height="18">
                    <Thumb.Template>
                      <ControlTemplate TargetType="Thumb">
                        <Border Background="White" CornerRadius="9" BorderBrush="#0B0F18" BorderThickness="2"/>
                      </ControlTemplate>
                    </Thumb.Template>
                  </Thumb>
                </Track.Thumb>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ===== Primary button ===== -->
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Padding" Value="22,10"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Background" Value="{DynamicResource AccentGradient}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="10"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.88"/></Trigger>
              <Trigger Property="IsPressed"   Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.78"/></Trigger>
              <Trigger Property="IsEnabled"   Value="False"><Setter TargetName="Bd" Property="Opacity" Value="0.35"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ===== Ghost button ===== -->
    <Style x:Key="Ghost" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#1B2434"/>
      <Setter Property="Foreground" Value="#C9D1E0"/>
    </Style>

    <!-- ===== Danger ghost button ===== -->
    <Style x:Key="Danger" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#3A1E27"/>
      <Setter Property="Foreground" Value="#FDA4AF"/>
    </Style>

    <!-- ===== Small chip (profile selector) ===== -->
    <Style x:Key="Chip" TargetType="ToggleButton">
      <Setter Property="Foreground" Value="#AAB4C6"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ToggleButton">
            <Border x:Name="Chip" Background="#151C29" BorderBrush="#232E40" BorderThickness="1"
                    CornerRadius="14" Padding="13,6">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Chip" Property="BorderBrush" Value="#3A4863"/></Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Chip" Property="Background" Value="#221F33"/>
                <Setter TargetName="Chip" Property="BorderBrush" Value="{DynamicResource Accent}"/>
                <Setter Property="Foreground" Value="#D7CCFF"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ===== Window caption button ===== -->
    <Style x:Key="WinBtn" TargetType="Button">
      <Setter Property="Width" Value="40"/>
      <Setter Property="Height" Value="30"/>
      <Setter Property="Foreground" Value="#8B95A7"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="Transparent" CornerRadius="8">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Background" Value="#1E2735"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="WinBtnClose" TargetType="Button" BasedOn="{StaticResource WinBtn}">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="Transparent" CornerRadius="8">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#C0392B"/>
                <Setter Property="Foreground" Value="White"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ===== Sidebar nav item ===== -->
    <Style x:Key="NavItem" TargetType="RadioButton">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Foreground" Value="#93A0B5"/>
      <Setter Property="Margin" Value="12,2,12,2"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="Pill" Background="Transparent" CornerRadius="10" Padding="12,10">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="Auto"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Border x:Name="Bar" Width="3" Height="18" CornerRadius="2" Background="Transparent"
                        VerticalAlignment="Center" Margin="0,0,11,0"/>
                <ContentPresenter Grid.Column="1" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Pill" Property="Background" Value="#141C29"/>
                <Setter Property="Foreground" Value="#D4DCEA"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Pill" Property="Background" Value="#1A2233"/>
                <Setter TargetName="Bar" Property="Background" Value="{DynamicResource Accent}"/>
                <Setter Property="Foreground" Value="#FFFFFF"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ===== Tweak card (CheckBox) ===== -->
    <Style x:Key="Toggle" TargetType="CheckBox">
      <Setter Property="Foreground" Value="#C9D1E0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,0,10"/>
      <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Border x:Name="Card" Background="#EB111826" CornerRadius="12"
                    BorderBrush="#1E2735" BorderThickness="1" Padding="14,13">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="Auto"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Border x:Name="Track" Width="46" Height="24" CornerRadius="12" Background="#242C3C"
                        VerticalAlignment="Top" Margin="0,2,14,0">
                  <Ellipse x:Name="Knob" Width="18" Height="18" Fill="#7E8AA0"
                           HorizontalAlignment="Left" Margin="3,0,0,0"/>
                </Border>
                <ContentPresenter Grid.Column="1" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Card" Property="Background" Value="#F2141C2C"/>
                <Setter TargetName="Card" Property="BorderBrush" Value="#33405A"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Track" Property="Background" Value="{DynamicResource Accent}"/>
                <Setter TargetName="Knob" Property="HorizontalAlignment" Value="Right"/>
                <Setter TargetName="Knob" Property="Margin" Value="0,0,3,0"/>
                <Setter TargetName="Knob" Property="Fill" Value="White"/>
                <Setter TargetName="Card" Property="BorderBrush" Value="{DynamicResource Accent}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ===== TextBox ===== -->
    <Style x:Key="Field" TargetType="TextBox">
      <Setter Property="Background" Value="#E60C1220"/>
      <Setter Property="Foreground" Value="#E6EAF2"/>
      <Setter Property="CaretBrush" Value="{DynamicResource Accent}"/>
      <Setter Property="BorderBrush" Value="#232E40"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,8"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="9" Padding="{TemplateBinding Padding}">
              <ScrollViewer x:Name="PART_ContentHost"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsKeyboardFocusWithin" Value="True">
                <Setter Property="BorderBrush" Value="{DynamicResource Accent}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Prog" TargetType="ProgressBar">
      <Setter Property="Height" Value="6"/>
      <Setter Property="Background" Value="#1B2431"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Foreground" Value="{DynamicResource AccentGradient}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ProgressBar">
            <Border Background="{TemplateBinding Background}" CornerRadius="3">
              <Grid ClipToBounds="True">
                <Border x:Name="PART_Track"/>
                <Border x:Name="PART_Indicator" Background="{TemplateBinding Foreground}"
                        CornerRadius="3" HorizontalAlignment="Left"/>
              </Grid>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

  </Window.Resources>

  <Border x:Name="RootBorder" CornerRadius="16" BorderBrush="#222C3D" BorderThickness="1"
          Background="#0A0E16">
    <Border.Effect>
      <DropShadowEffect BlurRadius="26" ShadowDepth="0" Opacity="0.55" Color="#000000"/>
    </Border.Effect>

    <Grid>
      <!-- ===== customizable background layers ===== -->
      <Border x:Name="BgHost" CornerRadius="16">
        <Border.Background>
          <LinearGradientBrush StartPoint="0,0" EndPoint="0.6,1">
            <GradientStop Color="#0E1420" Offset="0"/>
            <GradientStop Color="#0A0E16" Offset="1"/>
          </LinearGradientBrush>
        </Border.Background>
      </Border>
      <Border x:Name="ScrimHost" CornerRadius="16" Background="#00000000" IsHitTestVisible="False"/>

      <!-- ===== content ===== -->
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="232"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- SIDEBAR -->
        <Border Grid.Column="0" Background="#CC0B0F18" CornerRadius="16,0,0,16"
                BorderBrush="#1A2230" BorderThickness="0,0,1,0">
          <Grid>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <StackPanel Grid.Row="0" Margin="18,22,18,16">
              <StackPanel Orientation="Horizontal">
                <Border x:Name="LogoBorder" Width="42" Height="42" CornerRadius="12"
                        Background="{DynamicResource AccentGradient}">
                  <TextBlock Text="S" FontSize="22" FontWeight="Bold" Foreground="White"
                             HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <StackPanel Margin="12,0,0,0" VerticalAlignment="Center">
                  <TextBlock FontSize="19" FontWeight="Bold">
                    <Run Text="Scott" Foreground="#EEF1F8"/><Run Text="imizer" Foreground="{DynamicResource Accent}"/>
                  </TextBlock>
                  <TextBlock x:Name="VerText" Text="Advanced 2.1" FontSize="10.5" Foreground="#6B7689"/>
                </StackPanel>
              </StackPanel>
            </StackPanel>

            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,4,0,0">
              <StackPanel x:Name="NavStack"/>
            </ScrollViewer>

            <Border Grid.Row="2" Margin="14,10,14,16" Background="#B3101724" CornerRadius="10" Padding="12,10"
                    BorderBrush="#1C2634" BorderThickness="1">
              <StackPanel>
                <TextBlock x:Name="AdminText" Text="Checking privileges..." FontSize="11"
                           Foreground="#8B95A7" TextWrapping="Wrap"/>
                <TextBlock x:Name="ScoreMini" Text="" FontSize="11" FontWeight="SemiBold"
                           Foreground="#34D399" Margin="0,4,0,0"/>
              </StackPanel>
            </Border>
          </Grid>
        </Border>

        <!-- MAIN -->
        <Grid Grid.Column="1">
          <Grid.RowDefinitions>
            <RowDefinition Height="42"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <!-- caption strip -->
          <Grid x:Name="TitleBar" Grid.Row="0" Background="Transparent">
            <StackPanel x:Name="DragArea" Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Center"
                        Margin="18,0,0,0">
              <TextBlock Text="GAMING PERFORMANCE  |  PRIVACY  |  SECURITY" FontSize="10" FontWeight="SemiBold"
                         Foreground="#485366"/>
            </StackPanel>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,8,0">
              <Button x:Name="MinBtn" Style="{StaticResource WinBtn}" Content="&#x2013;" FontSize="16"/>
              <Button x:Name="CloseBtn" Style="{StaticResource WinBtnClose}" Content="&#x2715;" FontSize="12"/>
            </StackPanel>
          </Grid>

          <!-- page header -->
          <Grid Grid.Row="1" Margin="28,4,28,6">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel VerticalAlignment="Center">
              <TextBlock x:Name="PageTitle" Text="Dashboard" FontSize="26" FontWeight="Bold" Foreground="#EEF1F8"/>
              <TextBlock x:Name="PageSub" Text="System overview and quick tools"
                         FontSize="12.5" Foreground="#8B95A7" Margin="0,3,0,0"/>
            </StackPanel>
            <Grid Grid.Column="1" Width="280" VerticalAlignment="Center">
              <TextBox x:Name="SearchBox" Style="{StaticResource Field}"/>
              <TextBlock x:Name="SearchHint" Text="Search tweaks..." FontSize="13" Foreground="#5A6577"
                         Margin="12,0,0,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
            </Grid>
          </Grid>

          <!-- toolbar -->
          <Grid Grid.Row="2" Margin="28,2,28,12">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel x:Name="ToolbarPanel" Orientation="Horizontal" VerticalAlignment="Center">
              <TextBlock Text="PROFILES" FontSize="10.5" FontWeight="Bold" Foreground="#5E6A7E"
                         VerticalAlignment="Center" Margin="0,0,12,0"/>
              <StackPanel x:Name="ProfileStack" Orientation="Horizontal" VerticalAlignment="Center"/>
            </StackPanel>
            <StackPanel x:Name="ToolbarRight" Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
              <Button x:Name="AllBtn"  Style="{StaticResource Ghost}" Content="Select all" Padding="14,7" FontSize="12" Margin="0,0,8,0"/>
              <Button x:Name="NoneBtn" Style="{StaticResource Ghost}" Content="Clear"      Padding="14,7" FontSize="12"/>
            </StackPanel>
          </Grid>

          <!-- body -->
          <Grid Grid.Row="3" Margin="28,0,24,0">
            <Border x:Name="TweakHost" Background="#E60D131F" CornerRadius="14" BorderBrush="#1B2433" BorderThickness="1"
                    Padding="10,10,4,10">
              <ScrollViewer VerticalScrollBarVisibility="Auto">
                <StackPanel x:Name="TweakStack" Margin="4,4,10,4"/>
              </ScrollViewer>
            </Border>

            <Grid x:Name="SpecialHost" Visibility="Collapsed">
              <ScrollViewer x:Name="DashScroll" VerticalScrollBarVisibility="Auto">
                <StackPanel x:Name="DashStack" Margin="0,0,10,10"/>
              </ScrollViewer>
              <ScrollViewer x:Name="BenchScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
                <StackPanel x:Name="BenchStack" Margin="0,0,10,10"/>
              </ScrollViewer>
              <ScrollViewer x:Name="AppearScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
                <StackPanel x:Name="AppearStack" Margin="0,0,10,10"/>
              </ScrollViewer>
              <ScrollViewer x:Name="AuditScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
                <StackPanel x:Name="AuditStack" Margin="0,0,10,10"/>
              </ScrollViewer>
              <ScrollViewer x:Name="AboutScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
                <StackPanel x:Name="AboutStack" Margin="0,0,10,10"/>
              </ScrollViewer>
            </Grid>
          </Grid>

          <!-- footer -->
          <Grid Grid.Row="4" Margin="28,12,28,18">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <Border Background="#B30A0F19" CornerRadius="12" BorderBrush="#1A2231" BorderThickness="1" Padding="6,4">
              <RichTextBox x:Name="LogBox" Height="104" IsReadOnly="True" Background="Transparent"
                           BorderThickness="0" Foreground="#9AA4B5" FontFamily="Consolas" FontSize="12"
                           Padding="8,4" VerticalScrollBarVisibility="Auto" IsUndoEnabled="False"
                           SelectionBrush="#33405A"/>
            </Border>

            <Grid Grid.Row="1" Margin="0,12,0,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>

              <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                <CheckBox x:Name="RestoreChk" IsChecked="True" Foreground="#C9D1E0" FontSize="12.5"
                          VerticalAlignment="Center" Cursor="Hand"
                          Content="Restore point first"/>
                <CheckBox x:Name="BenchChk" IsChecked="False" Foreground="#C9D1E0" FontSize="12.5"
                          VerticalAlignment="Center" Cursor="Hand" Margin="18,0,0,0"
                          Content="Benchmark latency"
                          ToolTip="Measure ping before/after every tweak you apply (adds time)"/>
                <TextBlock x:Name="StatusText" Text="Ready." FontSize="12" Foreground="#8B95A7"
                           VerticalAlignment="Center" Margin="22,0,0,0"/>
              </StackPanel>

              <ProgressBar x:Name="Prog" Grid.Column="1" Style="{StaticResource Prog}" Margin="24,0"
                           Minimum="0" Maximum="100" Value="0" VerticalAlignment="Center"/>

              <StackPanel Grid.Column="2" Orientation="Horizontal">
                <Button x:Name="UndoBtn"  Style="{StaticResource Danger}" Content="Undo changes" Padding="18,10" Margin="0,0,10,0"/>
                <Button x:Name="ApplyBtn" Style="{StaticResource Btn}"    Content="Apply selected" Padding="24,10"/>
              </StackPanel>
            </Grid>
          </Grid>
        </Grid>
      </Grid>
    </Grid>
  </Border>
</Window>
'@

# ---------------------------------------------------------------------
#  UI builders
# ---------------------------------------------------------------------
function New-Badge {
    param([string]$Text, [string]$Color)
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = New-Object System.Windows.CornerRadius(6)
    $b.Background   = Brush ('#22' + $Color.TrimStart('#'))
    $b.Padding      = New-Object System.Windows.Thickness(7,2,7,2)
    $b.Margin       = New-Object System.Windows.Thickness(8,0,0,0)
    $b.VerticalAlignment = 'Center'
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 10
    $tb.FontWeight = [System.Windows.FontWeights]::Bold
    $tb.Foreground = Brush $Color
    $b.Child = $tb
    return $b
}

function Get-RiskColor([string]$Risk) {
    switch ($Risk) {
        'Safe'     { '#34D399' }
        'Moderate' { '#FBBF24' }
        'Advanced' { '#FB923C' }
        'Risky'    { '#F87171' }
        default    { '#8B95A7' }
    }
}

function New-TweakRow {
    param($Tweak)
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Style = $script:Win.FindResource('Toggle')
    $cb.Tag   = $Tweak
    $cb.IsChecked = [bool]$Tweak.Default
    $cb.ToolTip = $Tweak.Desc

    $outer = New-Object System.Windows.Controls.StackPanel

    $titleRow = New-Object System.Windows.Controls.DockPanel
    $titleRow.LastChildFill = $true

    $badges = New-Object System.Windows.Controls.StackPanel
    $badges.Orientation = 'Horizontal'
    $badges.VerticalAlignment = 'Center'
    [System.Windows.Controls.DockPanel]::SetDock($badges, [System.Windows.Controls.Dock]::Right)

    if ($Tweak.Reboot) { [void]$badges.Children.Add((New-Badge -Text 'REBOOT' -Color '#22D3EE')) }
    [void]$badges.Children.Add((New-Badge -Text $Tweak.Risk.ToUpper() -Color (Get-RiskColor $Tweak.Risk)))
    [void]$titleRow.Children.Add($badges)

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = $Tweak.Name
    $title.FontSize = 13.5
    $title.FontWeight = [System.Windows.FontWeights]::SemiBold
    $title.Foreground = Brush '#E6EAF2'
    $title.TextWrapping = 'Wrap'
    $title.VerticalAlignment = 'Center'
    [void]$titleRow.Children.Add($title)

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = $Tweak.Desc
    $desc.FontSize = 12
    $desc.TextWrapping = 'Wrap'
    $desc.Foreground = Brush '#8B95A7'
    $desc.Margin = New-Object System.Windows.Thickness(0,4,0,0)

    [void]$outer.Children.Add($titleRow)
    [void]$outer.Children.Add($desc)
    $cb.Content = $outer

    Add-Member -InputObject $Tweak -NotePropertyName Check  -NotePropertyValue $cb     -Force
    Add-Member -InputObject $Tweak -NotePropertyName Badges -NotePropertyValue $badges -Force
    [void]$script:TweakStack.Children.Add($cb)
    return $cb
}

function New-ActiveBadge { New-Badge -Text 'ACTIVE' -Color '#7C5CFF' }

function New-Card {
    param([string]$Title = '', [string]$Accent = '#7C5CFF')
    $border = New-Object System.Windows.Controls.Border
    $border.Background = Brush '#E6111826'
    $border.BorderBrush = Brush '#1E2735'
    $border.BorderThickness = New-Object System.Windows.Thickness(1)
    $border.CornerRadius = New-Object System.Windows.CornerRadius(14)
    $border.Padding = New-Object System.Windows.Thickness(18,16,18,16)
    $border.Margin = New-Object System.Windows.Thickness(0,0,0,14)
    $stack = New-Object System.Windows.Controls.StackPanel
    if ($Title) {
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = $Title
        $t.FontSize = 11.5
        $t.FontWeight = [System.Windows.FontWeights]::Bold
        $t.Foreground = Brush $Accent
        $t.Margin = New-Object System.Windows.Thickness(0,0,0,10)
        [void]$stack.Children.Add($t)
    }
    $border.Child = $stack
    return [pscustomobject]@{ Border = $border; Body = $stack }
}

function Add-InfoTile {
    param($Parent, [string]$Label, [string]$Value, [string]$Accent = '#E6EAF2')
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = New-Object System.Windows.Thickness(0,0,26,12)
    $l = New-Object System.Windows.Controls.TextBlock
    $l.Text = $Label.ToUpper(); $l.FontSize = 10; $l.FontWeight = [System.Windows.FontWeights]::Bold
    $l.Foreground = Brush '#5E6A7E'
    $v = New-Object System.Windows.Controls.TextBlock
    $v.Text = $Value; $v.FontSize = 14; $v.Foreground = Brush $Accent; $v.TextWrapping = 'Wrap'
    $v.Margin = New-Object System.Windows.Thickness(0,2,0,0)
    [void]$sp.Children.Add($l); [void]$sp.Children.Add($v)
    [void]$Parent.Children.Add($sp)
}

function New-ToolButton {
    param([string]$Text, [string]$Hint = '')
    $b = New-Object System.Windows.Controls.Button
    $b.Style = $script:Win.FindResource('Ghost')
    $b.Content = $Text
    $b.Padding = New-Object System.Windows.Thickness(16,10,16,10)
    $b.FontSize = 12.5
    $b.Margin = New-Object System.Windows.Thickness(0,0,10,10)
    $b.HorizontalContentAlignment = 'Left'
    if ($Hint) { $b.ToolTip = $Hint }
    return $b
}

function New-AuditRow($item) {
    $color = switch ($item.Status) {
        'pass' { '#34D399' }
        'fail' { '#F87171' }
        'warn' { '#FBBF24' }
        default { '#7C8AA0' }
    }
    $icon = switch ($item.Status) {
        'pass' { [char]0xE73E }
        'fail' { [char]0xEA39 }
        'warn' { [char]0xE7BA }
        default { [char]0xE946 }
    }
    $card = New-Object System.Windows.Controls.Border
    $card.Background = Brush '#E6111826'
    $card.BorderBrush = Brush '#1E2735'
    $card.BorderThickness = New-Object System.Windows.Thickness(1)
    $card.CornerRadius = New-Object System.Windows.CornerRadius(10)
    $card.Padding = New-Object System.Windows.Thickness(14,11,14,11)
    $card.Margin = New-Object System.Windows.Thickness(0,0,0,8)

    $dock = New-Object System.Windows.Controls.DockPanel
    $dock.LastChildFill = $true

    if ($item.FixId) {
        $fix = New-Object System.Windows.Controls.Button
        $fix.Style = $script:Win.FindResource('Ghost')
        $fix.Content = 'Fix'
        $fix.Padding = New-Object System.Windows.Thickness(12,5,12,5)
        $fix.FontSize = 11.5
        $fix.Tag = $item.FixId
        $fix.Margin = New-Object System.Windows.Thickness(10,0,0,0)
        [System.Windows.Controls.DockPanel]::SetDock($fix, [System.Windows.Controls.Dock]::Right)
        $fix.Add_Click({ param($s, $e) Apply-SingleTweak $s.Tag })
        [void]$dock.Children.Add($fix)
    }

    $ico = New-Object System.Windows.Controls.TextBlock
    $ico.Text = [string]$icon
    $ico.FontFamily = New-Object System.Windows.Media.FontFamily('Segoe MDL2 Assets')
    $ico.FontSize = 15
    $ico.Foreground = Brush $color
    $ico.VerticalAlignment = 'Center'
    $ico.Margin = New-Object System.Windows.Thickness(0,0,12,0)
    [System.Windows.Controls.DockPanel]::SetDock($ico, [System.Windows.Controls.Dock]::Left)
    [void]$dock.Children.Add($ico)

    $sp = New-Object System.Windows.Controls.StackPanel
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $item.Check; $t.FontSize = 13; $t.FontWeight = [System.Windows.FontWeights]::SemiBold
    $t.Foreground = Brush '#E6EAF2'
    $d = New-Object System.Windows.Controls.TextBlock
    $d.Text = $item.Detail; $d.FontSize = 11.5; $d.Foreground = Brush '#8B95A7'
    $d.TextWrapping = 'Wrap'; $d.Margin = New-Object System.Windows.Thickness(0,2,0,0)
    [void]$sp.Children.Add($t); [void]$sp.Children.Add($d)
    [void]$dock.Children.Add($sp)

    $card.Child = $dock
    return $card
}

function New-AuditHeader([string]$Area) {
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Area.ToUpper()
    $t.FontSize = 11
    $t.FontWeight = [System.Windows.FontWeights]::Bold
    $t.Foreground = Brush '#5E6A7E'
    $t.Margin = New-Object System.Windows.Thickness(2,14,0,8)
    return $t
}
