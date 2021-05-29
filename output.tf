output "rdp_connection_string" {
    value = "mstsc.exe /v:${azurerm_public_ip.example.ip_address}:3389"
}

output "local_win_credentials" {
    value = "Windows user/pass = ${azurerm_windows_virtual_machine.example.admin_username}/${random_string.winpassword.result}"
}