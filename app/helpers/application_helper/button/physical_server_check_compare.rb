class ApplicationHelper::Button::PhysicalServerCheckCompare < ApplicationHelper::Button::Basic
  def disabled?
    @error_message = _('No Compliance Policies assigned to this physical server') unless
        @record.try(:has_compliance_policies?)
    @error_message.present?
  end
end
