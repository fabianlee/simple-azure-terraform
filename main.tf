# https://github.com/kpatnayakuni/azure-quickstart-terraform-configuration/blob/master/101-vm-with-rdp-port/main.tf
# 

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
# https://github.com/kpatnayakuni/azure-quickstart-terraform-configuration/blob/master/101-vm-with-rdp-port/main.tf
# https://stackoverflow.com/questions/52302520/provisioning-a-windows-vm-in-azure-with-winrm-port-5986-open
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group
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

resource "random_string" "winpassword" {
  length  = 12
  upper   = true
  number  = true
  lower   = true
  special = true
  override_special = "!@#$%&"
}

# for powershell extension, https://gmusumeci.medium.com/how-to-bootstrapping-azure-vms-with-terraform-c8fdaa457836
# basic examples, https://github.com/terraform-providers/terraform-provider-azurerm/blob/master/examples/virtual-machines/windows/vm-joined-to-active-directory/modules/domain-member/main.tf
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
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

