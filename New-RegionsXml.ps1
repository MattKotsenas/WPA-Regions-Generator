<#
.SYNOPSIS
Create a WPA-compatible "Regions of Interest" file given a set of Generic Events and the corresponding event Provider info.

.DESCRIPTION
Create a WPA-compatible "Regions of Interest" file given a set of Generic Events and the corresponding event Provider info.

.PARAMETER RootName
The name of the top-most scenario / region. This should align to the name of your app or your top-level user flow.

.PARAMETER Measures
A collection of one or more objects that represents a measure that should be made a region.
A measure needs a **Name**, a **Start** event, and a **Stop** event.

.PARAMETER Path
The path where the Regions of Interest files should be saved.

Defaults to the current directory.

.PARAMETER EventProviders
A collection of one or more objects that represents an event provider.
A Regsions of Interest file will be created for each event provider.
An event provider needs a **Provider** GUID, an event **ID**, an event **Version**, and a **FieldName**.
These values can all be gathered from inspecting the Generic Events table in WPA.

By default the EventProviders are the performance.mark() providers for Edge and Chrome.
For more information about using performance.mark() and ETW, see https://matt.kotsenas.com/posts/using-wpa-to-analyze-performance-marks

.EXAMPLE
PS> $measures = @(@{Name = "Widget Load"; Start = "WidgetLoad-Start"; Stop = "WidgetLoad-End"}, @{Name = "Flyout Animation"; Start = "animation.flyout.begin"; Stop = "animation.flyout.end"})
PS> $measures | .\New-RegionsXml.ps1 -RootName "My App Scenarios"

.EXAMPLE
PS> $measures = @(@{Name = "Widget Load"; Start = "WidgetLoad-Start"; Stop = "WidgetLoad-End"}, @{Name = "Flyout Animation"; Start = "animation.flyout.begin"; Stop = "animation.flyout.end"})
PS> $providers = @(@{Name = "MyApp"; Provider = [Guid]"488d209a-d0fe-433d-8156-d212766fd68e"; Id = 123; Version = 0; FieldName = "MyEventFieldName"})
PS> .\New-RegionsXml.ps1 -RootName "My App Scenarios" -Measures $measures -Path .\path\to\files
#>
param
(
    [Parameter(Mandatory = $true)]
    [string]
    $RootName,

    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [Hashtable[]]
    $Measures,

    [Parameter(Mandatory = $false)]
    [string]
    $Path = $pwd,

    [Parameter(Mandatory = $false)]
    [Hashtable[]]
    $EventProviders = @(
        @{
            Name = "Edge";
            Provider = [Guid]"9e3b3947-ca5d-4614-91a2-7b624e0e7244";
            Id = 211;
            Version = 0;
            FieldName = "Name"
        },
        @{
            Name = "Chrome";
            Provider = [Guid]"d2d578d9-2936-45b6-a09f-30e32715f42d";
            Id = 1;
            Version = 0;
            FieldName = "Name"
        }
    )
)

Begin
{
    <#
    .SYNOPSIS
    WPA requires all GUIDs to be wrapped in curly-braces, so centralize creating and formatting GUIDs.
    #>
    function Format-Guid
    {
        param
        (
            [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
            [Guid]
            $Guid = [Guid]::NewGuid()
        )
        Set-StrictMode -Version 2
        $ErrorActionPreference = "Stop"

        return "{" + $Guid + "}"
    }

    <#
    .SYNOPSIS
    Pretty-print XML.
    #>
    function Write-Xml
    {
        param
        (
            [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
            [Xml.XmlDocument]
            $Document,

            [Parameter(Mandatory = $true)]
            [string]
            $Path
        )

        Set-StrictMode -Version 2
        $ErrorActionPreference = "Stop"

        $settings = New-Object Xml.XmlWriterSettings
        $settings.OmitXmlDeclaration = $false
        $settings.Indent = $true
        $settings.NewLineOnAttributes = $false

        $writer = $null
        try
        {
            $writer = [Xml.XmlWriter]::Create($Path, $settings)
            $Document.Save($writer)
        }
        finally
        {
            if ($writer -ne $null)
            {
                $writer.Dispose()
            }
        }
    }

    <#
    .SYNOPSIS
    Instead of using the verbose CreateElement() and SetAttribute() APIs, allow creating XML snippets in PowerShell, then importing them into a document.
    #>
    function Append-Element
    {
        param
        (
            [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
            [Xml.XmlDocument]
            $Document,

            [Parameter(Mandatory = $true)]
            [string]
            $XPath,

            [Parameter(Mandatory = $true)]
            [Xml.XmlElement]
            $Child
        )

        Set-StrictMode -Version 2
        $ErrorActionPreference = "Stop"

        $Document.DocumentElement.SelectSingleNode($XPath).AppendChild($Document.ImportNode($Child, $true))
    }

    Set-StrictMode -Version 2
    $ErrorActionPreference = "Stop"

    # Generate a root Regions document
    $template = [xml]@"
<?xml version='1.0' encoding='utf-8' standalone='yes'?>
<InstrumentationManifest>
    <Instrumentation>
        <Regions>
            <RegionRoot Guid=`"$(Format-Guid)`" Name=`"$RootName`" />
        </Regions>
    </Instrumentation>
</InstrumentationManifest>
"@
}

Process
{
    # Generate the "Event" GUID
    foreach ($measure in $Measures)
    {
        $measure.Guid = (Format-Guid)
    }
}

End
{
    foreach ($provider in $EventProviders)
    {
        # Create a Regions file per provider because we want regions with the same name to have the same GUID, but WPA does not
        # allow two regions with the same GUID to be in the same file
        $doc = $template.Clone()

        foreach ($measure in $Measures)
        {
            $region = [xml]@"
<Region Guid=`"$($measure.Guid)`" Name=`"$($measure.Name)`">
    <Match>
        <Event TID=`"true`" PID=`"true`" />
    </Match>
    <Start>
        <Event Provider=`"$(Format-Guid -Guid $provider.Provider)`" Id=`"$($provider.Id)`" Version=`"$($provider.Version)`" />
        <PayloadIdentifier FieldName=`"$($provider.FieldName)`" FieldValue=`"$($measure.Start)`" />
    </Start>
    <Stop>
        <Event Provider=`"$(Format-Guid -Guid $provider.Provider)`" Id=`"$($provider.Id)`" Version=`"$($provider.Version)`" />
        <PayloadIdentifier FieldName=`"$($provider.FieldName)`" FieldValue=`"$($measure.Stop)`" />
    </Stop>
</Region>
"@
            $doc | Append-Element -XPath "//RegionRoot" -Child $region.Region
        }

        $doc | Write-Xml -Path (Join-Path -Path $Path -ChildPath "$RootName.$($provider.Name).xml")
    }
}
