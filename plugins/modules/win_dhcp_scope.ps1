#!powershell

# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
		computer_name = @{ type = "str" }
        type = @{ type = "str"; choices = "Dhcp", "Bootp", "Both"; default = "Dhcp" }
        start_range = @{ type = "str" }
        end_range = @{ type = "str" }
        subnet_mask = @{ type = "str" }
        name = @{ type = "str"; }
        description = @{ type = "str"; }
        scope_state = @{ type = "str"; choices = "Active", "InActive"; default = "Active" }
        lease_duration = @{ type = "str"; default = "08.00:00:00" }
        scope_id = @{ type = "str" }
        state = @{ type = "str"; choices = "absent", "present"; default = "present" }
    }
    required_if = @(
        @("state", "present", @("start_range", "end_range", "subnet_mask", "name","scope_id"), $true),
        @("state", "absent", @("scope_id"), $true)
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode


$type = $module.Params.type
$start_range = $module.Params.start_range
$end_range = $module.Params.end_range
$subnet_mask = $module.Params.subnet_mask
$name = $module.Params.name
$description = $module.Params.description
$scope_state = $module.Params.scope_state
$lease_duration = $module.Params.lease_duration
$scope_id = $module.Params.scope_id
$state = $module.Params.state
$dhcp_computer_name = $module.Params.computer_name
$extra_args = @{}
if ($null -ne $dhcp_computer_name) {
    $extra_args.ComputerName = $dhcp_computer_name
}

$desired_scope = @{
    Type = $type
    StartRange = $start_range
    EndRange = $end_range
    Name = $name
    Description = $description
    State = $scope_state
    LeaseDuration = $lease_duration
}

Function Need-scope-update {
    Param(
        $Original,
        $Updated
    )
    
    return -not (
        ($original.Type -eq $updated.Type) -and
        ($original.StartRange -eq $updated.StartRange) -and
        ($original.EndRange -eq $updated.EndRange) -and
        ($original.ScopeState -eq $updated.ScopeState) -and
        ($original.LeaseDuration -eq $updated.LeaseDuration) -and
        ($original.Name -eq $updated.Name) -and
        ($original.Description -eq $updated.Description)
    )
}

Function Convert-Scope {
    Param(
        $Scope
    )
    
    $updated = @{ }

    # If we have the scope object
    if ($Scope.StartRange.IPAddressToString) {
        $updated.start_range = $Scope.StartRange.IPAddressToString
        $updated.end_range = $Scope.EndRange.IPAddressToString
        $updated.subnet_mask = $Scope.SubnetMask.IPAddressToString
        $updated.lease_duration = $Scope.LeaseDuration.ToString("dd\.hh\:mm\:ss")
        $updated.scope_id = $Scope.ScopeId.IPAddressToString
    }
    else {
        $updated.start_range = $Scope.StartRange
        $updated.end_range = $Scope.EndRange
        $updated.subnet_mask = $Scope.SubnetMask
        $updated.lease_duration = $Scope.LeaseDuration
        $updated.scope_id = $Scope.ScopeId
    }
    

    if ($Scope.Description) {
        $updated.description = $Scope.Description
    }
    else {
        $updated.description = ""
    }
    
    $updated.type = $Scope.Type
    $updated.name = $Scope.Name
    $updated.scope_state = $Scope.State
    
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
    # Try to get the existing scope
    $original_scope = Get-DhcpServerv4Scope @extra_args | Where-Object ScopeId -eq $scope_id
}
catch {
    $module.FailJson("Error when checking if scope exists.", $_)
}

if ($original_scope) {
    $scope_present = $true 
    $module.Diff.before = Convert-scope -scope $original_scope
}
else {
    $scope_present = $false 
    $module.Diff.before = @{ }
}

# State: Absent
# Ensure scope is not present
if ($state -eq "absent") {
    if ($scope_present) {
        # Remove the scope
        try {
            $original_scope | Remove-DhcpServerv4Scope @extra_args -WhatIf:$check_mode
            
            $module.Result.scope = @{ }
            $module.Diff.after = @{ }
            $module.Result.changed = $true
        }
        catch {
            $module.FailJson("Error when removing the scope.", $_)
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
    
    if ($scope_present) {
        # Scope Present Update the scope if needed
        if (Need-scope-update -Original $original_scope -Updated $desired_scope) {
            try {
                $original_scope | Set-DhcpServerv4Scope @desired_scope @extra_args -WhatIf:$check_mode
                
                # update desired state if in check mode
                if ($check_mode) {
                    $desired_scope.ScopeId = $scope_id
                    $desired_scope.SubnetMask = $subnet_mask
                    
                    $module.Result.scope = $desired_scope
                    $module.Diff.after = Convert-scope -scope $desired_scope
                }
                else {
                    # Get modified scope for diff
                    $updated_scope = Get-DhcpServerv4Scope @extra_args -ScopeId $scope_id
                    $module.Result.scope = Convert-scope -scope $updated_scope
                    $module.Diff.after = Convert-scope -scope $updated_scope
                }
                
                $module.Result.changed = $true
            }
            catch {
                $module.FailJson("Error when updating the scope.", $_)
            }
        }
        else {
            $module.Result.scope = Convert-scope -scope $original_scope
            $module.Diff.after = Convert-scope -scope $original_scope
            $module.Result.changed = $false
        }
    }
    else {
        # Scope absent Create the scope
        try {
            # add the SubnetMask when creating the scope
            $desired_scope.SubnetMask = $subnet_mask
            Add-DhcpServerv4Scope @desired_scope @extra_args -WhatIf:$check_mode
            
            # Populate the missing params for diff
            $desired_scope.ScopeId = $Scope_id
            
            $module.Result.scope = $desired_scope
            $module.Diff.after = Convert-scope -scope $desired_scope
            $module.Result.changed = $true
        }
        catch {
            $module.FailJson("Error when creating the scope.", $_)
        }
    }
    
}

$module.ExitJson()