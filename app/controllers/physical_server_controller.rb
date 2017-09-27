class PhysicalServerController < ApplicationController

  include Mixins::GenericListMixin
  include Mixins::GenericShowMixin
  include ActionView::Helpers::JavaScriptHelper
  include Mixins::ExplorerPresenterMixin
  include Mixins::Actions::PhysicalServerActions::PolicySimulation



  before_action :check_privileges
  before_action :session_data
  after_action :cleanup_action
  after_action :set_session_data

  def self.table_name
    @table_name ||= "physical_servers"
  end

  def session_data
    @title  = _("Physical Servers")
    @layout = "physical_server"
    @lastaction = session[:physical_server_lastaction]
    @polArr         = session[:polArr] || ""           # current tags in effect
    @policy_options = session[:policy_options] || ""
  end

  def set_session_data
    session[:layout] = @layout
    session[:physical_server_lastaction] = @lastaction
    session[:polArr]          = @polArr unless @polArr.nil?
    session[:policy_options]  = @policy_options unless @policy_options.nil?
  end

  def show_list
    # Disable the cache to prevent a caching problem that occurs when
    # pressing the browser's back arrow button to return to the show_list
    # page while on the Physical Server's show page. Disabling the cache
    # causes the page and its session variables to actually be reloaded.
    disable_client_cache

    process_show_list
  end

  def textual_group_list
    [
      %i(properties networks relationships power_management assets firmware_details network_adapters),
    ]
  end
  helper_method :textual_group_list

  def button
      assign_policies(PhysicalServer) if params[:pressed] == "physical_server_protect"
      tag(PhysicalServer) if params[:pressed] == "physical_server_tag"
      polsimph if params[:pressed] == "physical_server_policy_sim"

      return if ["physical_server_policy_sim", "physical_server_protect", "physical_server_tag"].include?(params[:pressed]) &&
                  @flash_array.nil?   # Some other screen is showing, so return
  end

  def policies
    @physical_server = @record = identify_record(params[:id], PhysicalServer)
    @lastaction = "rsop"
    @showtype = "policies"
    drop_breadcrumb(:name => _("Policy Simulation Details for %{name}") % {:name => @record.name},
                    :url  => "/physical_server/policies/#{@record.id}")
    @polArr = @record.resolve_profiles(session[:policies].keys).sort_by { |p| p["description"] }
    @policy_options = {}
    @policy_options[:out_of_scope] = true
    @policy_options[:passed] = true
    @policy_options[:failed] = true
    @policy_simulation_tree = TreeBuilderPolicySimulation.new(:policy_simulation_tree,
                                                              :policy_simulation,
                                                              @sb,
                                                              true,
                                                              :root      => @polArr,
                                                              :root_name => @record.name,
                                                              :options   => @policy_options)
    @edit = session[:edit] if session[:edit]
    if @edit && @edit[:explorer]
      if session[:policies].empty?
        render_flash(_("No policies were selected for Policy Simulation."), :error)
        return
      end
      @in_a_form = true
      replace_right_cell(:action => 'policy_sim')
      else
       render :template => 'physical_server/show'
     end
  end

  def policy_show_options
    if params[:passed] == "null" || params[:passed] == ""
      @policy_options[:passed] = false
      @policy_options[:failed] = true
    elsif params[:failed] == "null" || params[:failed] == ""
      @policy_options[:passed] = true
      @policy_options[:failed] = false
    elsif params[:failed] == "1"
      @policy_options[:failed] = true
    elsif params[:passed] == "1"
      @policy_options[:passed] = true
    end
    @physical_server = @record = identify_record(params[:id], PhysicalServer)
    @policy_simulation_tree = TreeBuilderPolicySimulation.new(:policy_simulation_tree,
                                                              :policy_simulation,
                                                              @sb,
                                                              true,
                                                              :root      => @polArr,
                                                              :root_name => @record.name,
                                                              :options   => @policy_options)
    replace_main_div({:partial => "physical_server/policies"}, {:flash => true})
  end

  # Show/Unshow out of scope items
  def policy_options
    @physical_server = @record = identify_record(params[:id], PhysicalServer)
    @policy_options ||= {}
    @policy_options[:out_of_scope] = (params[:out_of_scope] == "1")
    @policy_simulation_tree = TreeBuilderPolicySimulation.new(:policy_simulation_tree,
                                                              :policy_simulation,
                                                              @sb,
                                                              true,
                                                              :root      => @polArr,
                                                              :root_name => @record.name,
                                                              :options   => @policy_options)
    replace_main_div({:partial => "physical_server/policies"}, {:flash => true})
  end

#  Replace the right cell of the explorer
  def replace_right_cell(options = {})
    action, presenter = options.values_at(:action, :presenter)

    @explorer = true
    @sb[:action] = action unless action.nil?
    if @sb[:action] || params[:display]
      partial, action, @right_cell_text = set_right_cell_vars # Set partial name, action and cell header
    end
    presenter = rendering_objects

    presenter.show(:default_left_cell).hide(:custom_left_cell)
    # presenter[:clear_tree_cookies] = "edit_treeOpenStatex" if @sb[:action] == "policy_sim"

    presenter[:right_cell_text] = @right_cell_text

    presenter[:record_id] = @record.try(:id)

    # Hide/show searchbox depending on if a list is showing

    render :json => presenter.for_render
  end

  # set partial name and cell header for edit screens
  def set_right_cell_vars
    name = @record.try(:name).to_s
    table = request.parameters["controller"]
    case @sb[:action]
    when "policy_sim"
      if params[:action] == "policies"
        partial = "physical_server/policies"
        header = _("%{physical_server} Policy Simulation") % {:physical_server => ui_lookup(:table => table)}
        action = nil
      else
        partial = "layouts/policy_sim"
        header = _("%{physical_server} Policy Simulation") % {:physical_server => ui_lookup(:table => table)}
        action = nil
      end
    else
      # now take care of links on summary screen
      partial = if @showtype == "details"
                  "layouts/x_gtl"
                elsif @showtype == "item"
                  "layouts/item"
                elsif @showtype == "drift_history"
                  "layouts/#{@showtype}"
                else
                  "#{@showtype == "compliance_history" ? "shared/views" : "physical_server"}/#{@showtype}"
                end
      if @showtype == "item"
        header = _("%{action} \"%{item_name}\" for %{physical_server} \"%{name}\"") % {
          :physical_server => ui_lookup(:table => table),
          :name           => name,
          :item_name      => @item.kind_of?(ScanHistory) ? @item.started_on.to_s : @item.name,
          :action         => action_type(@sb[:action], 1)
        }
        x_history_add_item(:id     => x_node_right_cell,
                           :text   => header,
                           :action => @sb[:action],
                           :item   => @item.id)
      else
        header = _("\"%{action}\" for %{physical_server} \"%{name}\"") % {
          :physical_server => ui_lookup(:table => table),
          :name           => name,
          :action         => action_type(@sb[:action], 2)
        }
        if @display && @display != "main"
          x_history_add_item(:id      => x_node_right_cell,
                             :text    => header,
                             :display => @display)
        elsif @sb[:action] != "drift_history"
          x_history_add_item(:id     => x_node_right_cell,
                             :text   => header,
                             :action => @sb[:action])
        end
      end
      action = nil
    end
    return partial, action, header
  end

  def profile_build
    @catinfo ||= {}
    session[:physical_server].resolve_profiles(session[:policies].keys).each do |policy|
      cat = policy["description"]
      @catinfo[cat] = true unless @catinfo.key?(cat)
    end
  end

  def profile_toggle
    if params[:pressed] == "tag_cat_toggle"
      profile_build
      policy_escaped = j(params[:policy])
      cat            = params[:cat]
      render :update do |page|
        page << javascript_prologue
        if @catinfo[cat]
          @catinfo[cat] = false
          page << javascript_show("cat_#{policy_escaped}_div")
          page << "$('#cat_#{policy_escaped}_icon').prop('src', '#{ActionController::Base.helpers.image_path('tree/compress.png')}');"
        else
          @catinfo[cat] = true # Set squashed = true
          page << javascript_hide("cat_#{policy_escaped}_div")
          page << "$('#cat_#{policy_escaped}_icon').prop('src', '#{ActionController::Base.helpers.image_path('tree/expand.png')}');"
        end
      end
    else
      add_flash(_("Button not yet implemented"), :error)
      javascript_flash(:spinner_off => true)
    end
  end

end
