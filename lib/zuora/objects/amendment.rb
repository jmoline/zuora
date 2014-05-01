module Zuora::Objects
  class Amendment < Base
    attr_accessor :product_rate_plan

    store_accessors :amend_options

    belongs_to :subscription

    validates_presence_of :subscription_id, :name
    validates_length_of :name, :maximum => 100
    validates_inclusion_of :auto_renew, :in => [true, false], :allow_nil => true
    validates_length_of :code, :maximum => 50, :allow_nil => true
    validates_datetime_of :contract_effective_date, :allow_nil => true
    validates_datetime_of :customer_acceptance_date, :allow_nil => true
    validates_datetime_of :effective_date, :allow_nil => true
    validates_datetime_of :service_activation_date, :if => Proc.new { |a| a.status == 'PendingAcceptance' }
    validates_length_of :description, :maximum => 500, :allow_nil => true
    validates_numericality_of :initial_term, :if => Proc.new { |a| a.type == 'TermsAndConditions' }
    validates_numericality_of :renewal_term, :if => Proc.new { |a| a.type == 'TermsAndConditions' }
    validates_date_of :term_start_date, :if => Proc.new { |a| a.type == 'TermsAndConditions' }
    validates_presence_of :destination_account_id, :if => Proc.new {|a| a.type == 'OwnerTransfer' }
    validates_presence_of :destination_invoice_owner_id, :if => Proc.new {|a| a.type == 'OwnerTransfer' }
    validates_presence_of :product_rate_plan, :if => Proc.new {|a| ["NewProduct","RemoveProduct","UpdateProduct"].include?(a.type) }
    validates_inclusion_of :status, :in => ["Completed", "Cancelled", "Draft", "Pending Acceptance", "Pending Activation"]
    validates_inclusion_of :term_type, :in => ['TERMED', 'EVERGREEN'], :allow_nil => true
    validates_inclusion_of :type, :in => ['Cancellation', 'NewProduct', 'OwnerTransfer', 'RemoveProduct', 'Renewal', 'UpdateProduct', 'TermsAndConditions']

    validate do |request|
      request.must_have_existing(:product_rate_plan)
    end

    define_attributes do
      read_only :created_by_id, :created_date, :updated_by_id, :updated_date
      defaults :status => 'Draft'
    end

    def must_have_existing(ref)
      object = self.send(ref)
      unless object.blank?
        errors[ref] << "is invalid" if object.id.nil?
      end
    end

    def rate_plan_designation
      ["RemoveProduct","UpdateProduct"].include?(type) ? :AmendmentSubscriptionRatePlanId : :ProductRatePlanId
    end

    def create
      return false unless valid?
      result = self.connector.current_client.request(:amend) do |xml|
        xml.__send__(zns, :requests) do |s|
          s.__send__(zns, :Amendments) do |a|
            to_hash.each do |k,v|
              a.__send__(ons, k.to_s.camelize.to_sym, (v.is_a?(Date)||v.is_a?(Time) ? v.to_datetime.strftime("%FT%T%:z") : v)) unless v.nil?
            end
            generate_rate_plan(a)
          end
          s.__send__(zns, :AmendOptions) do |ao|
            generate_amend_options(ao)
          end unless amend_options.blank?
        end
      end
      apply_response(result.to_hash)
    end

    def apply_response(response_hash)
      # really lame but the amend method returns "results"
      # instead of "result" like every other call
      result = response_hash[:amend_response][:results]
      if result[:success]
        self.id = result[:id]
        @previously_changed = changes
        @changed_attributes.clear
        return true
      else
        self.errors.add(:base, result[:errors][:message])
        return false
      end
    end

    def generate_rate_plan(builder)
      if product_rate_plan.present?
        builder.__send__(zns, :RatePlanData) do |rpd|
          rpd.__send__(zns, :RatePlan) do |rp|
            rp.__send__(ons, rate_plan_designation, product_rate_plan.id)
          end
        end
      end
    end

    def generate_amend_options(builder)
      amend_options.each do |k,v|
        builder.__send__(zns, k.to_s.camelize.to_sym, v)
      end
    end
  end
end
