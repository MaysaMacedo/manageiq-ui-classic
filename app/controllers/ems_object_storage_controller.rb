class EmsObjectStorageController < ApplicationController
  include Mixins::GenericListMixin
  include Mixins::GenericShowMixin
  include EmsCommon
  include Mixins::EmsCommonAngular
  include Mixins::GenericSessionMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def self.model
    ManageIQ::Providers::StorageManager
  end

  def self.table_name
    @table_name ||= "ems_object_storage"
  end

  def breadcrumb_name(_model)
    ui_lookup(:tables => table_name.pluralize)
  end

  def ems_path(*args)
    path_hash = {:action => 'show', :id => args[0].id.to_s }
    path_hash.merge(args[1])
  end

  def show_list
    opts = {:supported_features_filter => "supports_object_storage?",
            :layout                    => "ems_storage",
            :model                     => model}
    process_show_list(opts)
  end

  def new_ems_path
    {:action => 'new'}
  end

  def ems_storage_form_fields
    ems_form_fields
  end

  menu_section :ost

  has_custom_buttons
end
