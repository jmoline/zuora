require 'spec_helper'

describe Zuora::Objects::Amendment do
  it "validates datetime of several attributes" do
    subject.status = 'PendingAcceptance' # required for service_activation_date
    [:contract_effective_date, :customer_acceptance_date, :effective_date, :service_activation_date].each do |attr|
      subject.send("#{attr}=", 'invalid')
      subject.should_not be_valid
      subject.errors[attr].should include('is not a valid datetime')
    end
  end

  context "TermsAndConditions amendments" do
    before do
      subject.type = 'TermsAndConditions'
      subject.should_not be_valid
    end

    it "validates date of term_start_date" do
      subject.errors[:term_start_date].should include('is not a valid date')
    end

    it "validates that initial_term is a number if type is TermsAndConditions" do
      subject.errors[:initial_term].should include("is not a number")
    end

    it "validates that renewal_term is a number if type is TermsAndConditions" do
      subject.errors[:renewal_term].should include("is not a number")
    end
  end

  it "requires name" do
    subject.name = nil
    subject.should_not be_valid
    subject.errors[:name].should include("can't be blank")
  end

  it "requires name to be less than 100 characters" do
    subject.name = "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"
    subject.should_not be_valid
    subject.errors[:name].should include("is too long (maximum is 100 characters)")
  end

  it "validates presence of product_rate_plan with certain types" do
    ['NewProduct','RemoveProduct','UpdateProduct'].each do |amendment_type|
      subject.type = amendment_type
      subject.should_not be_valid
      subject.errors[:product_rate_plan].should include("can't be blank")
    end
  end

  describe "of product_rate_plan" do
    it "validates that product_rate_plan is a pre-existing zuora object" do
      subject.product_rate_plan = Zuora::Objects::ProductRatePlan.new
      subject.valid?.should be_false
      subject.errors[:product_rate_plan].should include('is invalid')
    end

    it "accepts a valid pre-existing zuora product_rate_plan" do
      MockResponse.responds_with(:product_rate_plan_find_success) do
        subject.product_rate_plan = Zuora::Objects::ProductRatePlan.find('stub')
      end
      subject.valid?
      subject.errors[:product_rate_plan].should be_empty
    end

    describe "#rate_plan_designation" do
      it "should return :AmendmentSubscriptionRatePlanId when type is RemoveProduct" do
        subject.type = "RemoveProduct"
        subject.rate_plan_designation.should eql :AmendmentSubscriptionRatePlanId
      end

      it "should return :AmendmentSubscriptionRatePlanId when type is UpdateProduct" do
        subject.type = "UpdateProduct"
        subject.rate_plan_designation.should eql :AmendmentSubscriptionRatePlanId
      end

      it "should return :ProductRatePlanId when type is AddProduct" do
        subject.type = "AddProduct"
        subject.rate_plan_designation.should eql :ProductRatePlanId
      end
    end
  end

  context "amendment requests" do
    before do
      MockResponse.responds_with(:subscription_find_success) do
        subscription = Zuora::Objects::Subscription.find('stub')
        subject.subscription = subscription
        @end_date = subscription.subscription_end_date
      end
      subject.status = "Completed"
    end

    context "TermsAndConditions Amendments" do
      it "generates proper xml request" do
        subject.type = "TermsAndConditions"
        subject.name = "Change Terms"

        subject.contract_effective_date = @end_date + 1.day
        subject.term_start_date = @end_date + 1.day
        subject.initial_term = 1
        subject.renewal_term = 1
        subject.amend_options = {:generate_invoice => false, :process_payments => false}

        MockResponse.responds_with(:amendment_success) do
          subject.should be_valid
          subject.create.should == true
        end

        xml = Zuora::Api.instance.last_request
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:Type").
          with_value('TermsAndConditions')
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:Status").
          with_value('Completed')
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:ContractEffectiveDate").
          with_value('2012-08-21T00:00:00+00:00')
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:TermStartDate").
          with_value('2012-08-21T00:00:00+00:00')
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:InitialTerm").
          with_value('1')
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:RenewalTerm").
          with_value('1')
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:Name").
          with_value('Change Terms')
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:SubscriptionId").
          with_value('4028e48834aa10a30134c9fcdf9f6764')
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:AmendOptions/#{zns}:GenerateInvoice").
            with_value('false')
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:AmendOptions/#{zns}:ProcessPayments").
          with_value('false')
      end
    end

    context "Cancellation Amendments" do
      it "generates proper xml request" do
        subject.type = "Cancellation"
        subject.name = "Cancel Subscription"
        subject.contract_effective_date = @end_date + 1.day
        subject.effective_date = @end_date + 1.day

        MockResponse.responds_with(:amendment_success) do
          subject.should be_valid
          subject.create.should == true
        end

        xml = Zuora::Api.instance.last_request
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:Type").
          with_value('Cancellation')
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:Status").
          with_value('Completed')
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:ContractEffectiveDate").
          with_value('2012-08-21T00:00:00+00:00')
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:EffectiveDate").
          with_value('2012-08-21T00:00:00+00:00')
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:Name").
          with_value('Cancel Subscription')
        xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:SubscriptionId").
          with_value('4028e48834aa10a30134c9fcdf9f6764')
      end
    end

    context "Product Amendments" do
      before do
        MockResponse.responds_with(:product_rate_plan_find_success) do
          subject.product_rate_plan = Zuora::Objects::ProductRatePlan.find('stub')
        end

        subject.contract_effective_date = Time.parse("2012-07-20 10:10:27-04:00")
      end

      context "AddProduct request" do
        it "generates proper xml request" do
          subject.type = 'NewProduct'
          subject.name = 'Add Product'
          subject.amend_options = {:generate_invoice => true, :process_payments => false}

          MockResponse.responds_with(:amendment_success) do
            subject.should be_valid
            subject.create.should == true
          end

          xml = Zuora::Api.instance.last_request
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:Type").
            with_value('NewProduct')
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:Status").
            with_value('Completed')
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:ContractEffectiveDate").
            with_value('2012-07-20T10:10:27-04:00')
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:Name").
            with_value('Add Product')
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:SubscriptionId").
            with_value('4028e48834aa10a30134c9fcdf9f6764')
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{zns}:RatePlanData/#{zns}:RatePlan/#{ons}:ProductRatePlanId").
            with_value('4028e4883491c50901349d0e1e571341')
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:AmendOptions/#{zns}:GenerateInvoice").
            with_value('true')
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:AmendOptions/#{zns}:ProcessPayments").
            with_value('false')
        end
      end

      context "RemoveProduct request" do
        it "generates proper xml request" do
          subject.type = 'RemoveProduct'
          subject.name = 'Remove Product'
          subject.amend_options = {:generate_invoice => false, :process_payments => false}

          MockResponse.responds_with(:amendment_success) do
            subject.should be_valid
            subject.create.should == true
          end

          xml = Zuora::Api.instance.last_request
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:Type").
            with_value('RemoveProduct')
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:Status").
            with_value('Completed')
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:ContractEffectiveDate").
            with_value('2012-07-20T10:10:27-04:00')
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:Name").
            with_value('Remove Product')
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{ons}:SubscriptionId").
            with_value('4028e48834aa10a30134c9fcdf9f6764')
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:Amendments/#{zns}:RatePlanData/#{zns}:RatePlan/#{ons}:AmendmentSubscriptionRatePlanId").
            with_value('4028e4883491c50901349d0e1e571341')
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:AmendOptions/#{zns}:GenerateInvoice").
            with_value('false')
          xml.should have_xml("//env:Body/#{zns}:amend/#{zns}:requests/#{zns}:AmendOptions/#{zns}:ProcessPayments").
            with_value('false')
        end
      end
    end
  end
end
