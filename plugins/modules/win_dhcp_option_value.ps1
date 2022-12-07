#!powershell

# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
		computer_name = @{ type = "str" }
        scope_id = @{ type = "str" }
		option_id = @{ type = "int" }
		option_value = @{ type = "list"; elements = 'str' }
        option_type = @{ type = "str"; choices = "Byte", "Word", "DWord", "DWordDword", "IPAddress", "IPv6Address", "String", "BinaryData", "EncapsulatedData"; default = "String" }
        state = @{ type = "str"; choices = "absent", "present"; default = "present" }
    }
    required_if = @(
        @("state", "present", @("scope_id", "option_id", "option_value")),
        @("state", "absent", @("scope_id", "option_id"))
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode

$scope_id = $module.Params.scope_id
$option_id = $module.Params.option_id
$option_value = $module.Params.option_value
$option_type = $module.Params.option_type
$state = $module.Params.state
$dhcp_computer_name = $module.Params.computer_name
$extra_args = @{}
if ($null -ne $dhcp_computer_name) {
    $extra_args.ComputerName = $dhcp_computer_name
}

$desired_option_value = @{
    OptionId = $option_id
    Value = $option_value
}
#
Function need-update {
    Param(
        $Original,
        $Updated
    )
    
    # Did we find difference
    return -not (($original.Value -join "-") -eq ($updated.Value -join "-"))
}

Function convert-object {
    Param(
        $object
    )
  
    $updated = @{ }
 
    $updated.option_id = $object.OptionId
    $updated.option_value = $object.Value
  
    return $updated
}



Try {
    # Import DHCP Server PS Module
    Import-Module DhcpServer
}
Catch {
    # Couldn't load the DhcpServer Module
    $module.FailJson("The DhcpServer module failed to load properly: $($_.Exception.Message)", $_)
}

try {
    # Try to get the scope
    $scope = Get-DhcpServerv4Scope @extra_args | Where-Object ScopeId -eq $scope_id
	#$module.Result.scope = $scope
}
catch {
    $module.FailJson("Error when checking if scope exists.", $_)
}

if (-not $scope) { 
    $module.FailJson("the scope specified does not exists. ", $_)
}

try {
    # Try to get the option value
    $original_option_value = $scope | get-DhcpServerv4OptionValue @extra_args | Where-Object optionid -eq $option_id
}
catch {
    $module.FailJson("Error when checking if option exists.", $_)
}

if ($original_option_value) {          
    $option_value_present = $true
    $module.Diff.before = convert-object -object $original_option_value
}
else {
    $option_value_present = $false
	$module.Diff.before = @{ }
}

# State: Absent
# Ensure scope is not present
if ($state -eq "absent") {
    if ($option_value_present) {
		# Remove the option
		try {
			$scope | Remove-DhcpServerv4OptionValue -OptionID $option_id  @extra_args -WhatIf:$check_mode
			
            $module.Result.option_value = @{ }
            $module.Diff.after = @{ }
            $module.Result.changed = $true			
		}
		catch {
			$module.FailJson("Error when removing the option value.", $_)
		}
	}
	else {
		# Nothing to do already in the desired state
        $module.Result.changed = $false
        $module.ExitJson()		
	}
}
# State: Present
else {
    if ( (-not $option_value_present) -or (need-update -Original $original_option_value -Updated $desired_option_value) ) {			
		try {
            switch -regex ($option_type.ToLower()) {
                "binarydata|EncapsulatedData" {
                    $updated_option_value = $scope | Set-DhcpServerv4OptionValue -OptionID $option_id -Value $option_value @extra_args -WhatIf:$check_mode -PassThru
                }
                default {
                    $updated_option_value = $scope | Set-DhcpServerv4OptionValue -OptionID $option_id -Value "$option_value" @extra_args -WhatIf:$check_mode -PassThru
                }
            }
				
			if ($check_mode) {
				$module.Result.option_value = convert-object -object $desired_option_value
				$module.Diff.after = convert-object -object $desired_option_value
			}
			else {
				$module.Result.option_value = convert-object -object  $updated_option_value
				$module.Diff.after = convert-object -object $updated_option_value
			}
            
            $module.Result.changed = $true
		}
		catch {
			$module.FailJson("Error when setting the option value.", $_)
		}
    }
	else {
		$module.Result.option_value = convert-object -object $original_option_value
		$module.Diff.after = convert-object -object $original_option_value
		$module.Result.changed = $false
    }
}


$module.ExitJson()