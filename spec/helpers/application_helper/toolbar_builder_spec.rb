describe ApplicationHelper, "::ToolbarBuilder" do
  let(:toolbar_builder) do
    helper._toolbar_builder.tap do |h|
      # Publicize ToolbarBuilder's private interface for easier testing (Legacy reasons)
      h.class.send(:public, *h.private_methods)
    end
  end

  before do
    controller.extend(ApplicationController::CurrentUser)
    controller.class.include(ApplicationController::CurrentUser)
  end

  describe "custom_buttons" do
    let(:user) { FactoryGirl.create(:user, :role => "super_administrator") }

    shared_examples "no custom buttons" do
      it("#get_custom_buttons")        { expect(toolbar_builder.get_custom_buttons(subject)).to be_blank }
      it("#custom_buttons_hash")       { expect(toolbar_builder.custom_buttons_hash(subject)).to be_blank }
      it("#custom_toolbar_class")      { expect(toolbar_builder.custom_toolbar_class(subject).definition).to be_blank }
      it("#record_to_service_buttons") { expect(toolbar_builder.record_to_service_buttons(subject)).to be_blank }
    end

    shared_examples "with custom buttons" do
      before do
        @button_set = FactoryGirl.create(:custom_button_set, :set_data => {:applies_to_class => applies_to_class})
        login_as user
        @button1 = FactoryGirl.create(:custom_button, :applies_to_class => applies_to_class, :visibility => {:roles => ["_ALL_"]}, :options => {})
        @button_set.add_member @button1
      end

      it "#get_custom_buttons" do
        expected_button1 = {
          :id            => @button1.id,
          :class         => @button1.applies_to_class,
          :name          => @button1.name,
          :description   => @button1.description,
          :image         => @button1.options[:button_image],
          :text_display  => @button1.options.key?(:display) ? @button1.options[:display] : true,
          :target_object => subject.id
        }
        expected_button_set = {
          :id           => @button_set.id,
          :text         => @button_set.name,
          :description  => @button_set.description,
          :image        => @button_set.set_data[:button_image],
          :text_display => @button_set.set_data.key?(:display) ? @button_set.set_data[:display] : true,
          :buttons      => [expected_button1]
        }

        expect(toolbar_builder.get_custom_buttons(subject)).to eq([expected_button_set])
      end

      it "#record_to_service_buttons" do
        expect(toolbar_builder.record_to_service_buttons(subject)).to be_blank
      end

      it "#custom_buttons_hash" do
        escaped_button1_text = CGI.escapeHTML(@button1.name.to_s)
        button1 = {
          :id        => "custom__custom_#{@button1.id}",
          :type      => :button,
          :icon      => "product product-custom-#{@button1.options[:button_image]} fa-lg",
          :title     => CGI.escapeHTML(@button1.description.to_s),
          :text      => escaped_button1_text,
          :enabled   => true,
          :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck,
          :url       => "button",
          :url_parms => "?id=#{subject.id}&button_id=#{@button1.id}&cls=#{subject.class.name}&pressed=custom_button&desc=#{escaped_button1_text}"
        }
        button_set_item1_items = [button1]
        button_set_item1 = {
          :id      => "custom_#{@button_set.id}",
          :type    => :buttonSelect,
          :icon    => "product product-custom-#{@button_set.set_data[:button_image]} fa-lg",
          :title   => @button_set.description,
          :text    => @button_set.name,
          :enabled => true,
          :items   => button_set_item1_items
        }
        items = [button_set_item1]
        name = "custom_buttons_#{@button_set.name}"
        expect(toolbar_builder.custom_buttons_hash(subject)).to eq([:name => name, :items => items])
      end

      it "#custom_toolbar_class" do
        escaped_button1_text = CGI.escapeHTML(@button1.name.to_s)
        button1 = {
          :id        => "custom__custom_#{@button1.id}",
          :type      => :button,
          :icon      => "product product-custom-#{@button1.options[:button_image]} fa-lg",
          :title     => CGI.escapeHTML(@button1.description.to_s),
          :text      => escaped_button1_text,
          :enabled   => true,
          :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck,
          :url       => "button",
          :url_parms => "?id=#{subject.id}&button_id=#{@button1.id}&cls=#{subject.class.name}&pressed=custom_button&desc=#{escaped_button1_text}"
        }
        button_set_item1_items = [button1]
        button_set_item1 = {
          :id      => "custom_#{@button_set.id}",
          :type    => :buttonSelect,
          :icon    => "product product-custom-#{@button_set.set_data[:button_image]} fa-lg",
          :title   => @button_set.description,
          :text    => @button_set.name,
          :enabled => true,
          :items   => button_set_item1_items
        }
        group_name = "custom_buttons_#{@button_set.name}"
        expect(toolbar_builder.custom_toolbar_class(subject).definition[group_name].buttons).to eq([button_set_item1])
      end
    end

    context "for VM" do
      let(:applies_to_class) { 'Vm' }
      subject { FactoryGirl.create(:vm_vmware) }

      it_behaves_like "no custom buttons"
      it_behaves_like "with custom buttons"
    end

    context "for Service" do
      let(:applies_to_class) { 'ServiceTemplate' }
      let(:service_template) { FactoryGirl.create(:service_template) }
      subject                { FactoryGirl.create(:service, :service_template => service_template) }

      it_behaves_like "no custom buttons"
      it_behaves_like "with custom buttons"
    end
  end

  describe "#get_image" do
    subject { toolbar_builder.get_image(@img, @button_name) }

    context "when with show_summary" do
      before do
        @button_name = "show_summary"
        @img = "reload"
      end

      it "and layout is scan_profile" do
        @layout = "scan_profile"
        expect(subject).to eq("summary-green")
      end

      it "and layout is miq_schedule" do
        @layout = "miq_schedule"
        expect(subject).to eq("summary-green")
      end

      it "and layout is miq_proxy" do
        @layout = "miq_schedule"
        expect(subject).to eq("summary-green")
      end

      it "otherwise" do
        @layout = "some_thing"
        expect(subject).to eq(@img)
      end
    end

    it "when not with show_summary" do
      @button_name = "summary_reload"
      @img = "reload"
      expect(subject).to eq(@img)
    end
  end # get_image

  describe "#hide_button?" do
    let(:user) { FactoryGirl.create(:user) }
    subject { toolbar_builder.hide_button?(@id) }
    before do
      @record = double("record")
      login_as user
      @settings = {
        :views => {
          :compare      => 'compressed',
          :drift        => 'compressed',
          :compare_mode => 'exists',
          :drift_mode   => 'exists',
          :treesize     => '32'
        }
      }
    end

    it "when id likes old_dialogs_*" do
      @id = "old_dialogs_some_thing"
      expect(subject).to be_truthy
    end

    it "when id likes ab_*" do
      @id = "ab_some_thing"
      expect(subject).to be_truthy
    end

    ["miq_task_", "compare_", "drift_", "comparemode_", "driftmode_", "custom_"].each do |i|
      it "when id likes #{i}*" do
        @id = "#{i}some_thing"
        expect(subject).to be_falsey
      end
    end

    context "when with miq_request_reload" do
      before { @id = "miq_request_reload" }
      it "and lastaction is show_list" do
        @lastaction = "show_list"
        expect(subject).to be_falsey
      end

      it "and lastaction is not show_list" do
        @lastaction = "log"
        expect(subject).to be_truthy
      end
    end

    context "when with miq_request_reload" do
      before { @id = "miq_request_reload" }
      it "and showtype is miq_provisions" do
        @showtype = "miq_provisions"
        expect(subject).to be_falsey
      end

      it "and showtype is not miq_provisions" do
        @showtype = "compare"
        expect(subject).to be_truthy
      end
    end

    it "when id likes dialog_*" do
      @id = "dialog_some_thing"
      expect(subject).to be_falsey
    end

    it "when with miq_request_approve and allowed by the role" do
      @id = "miq_request_approve"
      # when the role allows the feature
      stub_user(:features => :all)
      expect(subject).to be_falsey
    end

    it "when with miq_request_deny and allowed by the role" do
      @id = "miq_request_deny"
      # when the role allows the feature
      stub_user(:features => :all)
      expect(subject).to be_falsey
    end

    it "when not with miq_request_approve or miq_request_deny and not allowed by the role" do
      @id = "miq_request_edit"
      expect(subject).to be_truthy
    end

    ["ems_cluster_protect", "ext_management_system_protect",
     "host_enter_maint_mode", "host_exit_maint_mode",
     "repo_protect",
     "resource_pool_protect",
     "vm_check_compliance",
     "vm_start",
     "vm_suspend"].each do |id|
      it "when with #{id}" do
        @id = id
        stub_user(:features => :all)
        expect(subject).to be_falsey
      end
    end

    %w(vm_miq_request_new vm_pre_prov).each do |id|
      it "when with #{id}" do
        @id = id
        stub_user(:features => :all)
        expect(subject).to be_falsey
      end
    end

    context "when with miq_task_canceljob" do
      before do
        @id = 'miq_task_canceljob'
        stub_user(:features => :all)
      end

      it "and @layout != all_tasks" do
        @layout = "x_tasks"
        expect(subject).to be_truthy
      end

      it "and @layout != all_ui_tasks" do
        @layout = "x_ui_tasks"
        expect(subject).to be_truthy
      end

      it "and @layout = all_tasks" do
        @layout = "all_tasks"
        expect(subject).to be_falsey
      end

      it "and @layout = all_ui_tasks" do
        @layout = "all_ui_tasks"
        expect(subject).to be_falsey
      end
    end

    context 'last action set to show' do
      let(:lastaction) { 'show' }

      %w(main vms instances all_vms).each do |display|
        context "requested to display #{display}" do
          it 'returns with false' do
            stub_user(:features => :all)
            @lastaction = lastaction
            @display = display
            @id = 'vm_miq_request_new'
            expect(subject).to be_falsey
          end
        end
      end
    end

    context "CustomButtonSet" do
      before do
        @record = CustomButtonSet.new
        @sb = {:active_tree => :sandt_tree}
      end

      %w(ab_button_new ab_group_edit ab_group_delete).each do |id|
        it "hides #{id} action from toolbar when user has view permission only" do
          @id = id
          expect(subject).to be_truthy
        end
      end
    end

    context "when with Host" do
      before do
        @record = Host.new
        stub_user(:features => :all)
      end

      context "and id = common_drift" do
        before do
          @id = 'common_drift'
          @lastaction = 'drift_history'
        end

        it "and lastaction = drift_history" do
          expect(subject).to be_falsey
        end
      end
    end

    context "ServiceTemplate" do
      before do
        @record = ServiceTemplate.new
        @sb = {:active_tree => :sandt_tree}
      end

      %w(ab_button_new ab_group_new catalogitem_edit catalogitem_delete).each do |id|
        it "hides #{id} action from toolbar when user has view permission only" do
          @id = id
          expect(subject).to be_truthy
        end
      end
    end

    context "when record class = ExtManagementSystem" do
      before do
        @record = FactoryGirl.create(:ems_amazon)
      end

      context "and id = ems_cloud_timeline" do
        before { @id = "ems_cloud_timeline" }

        it "hide timelines button for EC2 provider" do
          allow(@record).to receive(:has_events?).and_return(false)
          expect(subject).to be_truthy
        end
      end
    end
  end # end of hide_button?

  describe "#disable_button" do
    subject { toolbar_builder.disable_button(@id) }
    before do
      @gtl_type = 'list'
      @settings = {
        :views => {
          :compare      => 'compressed',
          :drift        => 'compressed',
          :compare_mode => 'exists',
          :drift_mode   => 'exists',
          :treesize     => '32'
        }
      }
    end

    def setup_firefox_with_linux
      allow(session).to receive(:fetch_path).with(:browser, :name).and_return('firefox')
      allow(session).to receive(:fetch_path).with(:browser, :os).and_return('linux')
    end

    ['list', 'tile', 'grid'].each do |g|
      it "when with view_#{g}" do
        @gtl_type = g
        expect(toolbar_builder.disable_button("view_#{g}")).to be_truthy
      end
    end

    it 'disables the add new iso datastore button when no EMSes are available' do
      expect(ManageIQ::Providers::Redhat::InfraManager)
        .to(receive(:any_without_iso_datastores?))
        .and_return(false)

      @layout = "pxe"
      @id = "iso_datastore_new"

      expect(subject).to match(/No.*are available/)
    end

    context "when record class = MiqServer" do
      let(:log_file) { FactoryGirl.create(:log_file) }
      let(:miq_task) { FactoryGirl.create(:miq_task) }
      let(:file_depot) { FactoryGirl.create(:file_depot) }
      let(:miq_server) { FactoryGirl.create(:miq_server) }

      before do
        @record = MiqServer.new('name' => 'Server1', 'id' => 'Server ID')
      end

      it "'collecting' log_file with started server and disables button" do
        @record.status = "not responding"
        error_msg = "Cannot collect current logs unless the Server is started"
        expect(toolbar_builder.disable_button("collect_logs")).to eq(error_msg)
      end

      it "log collecting is in progress and disables button" do
        log_file.resource = @record
        log_file.state = "collecting"
        log_file.save
        @record.status = "started"
        @record.log_files << log_file
        error_msg = "Log collection is already in progress for this Server"
        expect(toolbar_builder.disable_button("collect_logs")).to eq(error_msg)
      end

      it "log collection in progress with unfinished task and disables button" do
        @record.status = "started"
        miq_task.name = "Zipped log retrieval for XXX"
        miq_task.miq_server_id = @record.id
        miq_task.save
        error_msg = "Log collection is already in progress for this Server"
        expect(toolbar_builder.disable_button("collect_logs")).to eq(error_msg)
      end

      it "'collecting' with undefined depot and disables button" do
        @record.status = "started"
        @record.log_file_depot = nil
        error_msg = "Log collection requires the Log Depot settings to be configured"
        expect(toolbar_builder.disable_button("collect_logs")).to eq(error_msg)
      end

      it "'collecting' with undefined depot and disables button" do
        @record.status = "started"
        @record.log_file_depot = nil
        error_msg = "Log collection requires the Log Depot settings to be configured"
        expect(toolbar_builder.disable_button("collect_logs")).to eq(error_msg)
      end

      it "'collecting' with defined depot and enables button" do
        @record.status = "started"
        @record.log_file_depot = file_depot
        expect(toolbar_builder.disable_button("collect_logs")).to eq(false)
      end
    end

    context "when record class = Zone" do
      let(:log_file) { FactoryGirl.create(:log_file) }
      let(:miq_task) { FactoryGirl.create(:miq_task) }
      let(:file_depot) { FactoryGirl.create(:file_depot) }
      let(:miq_server) { FactoryGirl.create(:miq_server) }

      before do
        @record = FactoryGirl.create(:zone)
      end

      it "'collecting' without any started server and disables button" do
        miq_server.status = "not responding"
        @record.miq_servers << miq_server
        error_msg = "Cannot collect current logs unless there are started Servers in the Zone"
        expect(toolbar_builder.disable_button("zone_collect_logs")).to eq(error_msg)
      end

      it "log collecting is in progress and disables button" do
        log_file.resource = @record
        log_file.state = "collecting"
        log_file.save
        miq_server.log_files << log_file
        miq_server.status = "started"
        @record.miq_servers << miq_server
        @record.log_file_depot = file_depot
        error_msg = "Log collection is already in progress for one or more Servers in this Zone"
        expect(toolbar_builder.disable_button("zone_collect_logs")).to eq(error_msg)
      end

      it "log collection in progress with unfinished task and disables button" do
        miq_server.status = "started"
        @record.miq_servers << miq_server
        @record.log_file_depot = file_depot
        miq_task.name = "Zipped log retrieval for XXX"
        miq_task.miq_server_id = miq_server.id
        miq_task.save
        error_msg = "Log collection is already in progress for one or more Servers in this Zone"
        expect(toolbar_builder.disable_button("zone_collect_logs")).to eq(error_msg)
      end

      it "'collecting' with undefined depot and disables button" do
        miq_server.status = "started"
        @record.miq_servers << miq_server
        @record.log_file_depot = nil
        error_msg = "This Zone do not have Log Depot settings configured, collection not allowed"
        expect(toolbar_builder.disable_button("zone_collect_logs")).to eq(error_msg)
      end

      it "'collecting' with defined depot and enables button" do
        miq_server.status = "started"
        @record.miq_servers << miq_server
        @record.log_file_depot = file_depot
        expect(toolbar_builder.disable_button("zone_collect_logs")).to eq(false)
      end
    end

    context "when record class = ServiceTemplate" do
      context "and id = svc_catalog_provision" do
        before do
          @record = ServiceTemplate.new
          @id = "svc_catalog_provision"
        end

        it "no provision dialog is available when action = 'provision'" do
          allow(@record).to receive(:resource_actions).and_return([])
          expect(subject).to eq("No Ordering Dialog is available")
        end

        it "when a provision dialog is available" do
          allow(@record).to receive_messages(:resource_actions => [double(:action => 'Provision', :dialog_id => '10')])
          allow(Dialog).to receive_messages(:find_by_id => 'some thing')
          expect(subject).to be_falsey
        end
      end
    end

    context "when record class = Storage" do
      before { @record = Storage.new }

      context "and id = storage_perf" do
        before do
          @id = "storage_perf"
          allow(@record).to receive_messages(:has_perf_data? => true)
        end
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this Datastore"
        it_behaves_like 'default case'
      end

      context "and id = storage_delete" do
        before { @id = "storage_delete" }
        it "when with VMs or Hosts" do
          allow(@record).to receive(:hosts).and_return(%w(h1 h2))
          expect(subject).to eq("Only Datastore without VMs and Hosts can be removed")

          allow(@record).to receive_messages(:hosts => [], :vms_and_templates => ['v1'])
          expect(subject).to eq("Only Datastore without VMs and Hosts can be removed")
        end
        it_behaves_like 'default case'
      end
    end

    context "when record class = Vm" do
      before { @record = Vm.new }

      context "and id = vm_perf" do
        before do
          @id = "vm_perf"
          allow(@record).to receive_messages(:has_perf_data? => true)
        end
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this VM"
        it_behaves_like 'default case'
      end

      context "and id = storage_scan" do
        before do
          @id = "storage_scan"
          @record = FactoryGirl.create(:storage)
          host = FactoryGirl.create(:host_vmware,
                                    :ext_management_system => FactoryGirl.create(:ems_vmware),
                                    :storages              => [@record])
        end

        it "should be available for vmware storages" do
          expect(subject).to be(false)
        end
      end

      context "and id = storage_scan" do
        before do
          @id = "storage_scan"
          @record = FactoryGirl.create(:storage)
        end

        it "should be not be available for non-vmware storages" do
          expect(subject).to include('cannot be performed on selected')
        end
      end

      context "and id = vm_vnc_console" do
        before :each do
          @id = 'vm_vnc_console'
          @record = FactoryGirl.create(:vm_vmware)
        end

        it "should not be available for vmware hosts with an api version greater or equal to 6.5" do
          @ems = FactoryGirl.create(:ems_vmware, :api_version => '6.5')
          allow(@record).to receive(:ems_id).and_return(@ems.id)
          expect(subject).to include('VNC consoles are unsupported on VMware ESXi 6.5 and later.')
        end

        %w(5.1 5.5 6.0).each do |version|
          it "should be available for vmware hosts with an api version #{version}" do
            @ems = FactoryGirl.create(:ems_vmware, :api_version => version)
            allow(@record).to receive(:ems_id).and_return(@ems.id)
            expect(subject).to be(false)
          end
        end
      end
    end # end of Vm class

  end # end of disable button

  describe "#hide_button_ops" do
    subject { toolbar_builder.hide_button_ops(@id) }
    before do
      @record = FactoryGirl.create(:tenant, :parent => Tenant.seed)
      feature = EvmSpecHelper.specific_product_features(%w(ops_rbac rbac_group_add rbac_tenant_add rbac_tenant_delete))
      login_as FactoryGirl.create(:user, :features => feature)
      @sb = {:active_tree => :rbac_tree}
    end

    %w(rbac_group_add rbac_project_add rbac_tenant_add rbac_tenant_delete).each do |id|
      context "when with #{id} button should be visible" do
        before { @id = id }
        it "and record_id" do
          expect(subject).to be_falsey
        end
      end
    end

    %w(rbac_group_edit rbac_role_edit).each do |id|
      context "when with #{id} button should not be visible as user does not have access to these features" do
        before { @id = id }
        it "and record_id" do
          expect(subject).to be_truthy
        end
      end
    end
  end

  describe "#get_record_cls" do
    subject { toolbar_builder.get_record_cls(record) }
    context "when record not exist" do
      let(:record) { nil }
      it { is_expected.to eq("NilClass") }
    end

    context "when record is array" do
      let(:record) { ["some", "thing"] }
      it { is_expected.to eq(record.class.name) }
    end

    context "when record is valid" do
      [ManageIQ::Providers::Redhat::InfraManager::Host].each do |c|
        it "and with #{c}" do
          record = c.new
          expect(toolbar_builder.get_record_cls(record)).to eq(record.class.base_class.to_s)
        end
      end

      it "and with 'VmOrTemplate'" do
        record = ManageIQ::Providers::Vmware::InfraManager::Template.new
        expect(toolbar_builder.get_record_cls(record)).to eq(record.class.base_model.to_s)
      end

      it "otherwise" do
        record = Job.new
        expect(toolbar_builder.get_record_cls(record)).to eq(record.class.to_s)
      end
    end
  end

  describe "#twostate_button_selected" do
    before do
      @gtl_type = 'list'
      @settings = {
        :views => {
          :compare      => 'compressed',
          :drift        => 'compressed',
          :compare_mode => 'exists',
          :drift_mode   => 'exists',
          :treesize     => '32'
        }
      }
    end
    subject { toolbar_builder.twostate_button_selected(id) }

    ['list', 'tile', 'grid'].each do |g|
      it "when with view_#{g}" do
        @gtl_type = g
        expect(toolbar_builder.twostate_button_selected("view_#{g}")).to be_truthy
      end
    end

    it "when with tree_large" do
      @settings[:views][:treesize] = 32
      expect(toolbar_builder.twostate_button_selected("tree_large")).to be_truthy
    end

    it "when with tree_small" do
      @settings[:views][:treesize] = 16
      expect(toolbar_builder.twostate_button_selected("tree_small")).to be_truthy
    end

    context "when with 'compare_compressed'" do
      let(:id) { "compare_compressed" }
      it { is_expected.to be_truthy }
    end

    context "when with 'drift_compressed'" do
      let(:id) { "drift_compressed" }
      it { is_expected.to be_truthy }
    end

    context "when with 'compare_all'" do
      let(:id) { "compare_all" }
      it { is_expected.to be_truthy }
    end

    context "when with 'drift_all'" do
      let(:id) { "drift_all" }
      it { is_expected.to be_truthy }
    end

    context "when with 'comparemode_exists" do
      let(:id) { "comparemode_exists" }
      it { is_expected.to be_truthy }
    end

    context "when with 'driftmode_exists" do
      let(:id) { "driftmode_exists" }
      it { is_expected.to be_truthy }
    end
  end

  describe "#apply_common_props" do
    before do
      @record = double(:id => 'record_id_xxx_001', :class => double(:name => 'record_xxx_class'))
      btn_num = "x_button_id_001"
      desc = 'the description for the button'
      @input = {:url       => "button",
                :url_parms => "?id=#{@record.id}&button_id=#{btn_num}&cls=#{@record.class.name}&pressed=custom_button&desc=#{desc}"
      }
      @tb_buttons = {}
      @button = {:id => "custom_#{btn_num}"}
      @button = ApplicationHelper::Button::Basic.new(nil, nil, {}, {:id => "custom_#{btn_num}"})
    end

    context "button visibility" do
      it "defaults to hidden false" do
        props = toolbar_builder.apply_common_props(@button, @input)
        expect(props[:hidden]).to be(false)
      end

      it "honors explicit input's hidden properties" do
        props = toolbar_builder.apply_common_props(@button, :hidden => true)
        expect(props[:hidden]).to be(true)
      end
    end

    context "saves the item info by the same key" do
      subject do
        toolbar_builder.apply_common_props(@button, @input)
      end

      it "when input[:hidden] exists" do
        @input[:hidden] = 1
        expect(subject).to have_key(:hidden)
      end

      it "when input[:url_parms] exists" do
        expect(subject).to have_key(:url_parms)
      end

      it "when input[:confirm] exists" do
        @input[:confirm] = 'Are you sure?'
        expect(subject).to have_key(:confirm)
      end

      it "when input[:onwhen] exists" do
        @input[:onwhen] = '1+'
        expect(subject).to have_key(:onwhen)
      end
    end

    context "internationalization" do
      it "does translation of text title and confirm strings" do
        %i(text title confirm).each do |key|
          @input[key] = 'Configuration' # common button string, translated into Japanese
        end
        FastGettext.locale = 'ja'
        toolbar_builder.apply_common_props(@button, @input)
        %i(text title confirm).each do |key|
          expect(@button[key]).not_to match('Configuration')
        end
        FastGettext.locale = 'en'
      end

      it "does delayed translation of text title and confirm strings" do
        %i(text title confirm).each do |key|
          @input[key] = proc do
            _("Add New %{model}") % {:model => 'Model'}
          end
        end
        FastGettext.locale = 'ja'
        toolbar_builder.apply_common_props(@button, @input)
        %i(text title confirm).each do |key|
          expect(@button[key]).not_to match('Add New Model')
        end
        FastGettext.locale = 'en'
      end
    end
  end

  describe "#update_common_props" do
    before do
      @record = double(:id => 'record_id_xxx_001', :class => 'record_xxx_class')
      btn_num = "x_button_id_001"
      desc = 'the description for the button'
      @item = {:button    => "custom_#{btn_num}",
               :url       => "button",
               :url_parms => "?id=#{@record.id}&button_id=#{btn_num}&cls=#{@record.class}&pressed=custom_button&desc=#{desc}"
      }
      @tb_buttons = {}
      @item_out = {}
    end

    context "when item[:url] exists" do
      subject do
        toolbar_builder.update_common_props(@item, @item_out)
      end

      it "saves the value as it is otherwise" do
        expect(subject).to have_key(:url)
      end

      it "calls url_for_button" do
        expect(toolbar_builder).to receive(:url_for_button).and_call_original
        toolbar_builder.update_common_props(@item, @item_out)
      end
    end
  end

  describe "url_for_button" do
    context "when restful routes" do
      before do
        allow(controller).to receive(:restful?) { true }
      end

      it "returns / when button is 'view_grid', 'view_tile' or 'view_list'" do
        result = toolbar_builder.url_for_button('view_list', '/1r2?', true)
        expect(result).to eq('/')
      end

      it "supports compressed ids" do
        result = toolbar_builder.url_for_button('view_list', '/1?', true)
        expect(result).to eq('/')
      end
    end
  end

  describe "update_url_parms", :type => :request do
    before do
      MiqServer.seed
    end

    context "when the given parameter exists in the request query string" do
      before do
        get "/vm/show_list/100", :params => "type=grid"
      end

      it "updates the query string with the given parameter value" do
        expect(toolbar_builder.update_url_parms("?type=list")).to eq("?type=list")
      end
    end

    context "when the given parameters do not exist in the request query string" do
      before do
        get "/vm/show_list/100"
      end

      it "adds the params in the query string" do
        expect(toolbar_builder.update_url_parms("?refresh=y&type=list")).to eq("?refresh=y&type=list")
      end
    end

    context "when the request query string has a few specific params to be retained" do
      before do
        get "/vm/show_list/100",
            :params => "bc=VMs+running+on+2014-08-25&menu_click=Display-VMs-on_2-6-5&sb_controller=host"
      end

      it "retains the specific parameters and adds the new one" do
        expect(toolbar_builder.update_url_parms("?type=list"))
          .to eq("?bc=VMs+running+on+2014-08-25&menu_click=Display-VMs-on_2-6-5&sb_controller=host&type=list")
      end
    end

    context "when the request query string has a few specific params to be excluded" do
      before do
        get "/vm/show_list/100", :params => "page=1"
      end

      it "excludes specific parameters and adds the new one" do
        expect(toolbar_builder.update_url_parms("?type=list")).to eq("?type=list")
      end
    end
  end

  context "toolbar_class" do
    before do
      controller.instance_variable_set(:@sb, :active_tree => :foo_tree)
      @pdf_button = {:id        => "download_choice__download_pdf",
                     :child_id  => "download_pdf",
                     :type      => :button,
                     :img       => "download_pdf.png",
                     :imgdis    => "download_pdf.png",
                     :img_url   => ActionController::Base.helpers.image_path("toolbars/download_pdf.png"),
                     :icon      => "fa fa-file-pdf-o fa-lg",
                     :text      => "Download as PDF",
                     :title     => "Download this report in PDF format",
                     :name      => "download_choice__download_pdf",
                     :hidden    => false,
                     :pressed   => nil,
                     :onwhen    => nil,
                     :enabled   => true,
                     :url       => "/download_data",
                     :url_parms => "?download_type=pdf",
                     :data      => nil}
      @layout = "catalogs"
      stub_user(:features => :all)
      allow(helper).to receive(:x_active_tree).and_return(:ot_tree)
    end

    it "Hides PDF button when PdfGenerator is not available" do
      allow(PdfGenerator).to receive_messages(:available? => false)
      buttons = helper.build_toolbar('gtl_view_tb').collect { |button| button[:items] if button[:id] == "download_choice" }.compact.flatten
      expect(buttons).not_to include(@pdf_button)
    end

    it "Displays PDF button when PdfGenerator is available" do
      allow(PdfGenerator).to receive_messages(:available? => true)
      buttons = helper.build_toolbar('gtl_view_tb').collect { |button| button[:items] if button[:id] == "download_choice" }.compact.flatten
      expect(buttons).to include(@pdf_button)
    end

    it "Enables edit and remove buttons for read-write orchestration templates" do
      @record = FactoryGirl.create(:orchestration_template)
      buttons = helper.build_toolbar('orchestration_template_center_tb').first[:items]
      edit_btn = buttons.find { |b| b[:id].end_with?("_edit") }
      remove_btn = buttons.find { |b| b[:id].end_with?("_remove") }
      expect(edit_btn[:enabled]).to eq(true)
      expect(remove_btn[:enabled]).to eq(true)
    end

    it "Disables edit and remove buttons for read-only orchestration templates" do
      @record = FactoryGirl.create(:orchestration_template_with_stacks)
      buttons = helper.build_toolbar('orchestration_template_center_tb').first[:items]
      edit_btn = buttons.find { |b| b[:id].end_with?("_edit") }
      remove_btn = buttons.find { |b| b[:id].end_with?("_remove") }
      expect(edit_btn[:enabled]).to eq(false)
      expect(remove_btn[:enabled]).to eq(false)
    end
  end

  describe "#build_toolbar" do
    context "when the toolbar to be built is a blank view" do
      let(:toolbar_to_build) { 'blank_view_tb' }

      it "returns nil" do
        expect(_toolbar_builder.build_toolbar(toolbar_to_build)).to be_nil
      end
    end

    context "when the toolbar to be built is a generic object toolbar" do
      let(:toolbar_to_build) { 'generic_object_definition_tb' }

      before do
        allow(Rbac).to receive(:role_allows?).and_return(true)
      end

      it "includes the button group" do
        expect(_toolbar_builder.build_toolbar(toolbar_to_build).first).to include(
          :id    => "generic_object_definition_choice",
          :type  => :buttonSelect,
          :icon  => "fa fa-cog fa-lg",
          :title => "Configuration",
          :text  => "Configuration"
        )
      end

      it "includes the correct button items" do
        items = _toolbar_builder.build_toolbar(toolbar_to_build).first[:items]
        expect(items[0]).to include(
          :id    => "generic_object_definition_choice__generic_object_definition_create",
          :type  => :button,
          :icon  => "pficon pficon-add-circle-o fa-lg",
          :title => "Create a new Generic Object Definition",
          :text  => "Create a new Generic Object Definition",
          :data  => {
            'function'      => 'sendDataWithRx',
            'function-data' => '{"eventType": "showAddForm"}'
          }
        )
        expect(items[1]).to include(
          :id      => "generic_object_definition_choice__generic_object_definition_edit",
          :type    => :button,
          :icon    => "pficon pficon-edit fa-lg",
          :title   => "Edit this Generic Object Definition",
          :text    => "Edit this Generic Object Definition",
          :onwhen  => "1",
          :enabled => false,
          :data    => {
            'function'      => 'sendDataWithRx',
            'function-data' => '{"eventType": "showEditForm"}'
          }
        )
        expect(items[2]).to include(
          :id      => "generic_object_definition_choice__generic_object_definition_delete",
          :type    => :button,
          :icon    => "pficon pficon-delete fa-lg",
          :title   => "Delete this Generic Object Definition",
          :text    => "Delete this Generic Object Definition",
          :onwhen  => "1",
          :enabled => false,
          :confirm => "Are you sure you want to delete this Generic Object Definition?",
          :data    => {
            'function'      => 'sendDataWithRx',
            'function-data' => '{"eventType": "deleteGenericObject"}'
          }
        )
      end
    end
  end

  describe "#build_toolbar_by_class" do
    context "when the toolbar to be built is a blank view" do
      let(:toolbar_to_build) { ApplicationHelper::Toolbar::BlankView }

      it "returns nil" do
        expect(_toolbar_builder.build_toolbar_by_class(toolbar_to_build)).to be_nil
      end
    end

    context "when the toolbar to be built is a generic object toolbar" do
      let(:toolbar_to_build) { ApplicationHelper::Toolbar::GenericObjectDefinition }

      before do
        allow(Rbac).to receive(:role_allows?).and_return(true)
      end

      it "includes the button group" do
        expect(_toolbar_builder.build_toolbar_by_class(toolbar_to_build).first).to include(
          :id    => "generic_object_definition_choice",
          :type  => :buttonSelect,
          :icon  => "fa fa-cog fa-lg",
          :title => "Configuration",
          :text  => "Configuration"
        )
      end

      it "includes the correct button items" do
        items = _toolbar_builder.build_toolbar_by_class(toolbar_to_build).first[:items]
        expect(items[0]).to include(
          :id    => "generic_object_definition_choice__generic_object_definition_create",
          :type  => :button,
          :icon  => "pficon pficon-add-circle-o fa-lg",
          :title => "Create a new Generic Object Definition",
          :text  => "Create a new Generic Object Definition",
          :data  => {
            'function'      => 'sendDataWithRx',
            'function-data' => '{"eventType": "showAddForm"}'
          }
        )
        expect(items[1]).to include(
          :id      => "generic_object_definition_choice__generic_object_definition_edit",
          :type    => :button,
          :icon    => "pficon pficon-edit fa-lg",
          :title   => "Edit this Generic Object Definition",
          :text    => "Edit this Generic Object Definition",
          :onwhen  => "1",
          :enabled => false,
          :data    => {
            'function'      => 'sendDataWithRx',
            'function-data' => '{"eventType": "showEditForm"}'
          }
        )
        expect(items[2]).to include(
          :id      => "generic_object_definition_choice__generic_object_definition_delete",
          :type    => :button,
          :icon    => "pficon pficon-delete fa-lg",
          :title   => "Delete this Generic Object Definition",
          :text    => "Delete this Generic Object Definition",
          :onwhen  => "1",
          :enabled => false,
          :data    => {
            'function'      => 'sendDataWithRx',
            'function-data' => '{"eventType": "deleteGenericObject"}'
          }
        )
      end
    end
  end
end
