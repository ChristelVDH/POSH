[CmdletBinding(DefaultParameterSetName='Group',SupportsShouldProcess=$true)]
param(
[Parameter(Position=0,ParameterSetName='Group')]
$DestinationGroup = "Technicians",
[Parameter(Position=0,ParameterSetName='Group')]
$PermissionGroup = "TechManagers",
[Parameter(Position=0,ParameterSetName='User')]
$DestinationUser = "",
[Parameter(Position=0,ParameterSetName='User')]
$PermissionUser = "",
[Parameter(Position=0,ParameterSetName='Group')]
[Parameter(Position=0,ParameterSetName='User')]
[ValidateSet("Calendar", "Inbox", "RecoverableItems")]
$MailFolder = "Calendar",
[Parameter(Position=0,ParameterSetName='Group')]
[switch]$remove
)

process{
switch ($PSCmdlet.ParameterSetName){
	"Group"{
		#if error setting permission then try next cmdlet in case of a new DG
		#Set-DistributionGroup -Identity $PermissionGroup -MemberDepartRestriction Closed
		(Get-Group $DestinationGroup).members | Get-Mailbox | %{
			$mbFolder = (($_.SamAccountName)+ ":\" + (Get-MailboxFolderStatistics -Identity $_.SamAccountName -FolderScope $MailFolder | Select-Object -First 1).Name)
			Get-MailboxFolderPermission $mbFolder | select Foldername, User, AccessRights, IsValid | Sort AccessRights | ft
			if ($remove){
				foreach ($user in (Get-DistributionGroupMember $PermissionGroup)){
					Remove-MailboxFolderPermission -User $user -Identity $mbFolder -Confirm:$False
					}
				}
			Add-MailboxFolderPermission -User $(Get-DistributionGroup $PermissionGroup) -AccessRights "PublishingEditor" -Identity $mbFolder
			}
		}
	"User"{
		Get-Mailbox $DestinationUser | %{
			$mbFolder = (($_.SamAccountName)+ ":\" + (Get-MailboxFolderStatistics -Identity $_.SamAccountName -FolderScope $MailFolder | Select-Object -First 1).Name)
			Get-MailboxFolderPermission $mbFolder | select Foldername, User, AccessRights, IsValid | Sort AccessRights | ft
			Add-MailboxFolderPermission -User $PermissionUser -AccessRights "PublishingEditor" -Identity $mbFolder
			}
		}
	}
}

begin{}
end{}