module Mixins
  module Actions
    module PhysicalServerActions
      module PolicySimulation
        # Policy simulation for selected entities
        # Entities supported:
        #  %w(vm miq_template instance image)

        # Most of policy simulation related stuff is in:
        # app/controllers/application_controller/policy_support.rb
        # FIXME: we'd like to unify the code layout.
        #
        def polsimph
          assert_privileges(params[:pressed])
          records = find_records_with_rbac(PhysicalServer, checked_or_params)

          if records.length < 1
            add_flash(_("At least 1 %{model} must be selected for Policy Simulation") %
              {:model => ui_lookup(:model => "PhysicalServer")}, :error)
            @refresh_div = "flash_msg_div"
            @refresh_partial = "layouts/flash_msg"
          else
            session[:tag_items] = records       # Set the array of tag items
            session[:tag_db] = PhysicalServer # Remember the DB
            if @explorer
              @edit ||= {}
              @edit[:explorer] = true       # Since no @edit, create @edit and save explorer to use while building url for vms in policy sim grid
              @edit[:pol_items] = records
              session[:edit] = @edit
              policy_sim(records)
              @refresh_partial = "layouts/policy_sim"
            else
              javascript_redirect :controller => 'physical_server', :action => 'policy_sim' # redirect to build the policy simulation screen
            end
          end
        end
        alias_method :physical_server_policy_sim, :polsimph
      end
    end
  end
end
