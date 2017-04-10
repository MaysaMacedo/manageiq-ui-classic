module ManageIQ::Providers
  class AutomationManager::InventoryRootGroupDecorator < MiqDecorator
    def self.fonticon
      'pficon pficon-folder-close'
    end

    def self.fileicon
      '100/inventory_group.png'
    end
  end
end
