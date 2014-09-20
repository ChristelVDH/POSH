param(
$username=$env:username
)

process{
$photo = ([ADSISEARCHER]"samaccountname=$($username)").findone().properties.thumbnailphoto
if($photo -eq $null) {exit}
else{
	$AccountPic = "$temp\$domain$username.jpg"
	write-verbose $AccountPic
	$photo | set-content $AccountPic -Encoding byte
	$ADuser = "$domain\$username"
	[AccountPicture.Handle]::SetUserTile($ADuser,0,$AccountPic)
	}
}

begin{
$domain=$env:userdomain
$temp=$env:temp

$TypeDefinition=@"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32;
namespace AccountPicture{
    public class Handle{
        [DllImport("shell32.dll", EntryPoint = "#262", CharSet = CharSet.Unicode, PreserveSig = false)]
        public static extern void SetUserTile(string username, int whatever, string picpath);
		[STAThread]
        static void Main(string[] args){SetUserTile(args[0], 0, args[1]);}
		}
	}
"@
Add-Type -TypeDefinition $TypeDefinition -PassThru | out-null
}

end {}
