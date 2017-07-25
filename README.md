A simple PowerShell script for generating a [Regions of Interest][msdn-regions] file from a collection of event start / stop pairs.
By default the script generates two regsions files, one for Edge and one for Chrome, for use with `performance.mark()`,
though any event provider can be used by setting the `-EventProviders` parameter.
For more information why you'd use this tool, see https://matt.kotsenas.com/posts/using-wpa-to-analyze-performance-marks, and for
more info on _how_ to use it, see https://matt.kotsenas.com/posts/generate-wpa-regions-from-performance-marks. 

## Getting help

Help, including examples, is included in the script, just run

```powershell
Get-Help .\New-RegionsXml.ps1
```

[msdn-regions]: https://msdn.microsoft.com/en-us/library/dn450838.aspx