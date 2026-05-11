
<#PSScriptInfo

.VERSION 1.01

.GUID ee32954e-ad9a-40c3-869b-4c7293d5f88d

.AUTHOR David Dean <david@sycho.net>

.DESCRIPTION 
 A handy function for creating a temporary array ($blah) from a list of arbitrary data (i.e. email addresses), useful for running a loop against. After loading the function (or adding to your PowerShell profile), execute the function by typing 'blah' then pasting in a list of data that you want to perform a common command against.  For example, from an Excel spreadsheet, just ensure there are no leading or trailing spaces in the data.  Then run a foreach against $blah:  foreach ($b in $blah) {get-recipient $b} or $blah|%{get-recipient $_}.  Stop creating useless temporary text files!!

#> 

function blah {
	[System.Collections.ArrayList]$global:blah = @(while (Read-Host -OutVariable l){$l})
}
