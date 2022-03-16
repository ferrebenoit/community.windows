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
        lease_duration = @{ type = "int" }
        scope_id = @{ type = "str" }
        state = @{ type = "str"; choices = "absent", "present"; default = "present" }
    }
    required_if = @(
        @("state", "present", @("start_range", "end_range", "subnet_mask", "name"), $true),
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
$extra_args = @{}
if ($null -ne $dhcp_computer_name) {
    $extra_args.ComputerName = $dhcp_computer_name
}
