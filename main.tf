
resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "Central US" # East US
}

resource "azurerm_public_ip" "example" {
  name                = "publicip1"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
}

resource "azurerm_virtual_network" "example" {
  name                = "example-network"
  address_space       = ["172.18.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "example" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["172.18.1.0/24"]
}

# Security group for subnet 
resource "azurerm_network_security_group" "secgroup" {
  name                = "example-secgroup"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  security_rule {
    name                       = "default-allow-3389"
    priority                   = 1000
    access                     = "Allow"
    direction                  = "Inbound"
    destination_port_range     = 3389
    protocol                   = "*" # rdp uses both
    source_port_range          = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "wireguard-inbound-51820"
    priority                   = 1100
    access                     = "Allow"
    direction                  = "Inbound"
    destination_port_range     = 51820
    protocol                   = "*" # Tcp|Udp|Icmp|*
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "wireguard-outbound-51820"
    priority                   = 1200
    access                     = "Allow"
    direction                  = "Outbound"
    destination_port_range     = 51820
    protocol                   = "*" # Tcp|Udp|Icmp|*
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

# Associate subnet and network security group 
resource "azurerm_subnet_network_security_group_association" "secgroup-assoc" {
  subnet_id                 = azurerm_subnet.example.id
  network_security_group_id = azurerm_network_security_group.secgroup.id
}

resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  # no longer supported, use 'azurerm_network_interface_security_group_association' instead
  #network_security_group_id = azurerm_network_security_group.secgroup.id

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id  = azurerm_public_ip.example.id
  }
}

resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.example.id
  network_security_group_id = azurerm_network_security_group.secgroup.id
}

# https://stackoverflow.com/questions/52302520/provisioning-a-windows-vm-in-azure-with-winrm-port-5986-open
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.example.name}"
    }
    byte_length = 8
}
# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.example.name
    location                    = azurerm_resource_group.example.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}

resource "random_string" "winpassword" {
  length  = 12
  upper   = true
  number  = true
  lower   = true
  special = true
  override_special = "!@#$%&"
}

resource "azurerm_windows_virtual_machine" "example" {
  name                = "example-machine"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = random_string.winpassword.result
  provision_vm_agent =  true
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter" # 2016 is EOL Jan 2022
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
  }
}

// to list available extensions
// az vm extension image list --location westus -o table
resource "azurerm_virtual_machine_extension" "startup_script" {
  name                 = "startup_script"
  virtual_machine_id   = azurerm_windows_virtual_machine.example.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

 settings = <<SETTINGS
    {
    "commandToExecute": "powershell -encodedCommand ${textencodebase64(file("startup.ps1"), "UTF-16LE")}"
    }
    SETTINGS

  depends_on = [ azurerm_windows_virtual_machine.example ]
}

