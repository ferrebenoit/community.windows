#!powershell

# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
		computer_name = @{ type = "str" }
        scope_id = @{ type = "str" }
        exclusion_start_range = @{ type = "str" }
        exclusion_end_range = @{ type = "str" }
        state = @{ type = "str"; choices = "absent", "present"; default = "present" }
    }
    required_if = @(
        @("state", "present", @("scope_id", "exclusion_start_range", "exclusion_end_range")),
        @("state", "absent", @("scope_id", "exclusion_start_range", "exclusion_end_range"), $true)
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode

$scope_id = $module.Params.scope_id
$exclusion_start_range = $module.Params.exclusion_start_range
$exclusion_end_range = $module.Params.exclusion_end_range
$state = $module.Params.state
$dhcp_computer_name = $module.Params.computer_name
$extra_args = @{}
if ($null -ne $dhcp_computer_name) {
    $extra_args.ComputerName = $dhcp_computer_name
}

$desired_exclusion_range = @{
    ScopeId = $scope_id
    StartRange = $exclusion_start_range
    EndRange = $exclusion_end_range
}

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
 
    # if we have the exculsion range object
    if ($object.ScopeId.IPAddressToString) {
        $updated.scope_id = $object.ScopeId.IPAddressToString
        $updated.exclusion_start_range = $object.StartRange.IPAddressToString
        $updated.exclusion_end_range = $object.EndRange.IPAddressToString
    }
    else {
        $updated.scope_id = $object.ScopeId
        $updated.exclusion_start_range = $object.StartRange
        $updated.exclusion_end_range = $object.EndRange
    }
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

$both_provided = $false
$start_provided = $false
$end_provided = $false
try {
    #TODO Try to get the exclusion range (With both values or only sartrange or endrange)
    if ($exclusion_start_range -and $exclusion_end_range) {
        $original_exclusion_range = $scope | get-DhcpServerv4ExclusionRange @extra_args | Where-Object StartRange -eq $exclusion_start_range | where-object EndRange -eq $exclusion_end_range
        $both_provided = $true
    }
    elseif ($exclusion_start_range) {
        $original_exclusion_range = $scope | get-DhcpServerv4ExclusionRange @extra_args | Where-Object StartRange -eq $exclusion_start_range
        $start_provided = $true
    }
    else {
        $original_exclusion_range = $scope | get-DhcpServerv4ExclusionRange @extra_args | where-object EndRange -eq $exclusion_end_range
        $end_provided = $true
    }
}
catch {
    $module.FailJson("Error when checking if exclusion Range exists.", $_)
}

if ($original_exclusion_range) {          
    $original_exclusion_range_present = $true
    $module.Diff.before = convert-object -object $original_exclusion_range_present
}
else {
    $original_exclusion_range_present = $false
	$module.Diff.before = @{ }
}

# State: Absent
# Ensure scope is not present
if ($state -eq "absent") {
    if ($original_exclusion_range_present) {
		# Remove the exclusion range
		try {
            if ($both_provided) {
                $updated_exclusion_range = $scope | Add-DhcpServerv4ExclusionRange -StartRange $exclusion_start_range -EndRange $exclusion_end_range @extra_args -WhatIf:$check_mode -PassThru
            }
            elseif ($start_provided) {
                $updated_exclusion_range = $scope | Add-DhcpServerv4ExclusionRange -StartRange $exclusion_start_range @extra_args -WhatIf:$check_mode -PassThru
            }
            else {
                $updated_exclusion_range = $scope | Add-DhcpServerv4ExclusionRange -EndRange $exclusion_end_range @extra_args -WhatIf:$check_mode -PassThru
            }
			
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
    # If an existing exclusion range exists an overlap the new see what to do
    if ( (-not $original_exclusion_range_present) -or (need-update -Original $original_exclusion_range -Updated $desired_exclusion_range) ) {			
		try {
            if ($both_provided) {
                $updated_exclusion_range = $scope | Add-DhcpServerv4ExclusionRange -StartRange $exclusion_start_range -EndRange $exclusion_end_range @extra_args -WhatIf:$check_mode -PassThru
            }
            elseif ($start_provided) {
                $updated_exclusion_range = $scope | Add-DhcpServerv4ExclusionRange -StartRange $exclusion_start_range @extra_args -WhatIf:$check_mode -PassThru
            }
            else {
                $updated_exclusion_range = $scope | Add-DhcpServerv4ExclusionRange -EndRange $exclusion_end_range @extra_args -WhatIf:$check_mode -PassThru
            }

			if ($check_mode) {
				$module.Result.option_value = convert-object -object $desired_exclusion_range
				$module.Diff.after = convert-object -object $desired_exclusion_range
			}
			else {
				$module.Result.option_value = convert-object -object  $updated_exclusion_range
				$module.Diff.after = convert-object -object $updated_exclusion_range
			}
            
            $module.Result.changed = $true
		}
		catch {
			$module.FailJson("Error when adding the exclution range. The exclusion range might overlap with existing one", $_)
		}
    }
	else {
		$module.Result.option_value = convert-object -object $original_exclusion_range
		$module.Diff.after = convert-object -object $original_exclusion_range
		$module.Result.changed = $false
    }
}


$module.ExitJson()